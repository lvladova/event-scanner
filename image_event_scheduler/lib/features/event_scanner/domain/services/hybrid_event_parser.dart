import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../event_model.dart';
import 'event_parser.dart';
import 'package:flutter/material.dart';
import '../../../../config.dart';

class HybridEventParser {
  final String geminiApiKey;
  final int maxRetries;

  HybridEventParser(this.geminiApiKey, {this.maxRetries = 2});

  Future<List<EventModel>> extractEvents(String ocrText) async {
    if (ocrText.trim().isEmpty) {
      print('OCR text is empty, cannot extract events');
      return [];
    }

    // Try Gemini first if enabled
    if (Config.useGeminiParser) {
      try {
        print('Attempting to extract events using Gemini...');
        final geminiEvents = await _extractEventsWithGemini(ocrText);
        if (geminiEvents.isNotEmpty) {
          print('Successfully extracted ${geminiEvents.length} events using Gemini');
          return geminiEvents;
        } else {
          print('Gemini returned no events, falling back to traditional parser');
        }
      } catch (e) {
        print('Gemini extraction failed: $e');
      }
    } else {
      print('Gemini parser is disabled, using traditional parser');
    }

    // Fallback to traditional parser with multi-event detection
    print('Falling back to traditional parser');
    return _extractEventsTraditional(ocrText);
  }

  Future<List<EventModel>> _extractEventsWithGemini(String ocrText) async {
    // Truncate OCR text if it's too long
    final String truncatedText = ocrText.length > 10000
        ? ocrText.substring(0, 10000) + '...(truncated)'
        : ocrText;

    print('Gemini extraction: Processing ${truncatedText.length} characters of OCR text');

    final String prompt = '''
Extract ALL calendar events accurately from the OCR-scanned text provided below.

For each detected event, return a structured JSON object strictly following the specifications:

- "title": A clear and meaningful title for the event.
  - Prioritize explicit event names or titles clearly stated.
  - If an explicit title is absent, infer a relevant title based on context (e.g., "Meeting", "Conference", "Appointment").
  - Avoid default titles such as "Untitled Event" unless absolutely no context is provided.

- "date": The event date explicitly mentioned or inferred, in STRICT YYYY-MM-DD format.
  - If a year isn't mentioned, assume the current year (2024).
  - If no clear date is available, use null.

- "start_time": Event start time explicitly stated or inferred, STRICTLY in 24-hour format HH:MM.
  - If start time cannot be inferred clearly, return null.

- "end_time": Event end time explicitly stated or inferred, STRICTLY in 24-hour format HH:MM.
  - Return null if end time is not mentioned clearly.

- "duration_minutes": Calculate event duration ONLY if explicitly provided (e.g., "2-hour session").
  - Return null if not explicitly stated.

- "location": Extract the exact, complete location if explicitly mentioned.
  - If location details are incomplete or vague, return the best available string.
  - Return null if location is completely missing.

Guidelines for extraction accuracy:
- Identify separate events clearly by logical boundaries such as new lines, clear separation marks, dates, or contextual changes.
- Pay close attention to the format and logical flow of typical calendar event details.
- Do NOT fabricate details or infer beyond logical certainty.
- Avoid duplication: merge details confidently identified as referring to the same event.

OCR Text:
${truncatedText}

Return ONLY a structured JSON array like this example:
[
  {
    "title": "Team Meeting",
    "date": "2025-05-03",
    "start_time": "13:00",
    "location": "Room 403, Building A"
  }
]

Do NOT include any explanations, only pure JSON. If no events found, return an empty array [].
''';


    int retries = 0;
    while (retries <= maxRetries) {
      try {
        print('Gemini API request attempt #${retries + 1}');
        final stopwatch = Stopwatch()..start();

        // Fixed API URL - changed from v1beta to v1
        final apiUrl = 'https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash:generateContent?key=$geminiApiKey';
        print('Gemini API request to: ${apiUrl.substring(0, apiUrl.indexOf('?') + 20)}...');

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [{
              'parts': [{'text': prompt}]
            }],
            'generationConfig': {
              'temperature': 0.2,
              'topK': 1,
              'topP': 1,
              'maxOutputTokens': 2048,
            },
          }),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('Gemini API request timed out after 15 seconds');
            throw TimeoutException('Gemini API request timed out');
          },
        );

        stopwatch.stop();
        print('Gemini API response received in ${stopwatch.elapsedMilliseconds}ms with status: ${response.statusCode}');


        if (response.statusCode != 200) {
          String errorDetail = '';
          try {
            final errorJson = jsonDecode(response.body);
            if (errorJson.containsKey('error')) {
              final error = errorJson['error'];
              errorDetail = ' - Code: ${error['code']}, Message: ${error['message']}';

              // Fixed nullable expressions
              if ((error['message']?.toString() ?? '').contains('API key')) {
                throw Exception('Invalid Gemini API key');
              } else if ((error['message']?.toString() ?? '').contains('quota')) {
                throw Exception('Gemini API quota exceeded');
              }
            }
          } catch (e) {
            // Ignore JSON parsing errors in error response
          }

          print('Gemini API error: Status ${response.statusCode}$errorDetail');
          print('Response body: ${response.body.substring(0, math.min(200, response.body.length))}...');
          throw Exception('Gemini API returned status ${response.statusCode}$errorDetail');
        }

        print('Processing Gemini response...');
        return _processGeminiResponse(response);
      } catch (e) {
        // Classify error types for better debugging
        if (e is TimeoutException) {
          print('Gemini API timeout: The request took too long to complete');
        } else if (e is http.ClientException) {
          print('HTTP client error: ${e.message}');
        } else if (e is FormatException) {
          print('Format error: Invalid JSON response - ${e.message}');
        } else if (e is Exception && e.toString().contains('API key')) {
          print('API key error: Check your Gemini API key configuration');
        } else if (e is Exception && e.toString().contains('quota')) {
          print('Quota error: Your Gemini API quota has been exceeded');
        }

        // Determine if we should retry
        bool shouldRetry = e is TimeoutException ||
            (e is http.ClientException && e.toString().contains('Connection closed')) ||
            e.toString().contains('Socket');

        if (shouldRetry && retries < maxRetries) {
          retries++;
          print('Network error, retrying Gemini extraction (${retries}/${maxRetries})');
          await Future.delayed(Duration(seconds: 2 * retries));
          continue;
        }

        print('Gemini extraction failed: $e');
        throw Exception('Failed to extract events with Gemini: $e');
      }
    }

    throw Exception('Failed to extract events with Gemini after $maxRetries retries');
  }

  List<EventModel> _processGeminiResponse(http.Response response) {
    try {
      print('Parsing Gemini response body...');

      final data = jsonDecode(response.body);
      print('Response JSON structure: ${data.keys.toList()}');

      // Validate response structure with detailed logging
      if (data == null) {
        print('Error: Empty response from Gemini API');
        throw Exception('Empty response from Gemini API');
      }

      if (!data.containsKey('candidates')) {
        print('Error: Missing "candidates" key in response');
        print('Response keys available: ${data.keys.toList()}');
        throw Exception('No candidates in Gemini response');
      }

      if (data['candidates'] == null || data['candidates'].isEmpty) {
        print('Error: Empty candidates array');
        if (data.containsKey('promptFeedback')) {
          print('Prompt feedback: ${data['promptFeedback']}');
        }
        throw Exception('No candidates in Gemini response. Check for content filtering issues.');
      }

      final candidate = data['candidates'][0];
      print('Candidate keys: ${candidate.keys.toList()}');

      if (!candidate.containsKey('content')) {
        print('Error: Missing "content" in candidate');
        throw Exception('Missing content in Gemini response candidate');
      }

      final content = candidate['content'];
      print('Content keys: ${content.keys.toList()}');

      if (!content.containsKey('parts') || content['parts'] == null || content['parts'].isEmpty) {
        print('Error: Missing or empty "parts" in content');
        throw Exception('Missing parts in Gemini response content');
      }

      final parts = content['parts'];
      if (parts[0] == null || !parts[0].containsKey('text')) {
        print('Error: First part is null or missing "text"');
        print('Parts structure: $parts');
        throw Exception('Invalid parts structure in Gemini response');
      }

      final text = parts[0]['text'];
      if (text == null || text.isEmpty) {
        print('Error: Empty text in Gemini response');
        throw Exception('Empty text in Gemini response');
      }

      print('Received text response of length ${text.length}');
      print('Response preview: ${text.substring(0, math.min(100, text.length))}...');

      // First attempt: Try direct JSON decoding
      try {
        final trimmedText = text.trim();
        print('Attempting direct JSON parsing...');
        if (trimmedText.startsWith('[') && trimmedText.endsWith(']')) {
          final eventsJson = jsonDecode(trimmedText) as List;
          print('Successfully parsed JSON directly, found ${eventsJson.length} events');
          return eventsJson.map((e) => _parseEventFromJson(e)).toList();
        }
      } catch (e) {
        print('Direct JSON parsing failed: $e');
        print('Falling back to JSON extraction...');
      }

      // Second attempt: Extract JSON from text
      final jsonStart = text.indexOf('[');
      final jsonEnd = text.lastIndexOf(']') + 1;

      print('JSON markers found at: start=$jsonStart, end=$jsonEnd');

      if (jsonStart == -1 || jsonEnd <= jsonStart) {
        print('Error: Could not find JSON array in response');
        print('Response text: $text');
        throw Exception('No valid JSON array found in Gemini response');
      }

      final jsonString = text.substring(jsonStart, jsonEnd);
      print('Extracted JSON string of length ${jsonString.length}');

      try {
        print('Parsing extracted JSON...');
        final eventsJson = jsonDecode(jsonString) as List;
        print('Successfully parsed extracted JSON, found ${eventsJson.length} events');
        return eventsJson.map((e) {
          try {
            return _parseEventFromJson(e);
          } catch (parseError) {
            print('Error parsing event: $parseError');
            print('Problematic event JSON: $e');
            throw Exception('Error parsing event: $parseError');
          }
        }).toList();
      } catch (e) {
        print('JSON parsing error: $e');
        print('Problematic JSON string preview: ${jsonString.substring(0, math.min(200, jsonString.length))}...');
        throw Exception('Invalid JSON in Gemini response: $e');
      }
    } catch (e) {
      print('Error processing Gemini response: $e');
      throw Exception('Failed to process Gemini response: $e');
    }
  }

  List<EventModel> _extractEventsTraditional(String ocrText) {
    print('Running traditional parser on text (${ocrText.length} characters)');
    List<EventModel> events = [];

    // First, try to split by clear separators
    List<String> segments = [];

    // Split by lines first
    final lines = ocrText.split('\n');
    String currentSegment = '';
    bool inEvent = false;

    // Enhanced event boundary detection patterns
    final datePattern = RegExp(
      r'\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s*,?\s*'
      r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?\b|'
      r'\b\d{1,2}[/.-]\d{1,2}(?:[/.-]\d{2,4})?\b',
      caseSensitive: false,
    );

    final timePattern = RegExp(
      r'\b\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)\b',
      caseSensitive: false,
    );

    // Event title indicators
    final titleIndicators = [
      RegExp(r'event\s*:', caseSensitive: false),
      RegExp(r'title\s*:', caseSensitive: false),
      RegExp(r'what:', caseSensitive: false),
    ];

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) {
        // Empty line could signify separation between events
        if (currentSegment.isNotEmpty && inEvent) {
          segments.add(currentSegment);
          currentSegment = '';
          inEvent = false;
        }
        continue;
      }

      // Check for title indicators
      bool containsTitleIndicator = titleIndicators.any((pattern) => pattern.hasMatch(line));

      // Check for date and time
      final hasDate = datePattern.hasMatch(line);
      final hasTime = timePattern.hasMatch(line);

      // Detect potential event boundaries
      if ((hasDate && !hasTime && line.split(' ').length <= 6) || containsTitleIndicator) {
        // Likely a new event starting
        if (currentSegment.isNotEmpty) {
          segments.add(currentSegment);
        }
        currentSegment = line;
        inEvent = true;
      } else if (line.contains(';') || line.contains('·') || line.contains('•') || line.contains('|')) {
        // Split on separators
        final parts = line.split(RegExp(r';|·|•|\|'));
        if (currentSegment.isNotEmpty) {
          currentSegment += ' ' + parts[0].trim();
          segments.add(currentSegment);
        } else if (parts[0].trim().isNotEmpty) {
          segments.add(parts[0].trim());
        }

        currentSegment = '';

        for (int i = 1; i < parts.length; i++) {
          if (parts[i].trim().isNotEmpty) {
            segments.add(parts[i].trim());
          }
        }

        inEvent = false;
      } else {
        // Continue current segment
        currentSegment += (currentSegment.isEmpty ? '' : '\n') + line;

        // If this line seems like a complete event description
        if (hasTime &&
            (line.contains(',') ||
             line.toLowerCase().contains('at ') ||
             line.toLowerCase().contains('location'))) {
          segments.add(currentSegment);
          currentSegment = '';
          inEvent = false;
        }
      }
    }

    // Add final segment if any
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }

    print('Traditional parser identified ${segments.length} potential event segments');

    // Process each segment
    for (String segment in segments) {
      try {
        EventModel event = EventParser.parseEventDetails(segment);
        if (event.title != "Untitled Event" || event.date != null || event.time != null) {
          events.add(event);
        }
      } catch (e) {
        print('Error parsing segment: $e');
      }
    }

    print('Traditional parser returned ${events.length} valid events');
    return events;
  }

  EventModel _parseEventFromJson(Map<String, dynamic> json) {
    DateTime? date;
    if (json['date'] != null) {
      try {
        if (json['date'] is String) {
          // Try standard ISO format first
          date = DateTime.parse(json['date']);
        }
      } catch (e) {
        // Try alternative formats
        try {
          final dateParts = json['date'].toString().split('-');
          if (dateParts.length == 3) {
            date = DateTime(
              int.parse(dateParts[0]),
              int.parse(dateParts[1]),
              int.parse(dateParts[2])
            );
          }
        } catch (e2) {
          print('Could not parse date: ${json['date']}');
        }
      }
    }

    TimeOfDay? time;
    if (json['start_time'] != null) {
      try {
        final timeString = json['start_time'].toString();
        final timeRegex = RegExp(r'(\d{1,2}):(\d{2})');
        final match = timeRegex.firstMatch(timeString);

        if (match != null) {
          time = TimeOfDay(
            hour: int.parse(match.group(1)!),
            minute: int.parse(match.group(2)!),
          );
        }
      } catch (e) {
        print('Could not parse start_time: ${json['start_time']}');
      }
    }

    return EventModel(
      title: json['title']?.toString() ?? 'Untitled Event',
      date: date,
      time: time,
      location: json['location']?.toString() ?? 'Location TBD',
      description: json['description']?.toString() ?? json['title']?.toString() ?? '',
    );
  }
}