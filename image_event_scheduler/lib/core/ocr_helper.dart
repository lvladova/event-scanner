import 'dart:io';
import 'package:flutter/material.dart';
import '../features/event_scanner/domain/event_model.dart';
import '../features/event_scanner/domain/services/vision_api_service.dart';
import '../features/event_scanner/domain/services/event_parser.dart';
import '../features/event_scanner/domain/services/natural_language_service.dart';
import '../features/event_scanner/domain/services/hybrid_event_parser.dart';
import '../config.dart';

/// This class provides helper methods for Optical Character Recognition (OCR)
class OCRHelper {
  // Initialize the Hybrid Parser
  static final _hybridParser = HybridEventParser(Config.geminiApiKey);

  /// Extract only the raw text from an image
  static Future<String> extractTextOnly(File image) async {
    try {
      return await extractTextFromImage(image, Config.visionApiKey);
    } catch (e) {
      print('OCR failed: $e');
      return "";
    }
  }

  /// Extract multiple events from text using the hybrid parser
  static Future<List<EventModel>> extractMultipleEvents(String text) async {
    if (Config.useGeminiParser) {
      try {
        // Use hybrid parser that tries Gemini first, then falls back to traditional
        final events = await _hybridParser.extractEvents(text);
        if (events.isNotEmpty) {
          return events;
        }
      } catch (e) {
        print('Hybrid parser failed: $e');
      }
    }

    // Fallback to single event parsing if hybrid fails
    final event = await tryParseEvent(text);
    return event != null ? [event] : [];
  }

  /// Parse text into a single EventModel using traditional or NLP methods
  static Future<EventModel?> tryParseEvent(String text) async {
    if (Config.useNaturalLanguageAPI) {
      try {
        return await NaturalLanguageService.extractEventEntities(text, Config.visionApiKey);
      } catch (e) {
        print('NLP parsing failed: $e');
      }
    }
    try {
      return EventParser.parseEventDetails(text);
    } catch (e) {
      print('Traditional parsing failed: $e');
      return null;
    }
  }

  /// Enhanced extraction that gets both text and structured information
  static Future<Map<String, dynamic>> extractStructuredText(File image) async {
    try {
      return await extractTextAndStructureFromImage(image, Config.visionApiKey);
    } catch (e) {
      print('Enhanced OCR failed: $e');
      return {
        'rawText': '',
        'blocks': [],
        'paragraphs': [],
        'success': false,
        'error': e.toString(),
      };
    }
  }

/// Process an image and extract event information, potentially multiple events
  static Future<List<EventModel>> processEventImage(File image, {bool detectMultiple = true}) async {
    List<EventModel> detectedEvents = [];
    String textToParse = '';
    Map<String, dynamic>? structuredData;

    try {

      print('Starting event image processing...');
      // Step 1: Use the new format detection functionality
      final formatDetectionResult = await processImageWithFormatDetection(image, Config.visionApiKey);

      // Extract the information from the result
      textToParse = formatDetectionResult['rawText'] ?? '';
      structuredData = formatDetectionResult['structuredData'];
      final documentFormat = formatDetectionResult['format'];
      final parsedData = formatDetectionResult['parsedData'];

      if (textToParse.isEmpty) {
        print('No text extracted from image.');
        return [_createDefaultEvent("No text found in image.")];
      }

      // Use the parsed data based on format detection
      if (parsedData != null && parsedData.isNotEmpty) {
        // Convert parsedData to EventModel
        final EventModel event = _convertParsedDataToEventModel(parsedData, documentFormat);
        if (event.title.isNotEmpty && event.title != "Untitled Event") {
          return [event];
        }
      }

      // Step 2: Extract multiple events using hybrid parser
      if (detectMultiple) {
        detectedEvents = await extractMultipleEvents(textToParse);
        if (detectedEvents.isNotEmpty) {
          return detectedEvents;
        }
      }

      // Step 3: Fallback to single event if no multiple events detected
      final event = await tryParseEvent(textToParse);
      if (event != null) {
        detectedEvents.add(event);
      }

      // Step 4: If still no events detected, create a default one
      if (detectedEvents.isEmpty) {
        print('No specific events detected, creating default event.');
        detectedEvents.add(_createDefaultEvent(textToParse));
      }

      return detectedEvents;

    } catch (e) {
      print('Error processing event image: $e');
      return [_createDefaultEvent("Error processing image: $e")];
    }
  }

  /// Parse structured text data into a single EventModel
  static Future<EventModel?> tryParseStructuredEvent(Map<String, dynamic> structuredData) async {
    try {
      final String rawText = structuredData['rawText'] as String? ?? '';
      EventModel? event = await tryParseEvent(rawText);

      if (event == null || event.title == "Untitled Event" || event.date == null || event.time == null || event.location == "Location TBD") {
        final eventData = extractEventData(structuredData);
        event ??= EventModel();

        final titles = eventData['titles'];
        if (titles != null && titles.isNotEmpty && (event.title == "Untitled Event" || event.title.isEmpty)) {
          event.title = titles[0];
        }

        final dates = eventData['dates'];
        if (dates != null && dates.isNotEmpty && event.date == null) {
          try {
            event.date = DateTime.parse(dates[0]);
          } catch (e) {
            print('Failed to parse structured date: ${dates[0]}, error: $e');
          }
        }

        final times = eventData['times'];
        if (times != null && times.isNotEmpty && event.time == null) {
          try {
            event.time = _parseTimeOfDay(times[0]);
          } catch (e) {
            print('Failed to parse structured time: ${times[0]}, error: $e');
          }
        }

        final locations = eventData['locations'];
        if (locations != null && locations.isNotEmpty && (event.location == "Location TBD" || event.location.isEmpty)) {
          event.location = locations[0];
        }
      }
      return event;
    } catch (e) {
      print('Structured parsing failed: $e');
      return null;
    }
  }

  // Helper to create a default event model
  static EventModel _createDefaultEvent(String description) {
    return EventModel(
      title: "New Event",
      date: DateTime.now(),
      time: TimeOfDay.now(),
      location: "Location TBD",
      description: description,
    );
  }

  // Helper function to extract event data from structured data
  static Map<String, List<String>> extractEventData(Map<String, dynamic> structuredData) {
    final titles = <String>[];
    final dates = <String>[];
    final times = <String>[];
    final locations = <String>[];

    final blocks = structuredData['blocks'] as List<dynamic>? ?? [];
    for (final block in blocks) {
      final text = block['text'] as String? ?? '';

      // Simple extraction patterns - you can enhance these
      if (text.contains(RegExp(r'\d{4}')) && text.contains(RegExp(r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)', caseSensitive: false))) {
        dates.add(text);
      }

      if (text.contains(RegExp(r'\d{1,2}:\d{2}')) || text.contains(RegExp(r'(AM|PM)', caseSensitive: false))) {
        times.add(text);
      }

      if (text.contains('Room') || text.contains('Hall') || text.contains('Street') || text.contains('Avenue')) {
        locations.add(text);
      }

      if (text.length > 5 && text.length < 50 && !dates.contains(text) && !times.contains(text) && !locations.contains(text)) {
        titles.add(text);
      }
    }

    return {
      'titles': titles,
      'dates': dates,
      'times': times,
      'locations': locations,
    };
  }

  // Helper to convert parsed data from format detection to EventModel
  static EventModel _convertParsedDataToEventModel(Map<String, dynamic> parsedData, String format) {
    EventModel event = EventModel(
      title: parsedData['title'] ?? "Untitled Event",
      location: parsedData['location'] ?? "Location TBD",
      description: parsedData['description'] ?? "",
    );

    // Handle date
    if (parsedData['date'] != null) {
      try {
        event.date = DateTime.parse(parsedData['date']);
      } catch (e) {
        print('Error parsing date: $e');
      }
    }

    // Handle time
    if (parsedData['startTime'] != null) {
      try {
        event.time = _parseTimeOfDay(parsedData['startTime']);
      } catch (e) {
        print('Error parsing time: $e');
      }
    }

    return event;
  }

  // Helper to parse TimeOfDay robustly
  static TimeOfDay? _parseTimeOfDay(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        String minutePart = parts[1];
        int minute = 0;
        bool isPM = false;

        final minuteMatch = RegExp(r'\d{1,2}').firstMatch(minutePart);
        if (minuteMatch != null) {
          minute = int.parse(minuteMatch.group(0)!);
        }

        isPM = minutePart.toLowerCase().contains('pm');
        if (isPM && hour < 12) {
          hour += 12;
        } else if (!isPM && hour == 12) {
          hour = 0;
        }

        if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    } catch (e) {
      print('Failed to parse time string: $timeString, error: $e');
    }
    return null;
  }
}