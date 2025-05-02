import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Simple text extraction from image
Future<String> extractTextFromImage(File imageFile, String apiKey) async {
  try {
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
      final Map<String, dynamic> data = jsonDecode(response.body);

      // Handle potential null responses safely
      if (data['responses'] == null ||
          data['responses'].isEmpty ||
          data['responses'][0]['textAnnotations'] == null ||
          data['responses'][0]['textAnnotations'].isEmpty) {
        return "No text found in image";
      }

      final String? description = data['responses'][0]['textAnnotations'][0]['description'];
      return description ?? "No text found";
    } else {
      // Print detailed error message
      print('API Error Response: ${response.body}');
      throw Exception('Failed to extract text: ${response.statusCode}');
    }
  } catch (e) {
    print('Error extracting text from image: $e');
    throw Exception('Failed to process image: $e');
  }
}

/// Enhanced function to extract both raw text and structured information
Future<Map<String, dynamic>> extractTextAndStructureFromImage(File imageFile, String apiKey) async {
  try {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // Request both TEXT_DETECTION and DOCUMENT_TEXT_DETECTION
    // DOCUMENT_TEXT_DETECTION provides more structured information with paragraphs and blocks
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
              {"type": "LABEL_DETECTION", "maxResults": 5}  // Add label detection for context
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);

      // Initialize result structure
      final Map<String, dynamic> result = {
        'rawText': '',
        'blocks': <Map<String, dynamic>>[],
        'paragraphs': <Map<String, dynamic>>[],
        'lines': <Map<String, dynamic>>[],
        'words': <Map<String, dynamic>>[],
        'labels': <String>[],
        'success': true,
      };

      // Extract raw text from TEXT_DETECTION
      if (data['responses'] != null &&
          data['responses'].isNotEmpty &&
          data['responses'][0]['textAnnotations'] != null &&
          data['responses'][0]['textAnnotations'].isNotEmpty) {

        final String? description = data['responses'][0]['textAnnotations'][0]['description'];
        result['rawText'] = description ?? "No text found";
      } else {
        return {
          'rawText': "No text found in image",
          'blocks': <Map<String, dynamic>>[],
          'paragraphs': <Map<String, dynamic>>[],
          'lines': <Map<String, dynamic>>[],
          'words': <Map<String, dynamic>>[],
          'labels': <String>[],
          'success': false,
        };
      }

      // Extract structured text from DOCUMENT_TEXT_DETECTION
      if (data['responses'] != null &&
          data['responses'].isNotEmpty &&
          data['responses'][0]['fullTextAnnotation'] != null) {

        final fullTextAnnotation = data['responses'][0]['fullTextAnnotation'];

        // Extract structured elements (if available)
        if (fullTextAnnotation['pages'] != null && fullTextAnnotation['pages'].isNotEmpty) {
          // Extract blocks
          for (var block in fullTextAnnotation['pages'][0]['blocks'] ?? []) {
            final Map<String, dynamic> blockData = {
              'text': _getTextFromBlock(block),
              'boundingBox': block['boundingBox'],
              'paragraphs': <Map<String, dynamic>>[]
            };

            // Extract paragraphs within the block
            for (var paragraph in block['paragraphs'] ?? []) {
              final Map<String, dynamic> paragraphData = {
                'text': _getTextFromParagraph(paragraph),
                'boundingBox': paragraph['boundingBox'],
                'words': <Map<String, dynamic>>[],
              };

              // Extract words within the paragraph
              for (var word in paragraph['words'] ?? []) {
                final String wordText = _getTextFromWord(word);
                if (wordText.isNotEmpty) {
                  paragraphData['words'].add({
                    'text': wordText,
                    'boundingBox': word['boundingBox'],
                  });
                }
              }

              blockData['paragraphs'].add(paragraphData);
              result['paragraphs'].add(paragraphData);
            }

            result['blocks'].add(blockData);
          }
        }
      }

      // Extract labels if available (for context)
      if (data['responses'] != null &&
          data['responses'].isNotEmpty &&
          data['responses'][0]['labelAnnotations'] != null) {

        for (var label in data['responses'][0]['labelAnnotations']) {
          final String? description = label['description'];
          if (description != null && description.isNotEmpty) {
            result['labels'].add(description);
          }
        }
      }

      return result;
    } else {
      // Print detailed error message
      print('API Error Response: ${response.body}');
      throw Exception('Failed to extract text and structure: ${response.statusCode}');
    }
  } catch (e) {
    print('Error extracting text and structure from image: $e');
    throw Exception('Failed to process image: $e');
  }
}

/// Main function to process an image and extract event information
Future<Map<String, dynamic>> processImageForEvent(File imageFile, String apiKey) async {
  // First extract text and structure using your existing function
  final extractionResult = await extractTextAndStructureFromImage(imageFile, apiKey);

  // Then pass the result to the generalized event data extractor
  final eventData = await extractStructuredEventData(
    extractionResult,
    isWorkSchedule: false, // Set to true if you know it's a work schedule in advance
  );

  return {
    'rawExtraction': extractionResult,
    'eventData': eventData,
  };
}

/// Enhanced function to extract structured data from the OCR text
Future<Map<String, dynamic>> extractStructuredEventData(
    Map<String, dynamic> visionResponse, {
      bool isWorkSchedule = false,
    }) async {
  // Get the raw text
  final String rawText = visionResponse['rawText'] ?? '';

  // Initialize result structure
  final Map<String, dynamic> eventData = {
    'title': '',
    'date': '',
    'startTime': '',
    'endTime': '',
    'location': '',
    'description': rawText,
    'confidence': 0.0,
  };

  // Split text into lines for processing
  final List<String> lines = rawText.split('\n');

  // Try to determine document type based on content patterns
  if (isWorkSchedule || _detectWorkScheduleFormat(rawText)) {
    return _parseWorkScheduleFormat(lines);
  } else if (_detectEventPosterFormat(rawText)) {
    return _parseEventPosterFormat(lines);
  } else {
    return _parseGenericEventFormat(lines, visionResponse);
  }
}

/// Detect if the OCR text appears to be from a work schedule
bool _detectWorkScheduleFormat(String text) {
  // Look for patterns common in work schedules
  final bool hasDayOff = text.contains('Day Off') ||
      RegExp(r'\b\d+\.\d+\s+ASM\b').hasMatch(text);
  final bool hasTimeRange = RegExp(r'\d{2}:\d{2}\s*[-–]\s*\d{2}:\d{2}').hasMatch(text);
  final bool hasDayWithDate = RegExp(r'(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+\w+\s+\d{1,2}').hasMatch(text);

  // Consider it a work schedule if it has at least two of these patterns
  int matchCount = 0;
  if (hasDayOff) matchCount++;
  if (hasTimeRange) matchCount++;
  if (hasDayWithDate) matchCount++;

  return matchCount >= 2;
}

/// Detect if the OCR text appears to be from an event poster
bool _detectEventPosterFormat(String text) {
  // Event posters often have these characteristics
  final bool hasEventWords = RegExp(r'\b(event|concert|festival|party|show|exhibition)\b',
      caseSensitive: false).hasMatch(text);
  final bool hasTicketInfo = RegExp(r'\b(ticket|admission|entry|free|price|\$|£|€)\b',
      caseSensitive: false).hasMatch(text);
  final bool hasVenueWords = RegExp(r'\b(venue|theater|stadium|hall|center|arena)\b',
      caseSensitive: false).hasMatch(text);

  // Consider it an event poster if it has at least two of these patterns
  int matchCount = 0;
  if (hasEventWords) matchCount++;
  if (hasTicketInfo) matchCount++;
  if (hasVenueWords) matchCount++;

  return matchCount >= 2;
}

/// Parse text in work schedule format using positional grouping to maintain row structure
Map<String, dynamic> _parseWorkScheduleFormat(List<String> lines) {
  // Initialize result
  final result = <String, dynamic>{
    'title': '',
    'date': '',
    'startTime': '',
    'endTime': '',
    'location': '',
    'description': lines.join('\n'),
    'confidence': 0.7,  // Base confidence
  };

  // First, reorganize the lines into potential "rows" based on dates
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic>? currentRow;

  // Patterns for detecting various elements
  final datePattern = RegExp(r'(May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|Jan|Feb|Mar|Apr)\s+(\d{1,2})');
  final dayPattern = RegExp(r'\b(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\b');
  final titlePattern = RegExp(r'\b(Day\s+Off|[\d\.]+\s+ASM)\b');
  final timeRangePattern = RegExp(r'(\d{2}:\d{2})\s*[-–]\s*(\d{2}:\d{2})');
  final locationPattern = RegExp(r'(\d{5,6})\s+(Cheltenham\s+Grovefield\s+Way)');

  // Group lines into potential "rows" based on date markers
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    // Check if this line contains a date
    final dateMatch = datePattern.firstMatch(line);
    if (dateMatch != null) {
      // Start a new row with this date
      if (currentRow != null) {
        rows.add(currentRow);
      }

      currentRow = {
        'date': '${dateMatch.group(1)} ${dateMatch.group(2)}',
        'content': <String>[],
        'lineStart': i,
        'lineEnd': i,
      };

      // Check for day of week in the same line
      final dayMatch = dayPattern.firstMatch(line);
      if (dayMatch != null) {
        currentRow['day'] = dayMatch.group(1);
      }

      continue;
    }

    // Add the line to the current row's content
    if (currentRow != null) {
      currentRow['content'].add(line);
      currentRow['lineEnd'] = i;
    }
  }

  // Add the last row if it exists
  if (currentRow != null) {
    rows.add(currentRow);
  }

  // Now process each row to extract shift details, times, and locations
  for (var row in rows) {
    List<String> content = row['content'];

    // Look for shift title in this row's content
    String? rowTitle;
    String? rowStartTime;
    String? rowEndTime;
    String? rowLocation;

    for (var line in content) {
      // Extract shift title
      final titleMatch = titlePattern.firstMatch(line);
      if (titleMatch != null) {
        rowTitle = titleMatch.group(1);
      }

      // Extract time
      final timeMatch = timeRangePattern.firstMatch(line);
      if (timeMatch != null) {
        rowStartTime = timeMatch.group(1);
        rowEndTime = timeMatch.group(2);
      }

      // Extract location
      final locationMatch = locationPattern.firstMatch(line);
      if (locationMatch != null) {
        rowLocation = line;
      }
    }

    // Add complete row info
    row['title'] = rowTitle;
    row['startTime'] = rowStartTime;
    row['endTime'] = rowEndTime;
    row['location'] = rowLocation;
  }

  // Now find the ASM shift or non-Day Off shift if exists
  Map<String, dynamic>? targetRow;

  // First try to find an ASM shift
  for (var row in rows) {
    if (row['title'] != null && row['title'].toString().contains('ASM')) {
      targetRow = row;
      break;
    }
  }

  // If no ASM shift, check for any non-Day Off shift
  if (targetRow == null) {
    for (var row in rows) {
      if (row['title'] != null && !row['title'].toString().contains('Day Off')) {
        targetRow = row;
        break;
      }
    }
  }

  // If still no match, use the first row with any title
  if (targetRow == null && rows.isNotEmpty) {
    for (var row in rows) {
      if (row['title'] != null) {
        targetRow = row;
        break;
      }
    }
  }

  // If a row was selected, use its data
  if (targetRow != null) {
    result['title'] = targetRow['title'] ?? '';
    result['date'] = targetRow['date'] ?? '';
    result['startTime'] = targetRow['startTime'] ?? '';
    result['endTime'] = targetRow['endTime'] ?? '';
    result['location'] = targetRow['location'] ?? '';
  } else if (rows.isNotEmpty) {
    // Fallback: just use the first row
    result['date'] = rows[0]['date'] ?? '';
  }

  // If location is still empty but we found one in any row, use that
  if (result['location'].isEmpty) {
    for (var row in rows) {
      if (row['location'] != null && row['location'].toString().isNotEmpty) {
        result['location'] = row['location'];
        break;
      }
    }
  }

  // Calculate confidence based on completeness
  int fieldsFound = 0;
  if (result['title'].isNotEmpty) fieldsFound++;
  if (result['date'].isNotEmpty) fieldsFound++;
  if (result['startTime'].isNotEmpty) fieldsFound++;
  if (result['location'].isNotEmpty) fieldsFound++;

  // Adjust confidence based on fields found
  result['confidence'] = 0.5 + (fieldsFound / 8); // Max 1.0

  return result;
}

/// Parse text in event poster format
Map<String, dynamic> _parseEventPosterFormat(List<String> lines) {
  // Initialize result
  final result = <String, dynamic>{
    'title': '',
    'date': '',
    'startTime': '',
    'endTime': '',
    'location': '',
    'description': lines.join('\n'),
    'confidence': 0.5,  // Base confidence
  };

  // Patterns for event posters
  final datePattern = RegExp(
    r'\b(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,|\.|\s+)?\s*\d{4}?\b',
    caseSensitive: false,
  );

  final timePattern = RegExp(
    r'\b(?:at|from)?\s*\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)(?:\s*-\s*\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM))?\b',
    caseSensitive: false,
  );

  final locationPattern = RegExp(
    r'\b(?:at|in|venue|location|place)(?::|is)?\s+([A-Za-z0-9\s\.,]+(?:Theater|Theatre|Hall|Stadium|Arena|Center|Centre|Park|Building|Club))\b',
    caseSensitive: false,
  );

  // Title is often the largest text on a poster, which would be the first line in OCR
  if (lines.isNotEmpty && lines[0].length > 3) {
    result['title'] = lines[0];
  }

  // Look for date in all lines
  for (final line in lines) {
    final dateMatch = datePattern.firstMatch(line);
    if (dateMatch != null && result['date'].isEmpty) {
      result['date'] = dateMatch.group(0) ?? '';

      // Look for time on the same line
      final timeMatch = timePattern.firstMatch(line);
      if (timeMatch != null && result['startTime'].isEmpty) {
        result['startTime'] = timeMatch.group(0) ?? '';
      }

      continue;
    }

    // Look for time if not found with date
    if (result['startTime'].isEmpty) {
      final timeMatch = timePattern.firstMatch(line);
      if (timeMatch != null) {
        result['startTime'] = timeMatch.group(0) ?? '';
        continue;
      }
    }

    // Look for location
    final locationMatch = locationPattern.firstMatch(line);
    if (locationMatch != null && locationMatch.groupCount >= 1 && result['location'].isEmpty) {
      result['location'] = locationMatch.group(1) ?? '';
      continue;
    }
  }

  // Calculate confidence based on completeness
  int fieldsFound = 0;
  if (result['title'].isNotEmpty) fieldsFound++;
  if (result['date'].isNotEmpty) fieldsFound++;
  if (result['startTime'].isNotEmpty) fieldsFound++;
  if (result['location'].isNotEmpty) fieldsFound++;

  // Adjust confidence based on fields found
  result['confidence'] = 0.5 + (fieldsFound / 8); // Max 1.0

  return result;
}

/// Parse text in a generic event format
Map<String, dynamic> _parseGenericEventFormat(List<String> lines, Map<String, dynamic> visionResponse) {
  // Initialize result
  final result = <String, dynamic>{
    'title': '',
    'date': '',
    'startTime': '',
    'endTime': '',
    'location': '',
    'description': lines.join('\n'),
    'confidence': 0.3,  // Lower base confidence for generic format
  };

  // First, check if there are structured blocks available
  if (visionResponse['blocks'] != null && visionResponse['blocks'].isNotEmpty) {
    // Try to use the block structure to identify elements

    // Assume the first block might be the title (if it's short)
    if (visionResponse['blocks'][0]['text'].toString().split('\n').length <= 2) {
      result['title'] = visionResponse['blocks'][0]['text'];
    }

    // Look for blocks with date/time patterns
    for (var block in visionResponse['blocks']) {
      final text = block['text'] ?? '';

      // Skip if it's likely the title
      if (text == result['title']) continue;

      // Check for date patterns
      if (result['date'].isEmpty &&
          RegExp(r'\b(?:\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{2,4}|' +
              r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2})\b',
              caseSensitive: false).hasMatch(text)) {
        // Extract the date
        final dateMatch = RegExp(r'\b(?:\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{2,4}|' +
            r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,|\s+)?\s*\d{0,4})\b',
            caseSensitive: false).firstMatch(text);
        if (dateMatch != null) {
          result['date'] = dateMatch.group(0) ?? '';
        }
      }

      // Check for time patterns
      if (result['startTime'].isEmpty &&
          RegExp(r'\b\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?\b').hasMatch(text)) {
        // Extract the time
        final timeMatch = RegExp(r'\b(\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?)\b').firstMatch(text);
        if (timeMatch != null) {
          result['startTime'] = timeMatch.group(0) ?? '';

          // Look for end time (if it's a range)
          final rangeMatch = RegExp(r'\b\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?\s*(?:-|to|–)\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?)\b').firstMatch(text);
          if (rangeMatch != null && rangeMatch.groupCount >= 1) {
            result['endTime'] = rangeMatch.group(1) ?? '';
          }
        }
      }

      // Check for location keywords
      if (result['location'].isEmpty &&
          RegExp(r'\b(?:location|venue|place|at|in)\b', caseSensitive: false).hasMatch(text)) {
        // This block might contain location information
        result['location'] = text.replaceAll(RegExp(r'\b(?:location|venue|place|at|in)[:]\s*',
            caseSensitive: false), '');
      }
    }
  } else {
    // If no block structure, fall back to line-by-line analysis

    // Assume first line might be title
    if (lines.isNotEmpty && lines[0].length > 3) {
      result['title'] = lines[0];
    }

    // Generic patterns for dates, times, locations
    final datePattern = RegExp(r'\b\d{1,2}[\/\.\-]\d{1,2}[\/\.\-]\d{2,4}\b|' +
        r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,|\s+)?\s*\d{0,4}\b',
        caseSensitive: false);

    final timePattern = RegExp(r'\b\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?\b');

    final locationPattern = RegExp(r'\b(?:at|in|venue|location|place)[:]\s*([^\n\.]+)',
        caseSensitive: false);

    // Search all lines for patterns
    for (int i = 1; i < lines.length; i++) { // Skip first line (potential title)
      final line = lines[i];

      // Look for date
      if (result['date'].isEmpty) {
        final dateMatch = datePattern.firstMatch(line);
        if (dateMatch != null) {
          result['date'] = dateMatch.group(0) ?? '';
          continue;
        }
      }

      // Look for time
      if (result['startTime'].isEmpty) {
        final timeMatch = timePattern.firstMatch(line);
        if (timeMatch != null) {
          result['startTime'] = timeMatch.group(0) ?? '';

          // Look for end time
          final rangeMatch = RegExp(r'\b\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?\s*(?:-|to|–)\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM)?)\b').firstMatch(line);
          if (rangeMatch != null && rangeMatch.groupCount >= 1) {
            result['endTime'] = rangeMatch.group(1) ?? '';
          }

          continue;
        }
      }

      // Look for location
      if (result['location'].isEmpty) {
        final locationMatch = locationPattern.firstMatch(line);
        if (locationMatch != null && locationMatch.groupCount >= 1) {
          result['location'] = locationMatch.group(1)?.trim() ?? '';
          continue;
        }

        // Also check for common location words
        if (RegExp(r'\b(?:theater|theatre|hall|stadium|arena|center|centre|auditorium|venue)\b',
            caseSensitive: false).hasMatch(line)) {
          result['location'] = line.trim();
          continue;
        }
      }
    }
  }

  // Calculate confidence based on completeness
  int fieldsFound = 0;
  if (result['title'].isNotEmpty) fieldsFound++;
  if (result['date'].isNotEmpty) fieldsFound++;
  if (result['startTime'].isNotEmpty) fieldsFound++;
  if (result['location'].isNotEmpty) fieldsFound++;

  // Adjust confidence based on fields found
  result['confidence'] = 0.3 + (fieldsFound / 10); // Max 0.7 for generic format

  return result;
}

// Helper function to extract text from a block
String _getTextFromBlock(Map<String, dynamic> block) {
  final StringBuffer buffer = StringBuffer();

  // Extract text from paragraphs
  for (var paragraph in block['paragraphs'] ?? []) {
    final String paragraphText = _getTextFromParagraph(paragraph);
    if (paragraphText.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.write('\n');
      }
      buffer.write(paragraphText);
    }
  }

  return buffer.toString();
}

// Helper function to extract text from a paragraph
String _getTextFromParagraph(Map<String, dynamic> paragraph) {
  final StringBuffer buffer = StringBuffer();

  // Extract text from words
  for (var word in paragraph['words'] ?? []) {
    final String wordText = _getTextFromWord(word);
    if (wordText.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write(wordText);
    }
  }

  return buffer.toString();
}

// Helper function to extract text from a word
String _getTextFromWord(Map<String, dynamic> word) {
  final StringBuffer buffer = StringBuffer();

  // Extract text from symbols
  for (var symbol in word['symbols'] ?? []) {
    final String? text = symbol['text'];
    if (text != null) {
      buffer.write(text);
    }
  }

  return buffer.toString();
}

// Function to detect dates, times, and locations from extracted text
Map<String, dynamic> extractEventData(Map<String, dynamic> structuredText) {
  final Map<String, dynamic> eventData = {
    'dates': <String>[],
    'times': <String>[],
    'locations': <String>[],
    'titles': <String>[],
  };

  // Use the blocks to identify potential event information
  for (var block in structuredText['blocks'] ?? []) {
    final String text = block['text'] ?? '';

    // Simple regex patterns for demonstration
    // In a real app, you'd use more sophisticated NLP or regex patterns

    // Date patterns
    final datePattern1 = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b'); // MM/DD/YYYY
    final datePattern2 = RegExp(r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}\b', caseSensitive: false); // Month DD, YYYY

    // Time patterns
    final timePattern = RegExp(r'\b\d{1,2}:\d{2}\s*(?:am|pm|AM|PM)?\b');

    // Location patterns (very simplified)
    final locationPattern = RegExp(r'\b(?:at|in|location|venue)[:\s]+([^\n\.]+)', caseSensitive: false);

    // Extract dates
    for (final match in datePattern1.allMatches(text)) {
      eventData['dates'].add(match.group(0)!);
    }
    for (final match in datePattern2.allMatches(text)) {
      eventData['dates'].add(match.group(0)!);
    }

    // Extract times
    for (final match in timePattern.allMatches(text)) {
      eventData['times'].add(match.group(0)!);
    }

    // Extract potential locations
    for (final match in locationPattern.allMatches(text)) {
      if (match.groupCount >= 1) {
        eventData['locations'].add(match.group(1)!.trim());
      }
    }

    // The first paragraph might be the title (simplified approach)
    if (block['paragraphs'] != null &&
        block['paragraphs'].isNotEmpty &&
        block['paragraphs'][0]['text'] != null) {
      final String paragraphText = block['paragraphs'][0]['text'];
      // Only consider it a title if it's not a date, time, or location
      if (!datePattern1.hasMatch(paragraphText) &&
          !datePattern2.hasMatch(paragraphText) &&
          !timePattern.hasMatch(paragraphText) &&
          !locationPattern.hasMatch(paragraphText)) {
        eventData['titles'].add(paragraphText);
      }
    }
  }

  return eventData;
}