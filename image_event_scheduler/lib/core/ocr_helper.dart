import 'dart:io';
import '../features/event_scanner/domain/event_model.dart';
import '../features/event_scanner/domain/services/vision_api_service.dart';
import '../features/event_scanner/domain/services/event_parser.dart';
import '../features/event_scanner/domain/services/natural_language_service.dart';
import '../config.dart';
import 'package:flutter/material.dart';

class OCRHelper {
  /// Extract only the raw text from an image
  static Future<String> extractTextOnly(File image) async {
    try {
      return await extractTextFromImage(image, Config.visionApiKey);
    } catch (e) {
      print('OCR failed: $e');
      return "";
    }
  }

  /// Enhanced extraction that gets both text and structured information
  static Future<Map<String, dynamic>> extractStructuredText(File image) async {
    try {
      // Call the enhanced Vision API function
      return await extractTextAndStructureFromImage(image, Config.visionApiKey);
    } catch (e) {
      print('Enhanced OCR failed: $e');
      // Return a fallback structure
      return {
        'rawText': '',
        'blocks': [],
        'paragraphs': [],
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Parse text into an EventModel
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

  /// Parse structured text data into an EventModel
  static Future<EventModel?> tryParseStructuredEvent(Map<String, dynamic> structuredData) async {
    try {
      // First extract the raw text for compatibility with existing parsers
      final String rawText = structuredData['rawText'] ?? '';

      // Use existing parsers first for compatibility
      EventModel? event = await tryParseEvent(rawText);

      // If we couldn't parse it with existing methods, or we want to enhance the result
      if (event == null || event.title == "Untitled Event") {
        // Extract event data using the structured information
        final eventData = extractEventData(structuredData);

        // Create or enhance the event model
        if (event == null) {
          event = EventModel();
        }

        // Set title if detected and not already set
        if (eventData['titles'].isNotEmpty && (event.title == "Untitled Event" || event.title.isEmpty)) {
          event.title = eventData['titles'][0];
        }

        // Set date if detected and not already set
        if (eventData['dates'].isNotEmpty && event.date == null) {
          // We'd need more sophisticated date parsing here
          // This is a placeholder - in a real implementation, you'd convert the date string to DateTime
          final dateString = eventData['dates'][0];
          try {
            // This is a simplistic approach - you'd need more robust parsing
            final date = DateTime.parse(dateString);
            event.date = date;
          } catch (e) {
            print('Failed to parse date: $dateString, error: $e');
          }
        }

        // Set time if detected and not already set
        if (eventData['times'].isNotEmpty && event.time == null) {
          // We'd need more sophisticated time parsing here
          // This is a placeholder - in a real implementation, you'd convert the time string to TimeOfDay
          final timeString = eventData['times'][0];
          try {
            // Very simplistic approach - you'd need more robust parsing
            // Format expected: HH:MM AM/PM
            final parts = timeString.split(':');
            if (parts.length >= 2) {
              int hour = int.parse(parts[0]);

              // Handle minutes and AM/PM
              String minutePart = parts[1];
              int minute = 0;
              bool isPM = false;

              // Extract minutes
              final minuteMatch = RegExp(r'\d{1,2}').firstMatch(minutePart);
              if (minuteMatch != null) {
                minute = int.parse(minuteMatch.group(0)!);
              }

              // Check for AM/PM
              isPM = minutePart.toLowerCase().contains('pm');
              if (isPM && hour < 12) {
                hour += 12;
              } else if (!isPM && hour == 12) {
                hour = 0;
              }

              event.time = TimeOfDay(hour: hour, minute: minute);
            }
          } catch (e) {
            print('Failed to parse time: $timeString, error: $e');
          }
        }

        // Set location if detected and not already set
        if (eventData['locations'].isNotEmpty &&
            (event.location == "Location TBD" || event.location.isEmpty)) {
          event.location = eventData['locations'][0];
        }
      }

      return event;
    } catch (e) {
      print('Structured parsing failed: $e');
      return null;
    }
  }

  /// Process an image and extract event information, using the most appropriate method
  static Future<List<EventModel>> processEventImage(File image, {bool detectMultiple = true}) async {
    List<EventModel> detectedEvents = [];

    try {
      // Use the enhanced extraction if available
      final structuredData = await extractStructuredText(image);

      // Check if we successfully extracted structured data
      if (structuredData['success'] == true) {
        // Try to parse using structured data
        final event = await tryParseStructuredEvent(structuredData);
        if (event != null) {
          detectedEvents.add(event);
        }

        // If we should detect multiple events
        if (detectMultiple && Config.enableMultiEventDetection) {
          // Try to detect multiple events from blocks or paragraphs
          final blocks = structuredData['blocks'] as List<dynamic>;
          if (blocks.length > 1) {
            // Process each major text block as a potential separate event
            for (int i = 0; i < blocks.length; i++) {
              // Skip the first block if we already processed it
              if (i == 0 && detectedEvents.isNotEmpty) continue;

              final block = blocks[i];
              final blockText = block['text'] as String? ?? '';

              // Only process blocks with enough text
              if (blockText.length > 20) {
                final blockEvent = await tryParseEvent(blockText);
                if (blockEvent != null &&
                    // Avoid duplicate events
                    !detectedEvents.any((e) => e.title == blockEvent.title)) {
                  detectedEvents.add(blockEvent);
                }
              }
            }
          }
        }
      } else {
        // Fallback to traditional text extraction if structured extraction failed
        final rawText = await extractTextOnly(image);
        if (rawText.isNotEmpty) {
          // Try to parse a single event
          final event = await tryParseEvent(rawText);
          if (event != null) {
            detectedEvents.add(event);
          }

          // If we should detect multiple events
          if (detectMultiple && Config.enableMultiEventDetection) {
            // Try to split the text into multiple sections
            final sections = rawText.split(RegExp(r'\n{3,}'));
            if (sections.length > 1) {
              // Process each section as a potential separate event
              for (int i = 0; i < sections.length; i++) {
                // Skip the first section if we already processed it
                if (i == 0 && detectedEvents.isNotEmpty) continue;

                final section = sections[i];

                // Only process sections with enough text
                if (section.length > 20) {
                  final sectionEvent = await tryParseEvent(section);
                  if (sectionEvent != null &&
                      // Avoid duplicate events
                      !detectedEvents.any((e) => e.title == sectionEvent.title)) {
                    detectedEvents.add(sectionEvent);
                  }
                }
              }
            }
          }
        }
      }

      // If we couldn't detect any events, create a blank one
      if (detectedEvents.isEmpty) {
        detectedEvents.add(EventModel(
          title: "New Event",
          date: DateTime.now(),
          time: TimeOfDay.now(),
          location: "Location TBD",
          description: structuredData['rawText'] ?? "",
        ));
      }

      return detectedEvents;
    } catch (e) {
      print('Error processing event image: $e');
      // Return a blank event on error
      return [EventModel(
        title: "New Event",
        date: DateTime.now(),
        time: TimeOfDay.now(),
        location: "Location TBD",
        description: "Error processing image: $e",
      )];
    }
  }
}

