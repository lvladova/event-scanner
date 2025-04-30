import 'dart:io';
import '../../features/event_scanner/domain/event_model.dart';
import '../../features/event_scanner/domain/services/vision_api_service.dart';
import '../../features/event_scanner/domain/services/event_parser.dart';
import '../../features/event_scanner/domain/services/natural_language_service.dart';
import '../../config.dart';
import '../../features/event_scanner/domain/schedule_model.dart';
import '../../features/event_scanner/domain/services/schedule_parser.dart';

class OCRHelper {
  static Future<String> extractTextOnly(File image) async {
    try {
      return await extractTextFromImage(image, Config.visionApiKey);
    } catch (e) {
      print('OCR failed: $e');
      return "";
    }
  }

  static Future<EventModel?> tryParseEvent(String text) async {
    if (Config.useNaturalLanguageAPI) {
      try {
        return await NaturalLanguageService.extractEventEntities(text, Config.visionApiKey);
      } catch (e) {
        print('NLP parsing failed: $e');
        // Fallback
      }
    }
    try {
      return EventParser.parseEventDetails(text);
    } catch (e) {
      print('Traditional parsing failed: $e');
      return null;
    }
  }

  // Add these functions to your lib/core/ocr_helper.dart file:

  /// Try to parse an image as a schedule with potentially multiple events
  static Future<ScheduleModel> tryParseSchedule(File image) async {
    try {
      // First extract both text and the structured information
      final extractionResult = await extractTextAndStructure(image);
      final String text = extractionResult['text'] as String;
      final Map<String, dynamic> fullResponse =
          extractionResult['fullResponse'] as Map<String, dynamic>? ?? {};

      // Check if this might be a multi-event image
      bool isLikelyMultiEvent = _checkForMultiEventIndicators(text);

      if (isLikelyMultiEvent) {
        // Use the schedule parser to extract multiple events
        return ScheduleParser.parseSchedule(text, fullResponse);
      } else {
        // Treat as single event case
        EventModel? event = await tryParseEvent(text);

        // Create a schedule with just one event
        return ScheduleModel(
          title: event?.title ?? "Untitled Schedule",
          events: event != null ? [event] : [],
          rawText: text,
        );
      }
    } catch (e) {
      print('Schedule parsing failed: $e');
      // Return an empty schedule as fallback
      return ScheduleModel(
        title: "Error Parsing Schedule",
        events: [],
        rawText: "",
      );
    }
  }

  /// Check if text likely contains multiple events
  static bool _checkForMultiEventIndicators(String text) {
    // 1. Look for multiple date patterns
    final datePattern = RegExp(
      r'\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2}',
      caseSensitive: false,
    );

    final dateMatches = datePattern.allMatches(text).toList();
    if (dateMatches.length > 1) {
      return true;
    }

    // 2. Look for day of week patterns
    final dayPattern = RegExp(
      r'\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)\b',
      caseSensitive: false,
    );

    final dayMatches = dayPattern.allMatches(text).toList();
    if (dayMatches.length > 1) {
      return true;
    }

    // 3. Check for list markers and bullet points
    final listMarkers = [
      RegExp(r'\n\d+\.'),    // Numbered list
      RegExp(r'\n\*'),       // Asterisk bullet
      RegExp(r'\n-'),        // Hyphen bullet
      RegExp(r'\n•'),        // Bullet point
      RegExp(r'\(\d+\)'),    // Parenthesis numbers
    ];

    for (final marker in listMarkers) {
      if (marker.allMatches(text).length > 1) {
        return true;
      }
    }

    // 4. Check for schedule-related keywords
    final scheduleKeywords = [
      'schedule', 'timetable', 'agenda', 'itinerary',
      'program', 'lineup', 'calendar', 'events', 'activities',
      'rota', 'roster', 'syllabus'
    ];

    for (final keyword in scheduleKeywords) {
      if (text.toLowerCase().contains(keyword)) {
        return true;
      }
    }

    // 5. Check if the text is long enough to potentially contain multiple events
    if (text.split('\n').length > 10) {
      return true;
    }

    return false;
  }

  /// Extract both text and document structure from an image
  static Future<Map<String, dynamic>> extractTextAndStructure(File image) async {
    try {
      return await extractTextAndStructureFromImage(image, Config.visionApiKey);
    } catch (e) {
      print('OCR with structure extraction failed: $e');
      return {
        'text': '',
        'fullResponse': {}
      };
    }
  }
}

