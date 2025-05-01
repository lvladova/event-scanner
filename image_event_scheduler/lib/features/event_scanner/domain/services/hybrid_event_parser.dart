import 'dart:convert';
import 'package:http/http.dart' as http;
import '../event_model.dart';
import 'event_parser.dart';
import 'package:flutter/material.dart';

class HybridEventParser {
  final String geminiApiKey;

  HybridEventParser(this.geminiApiKey);

  Future<List<EventModel>> extractEvents(String ocrText) async {
    // Try Gemini first
    try {
      final geminiEvents = await _extractEventsWithGemini(ocrText);
      if (geminiEvents.isNotEmpty) {
        print('Successfully extracted ${geminiEvents.length} events using Gemini');
        return geminiEvents;
      }
    } catch (e) {
      print('Gemini extraction failed: $e');
    }

    // Fallback to traditional parser with multi-event detection
    print('Falling back to traditional parser');
    return _extractEventsTraditional(ocrText);
  }

  Future<List<EventModel>> _extractEventsWithGemini(String ocrText) async {
    final String prompt = '''
Extract ALL events from this text. For each event, identify:
- Title/name of the event
- Date (return in YYYY-MM-DD format if possible, or null if not found)
- Time (return in HH:MM format if available, or null if not found)
- Location (full location string, or null if not found)
- Duration (in minutes, only if explicitly mentioned)

Text:
${ocrText}

Return ONLY a JSON array, no other text. Format:
[
  {
    "title": "Event Title",
    "date": "2025-05-03",
    "time": "13:00",
    "location": "Event Location",
    "duration_minutes": 60
  }
]

If any field is not found, use null. If no events found, return empty array [].
''';

    final response = await http.post(
      Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$geminiApiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [{
          'parts': [{'text': prompt}]
        }],
        'generationConfig': {
          'temperature': 0.2,  // Very low for consistent structured output
          'topK': 1,
          'topP': 1,
          'maxOutputTokens': 2048,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['candidates'][0]['content']['parts'][0]['text'];

      // Try to extract JSON from response
      final jsonStart = content.indexOf('[');
      final jsonEnd = content.lastIndexOf(']') + 1;

      if (jsonStart != -1 && jsonEnd != -1) {
        final jsonString = content.substring(jsonStart, jsonEnd);
        final eventsJson = jsonDecode(jsonString) as List;

        return eventsJson.map((e) => _parseEventFromJson(e)).toList();
      }
    }

    throw Exception('Failed to extract events with Gemini');
  }

  List<EventModel> _extractEventsTraditional(String ocrText) {
    // Enhanced traditional parser with multi-event detection
    List<EventModel> events = [];

    // First, try to split by clear separators
    List<String> segments = [];

    // Split by lines first
    final lines = ocrText.split('\n');
    String currentSegment = '';

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Check for date patterns that might indicate new events
      final datePattern = RegExp(
        r'\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s*,?\s*'
        r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?\b|'
        r'\b\d{1,2}[/.-]\d{1,2}(?:[/.-]\d{2,4})?\b',
        caseSensitive: false,
      );

      // Check for time patterns
      final timePattern = RegExp(
        r'\b\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)\b',
        caseSensitive: false,
      );

      // Check if this line is a date header (date but no time)
      final hasDate = datePattern.hasMatch(line);
      final hasTime = timePattern.hasMatch(line);

      if (hasDate && !hasTime && line.split(' ').length <= 5) {
        // Likely a date header - start new segment
        if (currentSegment.isNotEmpty) {
          segments.add(currentSegment);
          currentSegment = '';
        }
        currentSegment = line;
      } else if (line.contains(';') || line.contains('·') || line.contains('•')) {
        // Split on semicolon or bullet points
        final parts = line.split(RegExp(r';|·|•'));
        if (currentSegment.isNotEmpty) {
          currentSegment += ' ' + parts[0];
          segments.add(currentSegment);
          currentSegment = '';
        }

        for (int i = 1; i < parts.length; i++) {
          if (parts[i].trim().isNotEmpty) {
            segments.add(parts[i].trim());
          }
        }
      } else {
        currentSegment += (currentSegment.isEmpty ? '' : '\n') + line;

        // If this line has time and seems complete, it might be a full event
        if (hasTime && (line.contains(',') || line.toLowerCase().contains('at '))) {
          segments.add(currentSegment);
          currentSegment = '';
        }
      }
    }

    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }

    // Parse each segment
    for (String segment in segments) {
      EventModel event = EventParser.parseEventDetails(segment);
      if (event.title != "Untitled Event" || event.date != null || event.time != null) {
        events.add(event);
      }
    }

    return events;
  }

  EventModel _parseEventFromJson(Map<String, dynamic> json) {
    DateTime? date;
    if (json['date'] != null && json['date'] is String) {
      try {
        date = DateTime.parse(json['date']);
      } catch (_) {
        // Try other formats if needed
      }
    }

    TimeOfDay? time;
    if (json['time'] != null && json['time'] is String) {
      try {
        final parts = json['time'].split(':');
        if (parts.length >= 2) {
          time = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (_) {}
    }

    return EventModel(
      title: json['title']?.toString() ?? 'Untitled Event',
      date: date,
      time: time,
      location: json['location']?.toString() ?? 'Location TBD',
      description: json['title']?.toString() ?? '',
    );
  }
}