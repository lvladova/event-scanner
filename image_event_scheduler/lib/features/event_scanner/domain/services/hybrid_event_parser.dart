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
You are an expert in parsing messy OCR-scanned text of screenshots, emails, chat messages, or promotional material, into structured calendar events like tickets, event posters, booking confirmations, work schedules, Concerts Reservations and all the other types of events. 

The text may come from screenshots, emails, chat messages, or promotional material.

The OCR text below contains a schedule with multiple events or just one, where:
- **Dates and times may be separated by line breaks**.
- Events may be inconsistently formatted.
- Some lines may contain only a date, only a time, or only a location.
- If there is some type of location mentioned for example "Restaurant", use it as part of the structured event.

📌 **Your goal** is to return a list of structured calendar events or just one event, in the following strict format:

Each object must include only these fields:
- "title": A descriptive event title, like "2.0 ASM". If not available, infer from context. Do NOT use "Untitled Event".
- "date": The full date in YYYY-MM-DD format. If the year is missing, assume 2025.
- "start_time": Start time in 24-hour format (HH:MM). If a time range is given, use the start time. If no time is found, return null.
- "location": Use the full location string if stated. Return null if no location is mentioned.

🧠 **CRITICAL INSTRUCTION**:
If a line contains a date (e.g., "Apr 14") and a few lines below it contains a time (e.g., "09:56 - 22:02"), and no other date appears between them, you MUST associate that time with the previous date. This means you must treat lines together **even if separated** by blank lines or unrelated headers.
⚠️ Instructions:
- The OCR text may include broken formatting and inconsistent spacing.
- Events may not have all fields on the same line.
- If a date appears in the text (e.g., "Apr 14") and a time appears a few lines below (e.g., "09:56 - 22:02"), and no other date appears in between, associate the time with the most recent date.
- Do NOT assume that lines must be adjacent — relate fields logically based on order, not just position.
- 🚫 Do NOT include "Day Off" entries or any lines that indicate time off, holidays, or absence. These are not events and must be excluded entirely.
- Do NOT fabricate missing information. Use null for fields not clearly present.
- Return only valid calendar events with at least a title and date.
- If several dates (e.g., May 20 to May 23) appear with no event text, treat them as **empty days**, not connected to any following event. Do NOT assign the next event’s time or title to the last of these dates. Only assign a date if it is immediately followed by or near a time/title block.
- If day names appear in other languages (e.g., “Lun” for Monday, “Frei” for Friday), normalize them to English when converting to dates.
- Dates may appear in formats like "Apr 1", "April 1st", "1 Apr", or "Mon, Apr 1". Normalize to YYYY-MM-DD assuming year = 2025 unless otherwise stated.
- Prefer specific titles like "2.0 ASM" over generic UI labels or app headers (e.g., "MyALDI", "News by Topic").
- Do not duplicate events. If the same date and time appear more than once, only extract it once.
- If multiple lines refer to the same event (e.g., date, then title, then time), treat them as one event block.
- Combine multi-line entries into a single event when logically continuous.


🔍 FORMAT DETECTION:
Before extracting events, first identify whether the OCR text is:
- A **Work Schedule**: Usually includes multiple dates in sequence (e.g., "May 5", "May 6", "May 7"), role labels (e.g., "ASM", "Shift", "0.5 ASM"), consistent locations, and possibly "Day Off".
- An **Event Poster**: Typically contains a single date and time, a bold or catchy title, promotional language (e.g., "Join us", "Don't miss"), and no sequential calendar structure.

Your task:
1. **If it's a work schedule**, extract each individual shift as a separate calendar event (excluding "Day Off").
2. **If it's an event poster**, extract only one calendar event using the most prominent title, date, time, and location.

Ignore header/footer noise. Focus only on event-worthy data.

✅ Output format:
Return a pure JSON array like this:

[
  {
    "title": "2.0 ASM",
    "date": "2025-04-14",
    "start_time": "09:56",
    "location": "775167 Cheltenham Grovefield Way"
  },
  {
    "title": "2.0 ASM",
    "date": "2025-04-16",
    "start_time": "11:57",
    "location": "775167 Cheltenham Grovefield Way"
  }
]

⛔ Do NOT return any other fields.
⛔ Do NOT include explanation or markdown.
⛔ If time or location is not clearly present, use null for that field.

---

OCR Text:
${truncatedText}
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