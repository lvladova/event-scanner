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


