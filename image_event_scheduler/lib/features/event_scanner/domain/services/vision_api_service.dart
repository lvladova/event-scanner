import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<String> extractTextFromImage(File imageFile, String apiKey) async {
  final bytes = await imageFile.readAsBytes();
  final base64Image = base64Encode(bytes);

  final response = await http.post(
    Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "requests": [
        {
          "image": {"content": base64Image},
          "features": [{"type": "TEXT_DETECTION", "maxResults": 1}]
        }
      ]
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['responses']?.isEmpty || data['responses'][0]['textAnnotations'] == null) {
      return "No text found in image";
    }
    final description = data['responses'][0]['textAnnotations'][0]['description'];
    return description ?? "No text found";
  } else {
    // Print detailed error message
    print('API Error Response: ${response.body}');
    throw Exception('Failed to extract text: ${response.statusCode}');
  }
}

/// Extract text and comprehensive document structure from an image
Future<Map<String, dynamic>> extractTextAndStructureFromImage(File imageFile, String apiKey) async {
  try {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // Enhanced request with multiple detection types
    final response = await http.post(
      Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "requests": [
          {
            "image": {"content": base64Image},
            "features": [
              {"type": "TEXT_DETECTION", "maxResults": 1},
              {"type": "DOCUMENT_TEXT_DETECTION", "maxResults": 1},
              {"type": "IMAGE_PROPERTIES", "maxResults": 1},
              {"type": "OBJECT_LOCALIZATION", "maxResults": 10}
            ],
            "imageContext": {
              "languageHints": ["en"], // Add more languages as needed
              "textDetectionParams": {
                "enableTextDetectionConfidenceScore": true
              }
            }
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final responses = data['responses']?[0] ?? {};

      // 1. Extract basic text
      String extractedText = "No text found in image";
      if (responses['textAnnotations'] != null &&
          responses['textAnnotations'].isNotEmpty) {
        extractedText = responses['textAnnotations'][0]['description'] ?? "No text found";
      }

      // 2. Process structured document text (with layout info)
      final documentResults = <Map<String, dynamic>>[];
      if (responses['fullTextAnnotation'] != null) {
        final fullText = responses['fullTextAnnotation'];

        // Extract page info
        if (fullText['pages'] != null) {
          for (var page in fullText['pages']) {
            // Process blocks (paragraphs, tables, etc.)
            if (page['blocks'] != null) {
              for (var block in page['blocks']) {
                final blockInfo = {
                  'blockType': block['blockType'] ?? 'TEXT',
                  'boundingBox': block['boundingBox'],
                  'confidence': block['confidence'] ?? 0.0,
                  'text': '',
                  'paragraphs': <Map<String, dynamic>>[],
                };

                // Extract paragraphs within each block
                if (block['paragraphs'] != null) {
                  for (var paragraph in block['paragraphs']) {
                    final paraInfo = {
                      'boundingBox': paragraph['boundingBox'],
                      'confidence': paragraph['confidence'] ?? 0.0,
                      'text': '',
                      'words': <Map<String, dynamic>>[],
                    };

                    // Extract words within each paragraph
                    if (paragraph['words'] != null) {
                      for (var word in paragraph['words']) {
                        final wordText = _extractTextFromSymbols(word['symbols']);

                        paraInfo['words'].add({
                          'boundingBox': word['boundingBox'],
                          'confidence': word['confidence'] ?? 0.0,
                          'text': wordText,
                          'symbols': word['symbols'] ?? [],
                        });

                        paraInfo['text'] += wordText + ' ';
                      }

                      paraInfo['text'] = paraInfo['text'].trim();
                    }

                    blockInfo['paragraphs'].add(paraInfo);
                    blockInfo['text'] += paraInfo['text'] + '\n';
                  }

                  blockInfo['text'] = blockInfo['text'].trim();
                }

                documentResults.add(blockInfo);
              }
            }
          }
        }
      }

      // 3. Extract table structures
      final tableStructures = _detectTableStructures(responses);

      // 4. Identify potential list items
      final listItems = _detectListItems(extractedText);

      // 5. Process layout-based relationships
      final layoutAnalysis = _analyzeTextLayout(responses);

      // Return comprehensive results
      return {
        'text': extractedText,
        'fullResponse': responses,
        'documentStructure': {
          'blocks': documentResults,
          'tables': tableStructures,
          'lists': listItems,
          'layout': layoutAnalysis,
        },
        'textDensityMap': _generateTextDensityMap(responses),
        'confidence': _calculateOverallConfidence(responses),
      };
    } else {
      print('API Error Response: ${response.body}');
      throw Exception('Failed to extract text: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in text extraction: $e');
    return {
      'text': 'Error: Failed to process image',
      'fullResponse': {},
      'documentStructure': {
        'blocks': [],
        'tables': [],
        'lists': [],
        'layout': {},
      },
      'error': e.toString(),
    };
  }
}

/// Extract text from symbol annotations
String _extractTextFromSymbols(List<dynamic>? symbols) {
  if (symbols == null) return '';

  final buffer = StringBuffer();
  for (var symbol in symbols) {
    buffer.write(symbol['text'] ?? '');

    // Add space if detected
    if (symbol['property']?['detectedBreak']?['type'] == 'SPACE') {
      buffer.write(' ');
    }

    // Add newline if detected
    if (symbol['property']?['detectedBreak']?['type'] == 'EOL_SURE_SPACE' ||
        symbol['property']?['detectedBreak']?['type'] == 'LINE_BREAK') {
      buffer.write('\n');
    }
  }

  return buffer.toString();
}

/// Detect table structures from document layout
List<Map<String, dynamic>> _detectTableStructures(Map<String, dynamic> response) {
  final tables = <Map<String, dynamic>>[];

  try {
    // Table detection logic based on layout and alignments
    final fullTextAnnotation = response['fullTextAnnotation'];
    if (fullTextAnnotation != null && fullTextAnnotation['pages'] != null) {
      for (var page in fullTextAnnotation['pages']) {
        if (page['blocks'] == null) continue;

        // Find blocks that might represent tables
        for (var block in page['blocks']) {
          // Skip non-text blocks
          if (block['blockType'] != 'TEXT') continue;

          // Check for grid-like arrangement of words
          final gridAnalysis = _analyzeBlockForGridPattern(block);
          if (gridAnalysis['isLikelyTable']) {
            tables.add({
              'boundingBox': block['boundingBox'],
              'confidence': block['confidence'] ?? 0.0,
              'rows': gridAnalysis['rows'],
              'columns': gridAnalysis['columns'],
              'cellData': gridAnalysis['cellData'],
            });
          }
        }
      }
    }
  } catch (e) {
    print('Error detecting tables: $e');
  }

  return tables;
}

/// Analyze if a text block has a grid/table pattern
Map<String, dynamic> _analyzeBlockForGridPattern(Map<String, dynamic> block) {
  // Default response
  final result = {
    'isLikelyTable': false,
    'rows': 0,
    'columns': 0,
    'cellData': <Map<String, dynamic>>[],
  };

  try {
    if (block['paragraphs'] == null || block['paragraphs'].isEmpty) {
      return result;
    }

    // Collect all word bounding boxes
    final wordPositions = <Map<String, dynamic>>[];
    for (var paragraph in block['paragraphs']) {
      if (paragraph['words'] == null) continue;

      for (var word in paragraph['words']) {
        // Skip words without bounding boxes
        if (word['boundingBox'] == null || word['boundingBox']['vertices'] == null) continue;

        // Extract word text
        final wordText = _extractTextFromSymbols(word['symbols']);

        // Calculate bounding box center
        final vertices = word['boundingBox']['vertices'];
        final centerX = (vertices[0]['x'] + vertices[1]['x'] + vertices[2]['x'] + vertices[3]['x']) / 4;
        final centerY = (vertices[0]['y'] + vertices[1]['y'] + vertices[2]['y'] + vertices[3]['y']) / 4;

        wordPositions.add({
          'text': wordText,
          'centerX': centerX,
          'centerY': centerY,
          'boundingBox': word['boundingBox'],
        });
      }
    }

    // Need sufficient words to form a table
    if (wordPositions.length < 6) {
      return result;
    }

    // Analyze vertical alignments (rows)
    final yPositions = wordPositions.map((w) => w['centerY']).toList();
    yPositions.sort();

    // Group y-positions that are close together (within threshold)
    final yThreshold = 10.0; // Adjust based on image size
    final yGroups = <List<double>>[];

    for (var y in yPositions) {
      bool grouped = false;
      for (var group in yGroups) {
        if ((y - group.last).abs() < yThreshold) {
          group.add(y);
          grouped = true;
          break;
        }
      }

      if (!grouped) {
        yGroups.add([y]);
      }
    }

    // Similar analysis for columns (x positions)
    final xPositions = wordPositions.map((w) => w['centerX']).toList();
    xPositions.sort();

    final xThreshold = 15.0; // Adjust based on image size
    final xGroups = <List<double>>[];

    for (var x in xPositions) {
      bool grouped = false;
      for (var group in xGroups) {
        if ((x - group.last).abs() < xThreshold) {
          group.add(x);
          grouped = true;
          break;
        }
      }

      if (!grouped) {
        xGroups.add([x]);
      }
    }

    // Calculate average y-coordinate for each row
    final rowCenters = yGroups.map((group) {
      return group.reduce((a, b) => a + b) / group.length;
    }).toList();

    // Calculate average x-coordinate for each column
    final colCenters = xGroups.map((group) {
      return group.reduce((a, b) => a + b) / group.length;
    }).toList();

    // Assign words to cells based on their proximity to row/column centers
    final cellData = <Map<String, dynamic>>[];

    for (var word in wordPositions) {
      // Find closest row
      int rowIndex = 0;
      double minRowDist = double.infinity;

      for (int i = 0; i < rowCenters.length; i++) {
        final dist = (word['centerY'] - rowCenters[i]).abs();
        if (dist < minRowDist) {
          minRowDist = dist;
          rowIndex = i;
        }
      }

      // Find closest column
      int colIndex = 0;
      double minColDist = double.infinity;

      for (int i = 0; i < colCenters.length; i++) {
        final dist = (word['centerX'] - colCenters[i]).abs();
        if (dist < minColDist) {
          minColDist = dist;
          colIndex = i;
        }
      }

      // Add to cell data
      cellData.add({
        'text': word['text'],
        'row': rowIndex,
        'column': colIndex,
        'boundingBox': word['boundingBox'],
      });
    }

    // Determine if this is likely a table
    // Criteria: Multiple rows and columns with fairly even distribution
    final isLikelyTable = rowCenters.length >= 2 && colCenters.length >= 2;

    if (isLikelyTable) {
      result['isLikelyTable'] = true;
      result['rows'] = rowCenters.length;
      result['columns'] = colCenters.length;
      result['cellData'] = cellData;
    }
  } catch (e) {
    print('Error analyzing block for grid pattern: $e');
  }

  return result;
}

/// Detect potential list items in text
List<Map<String, dynamic>> _detectListItems(String text) {
  final listItems = <Map<String, dynamic>>[];

  try {
    final lines = text.split('\n');

    // Common list item patterns
    final listItemPatterns = [
      RegExp(r'^\s*\d+\.\s+(.+)$'),                // Numbered: "1. Item"
      RegExp(r'^\s*[a-z]\)\s+(.+)$'),              // Lettered: "a) Item"
      RegExp(r'^\s*[\*\-•■□▪▫◦○●]\s+(.+)$'),       // Bulleted: "• Item"
      RegExp(r'^\s*\(\d+\)\s+(.+)$'),              // Parenthesis: "(1) Item"
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      for (var pattern in listItemPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          // This line is a list item
          final content = match.group(1) ?? '';

          listItems.add({
            'lineIndex': i,
            'text': content,
            'fullText': line,
            'indentLevel': _countLeadingSpaces(line),
          });

          break;
        }
      }
    }
  } catch (e) {
    print('Error detecting list items: $e');
  }

  return listItems;
}

/// Count leading spaces to determine indentation level
int _countLeadingSpaces(String text) {
  final match = RegExp(r'^\s*').firstMatch(text);
  return match != null ? match.group(0)!.length : 0;
}

/// Analyze text layout for spatial relationships
Map<String, dynamic> _analyzeTextLayout(Map<String, dynamic> response) {
  final layout = {
    'textLines': <Map<String, dynamic>>[],
    'textBlocks': <Map<String, dynamic>>[],
    'textRegions': <Map<String, dynamic>>[],
  };

  try {
    if (response['textAnnotations'] == null || response['textAnnotations'].isEmpty) {
      return layout;
    }

    // Skip the first annotation (which is the entire text)
    final annotations = response['textAnnotations'].sublist(1);

    // Group text by vertical position (to identify lines)
    final Map<int, List<Map<String, dynamic>>> lineGroups = {};

    for (var annotation in annotations) {
      if (annotation['boundingPoly'] == null || annotation['boundingPoly']['vertices'] == null) {
        continue;
      }

      final vertices = annotation['boundingPoly']['vertices'];
      if (vertices.length < 4) continue;

      // Calculate center Y position
      final centerY = (vertices[0]['y'] + vertices[1]['y'] + vertices[2]['y'] + vertices[3]['y']) / 4;

      // Group with 10px tolerance
      final lineY = (centerY / 10).round() * 10;

      if (!lineGroups.containsKey(lineY)) {
        lineGroups[lineY] = [];
      }

      lineGroups[lineY]!.add({
        'text': annotation['description'] ?? '',
        'boundingPoly': annotation['boundingPoly'],
        'centerX': (vertices[0]['x'] + vertices[1]['x'] + vertices[2]['x'] + vertices[3]['x']) / 4,
        'centerY': centerY,
      });
    }

    // Sort line groups by Y position
    final sortedLineKeys = lineGroups.keys.toList()..sort();

    // Process each line
    for (int i = 0; i < sortedLineKeys.length; i++) {
      final key = sortedLineKeys[i];
      final line = lineGroups[key]!;

      // Sort words in the line by X position
      line.sort((a, b) => a['centerX'].compareTo(b['centerX']));

      // Collect text for this line
      final lineText = line.map((item) => item['text']).join(' ');

      layout['textLines'].add({
        'index': i,
        'y': key,
        'text': lineText,
        'words': line,
      });
    }

    // Group lines into blocks based on vertical spacing
    final lineSpacings = <double>[];
    for (int i = 1; i < sortedLineKeys.length; i++) {
      lineSpacings.add((sortedLineKeys[i] - sortedLineKeys[i-1]).toDouble());
    }

    // Calculate median line spacing
    if (lineSpacings.isNotEmpty) {
      lineSpacings.sort();
      final medianSpacing = lineSpacings[lineSpacings.length ~/ 2];

      // Group lines that are within 1.5x median spacing
      int currentBlock = 0;
      List<int> blockLines = [0]; // First line is in the first block

      for (int i = 1; i < sortedLineKeys.length; i++) {
        final spacing = sortedLineKeys[i] - sortedLineKeys[i-1];

        if (spacing > medianSpacing * 1.5) {
          // New block
          layout['textBlocks'].add({
            'index': currentBlock,
            'lines': blockLines.map((j) => layout['textLines'][j]).toList(),
            'text': blockLines.map((j) => layout['textLines'][j]['text']).join('\n'),
          });

          currentBlock++;
          blockLines = [i];
        } else {
          // Continue current block
          blockLines.add(i);
        }
      }

      // Add the last block
      if (blockLines.isNotEmpty) {
        layout['textBlocks'].add({
          'index': currentBlock,
          'lines': blockLines.map((j) => layout['textLines'][j]).toList(),
          'text': blockLines.map((j) => layout['textLines'][j]['text']).join('\n'),
        });
      }
    }
  } catch (e) {
    print('Error analyzing text layout: $e');
  }

  return layout;
}

/// Generate a heatmap of text density
Map<String, dynamic> _generateTextDensityMap(Map<String, dynamic> response) {
  const int gridSize = 10; // 10x10 grid
  final Map<String, dynamic> densityMap = {
    'gridSize': gridSize,
    'cells': List.generate(gridSize, (_) => List.filled(gridSize, 0)),
  };

  try {
    if (response['textAnnotations'] == null || response['textAnnotations'].isEmpty) {
      return densityMap;
    }

    // Extract image dimensions
    var maxX = 0.0;
    var maxY = 0.0;

    for (var annotation in response['textAnnotations']) {
      if (annotation['boundingPoly'] == null || annotation['boundingPoly']['vertices'] == null) {
        continue;
      }

      for (var vertex in annotation['boundingPoly']['vertices']) {
        if (vertex['x'] != null && vertex['x'] > maxX) maxX = vertex['x'].toDouble();
        if (vertex['y'] != null && vertex['y'] > maxY) maxY = vertex['y'].toDouble();
      }
    }

    if (maxX == 0 || maxY == 0) return densityMap;

    // Populate density map
    for (var annotation in response['textAnnotations']) {
      if (annotation['boundingPoly'] == null || annotation['boundingPoly']['vertices'] == null) {
        continue;
      }

      final vertices = annotation['boundingPoly']['vertices'];
      if (vertices.length < 4) continue;

      // Calculate normalized center position
      final centerX = (vertices[0]['x'] + vertices[1]['x'] + vertices[2]['x'] + vertices[3]['x']) / 4 / maxX;
      final centerY = (vertices[0]['y'] + vertices[1]['y'] + vertices[2]['y'] + vertices[3]['y']) / 4 / maxY;

      // Map to grid cell
      final gridX = (centerX * (gridSize - 1)).round();
      final gridY = (centerY * (gridSize - 1)).round();

      if (gridX >= 0 && gridX < gridSize && gridY >= 0 && gridY < gridSize) {
        densityMap['cells'][gridY][gridX]++;
      }
    }
  } catch (e) {
    print('Error generating text density map: $e');
  }

  return densityMap;
}

/// Calculate overall confidence of OCR results
double _calculateOverallConfidence(Map<String, dynamic> response) {
  double confidence = 0.0;
  int count = 0;

  try {
    if (response['fullTextAnnotation'] != null &&
        response['fullTextAnnotation']['pages'] != null) {
      for (var page in response['fullTextAnnotation']['pages']) {
        if (page['blocks'] != null) {
          for (var block in page['blocks']) {
            if (block['confidence'] != null) {
              confidence += block['confidence'];
              count++;
            }
          }
        }
      }
    }
  } catch (e) {
    print('Error calculating confidence: $e');
  }

  return count > 0 ? confidence / count : 0.0;
}
