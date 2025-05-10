import 'dart:convert';
import 'dart:math' show min;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import '../event_model.dart';
import 'event_parser.dart';

/// A service to extract event entities from text using Google Natural Language API
class NaturalLanguageService {
  static const String apiBaseUrl = 'https://language.googleapis.com/v1/documents:analyzeEntities';

  /// Main method to extract event entities from text using multiple strategies
  static Future<EventModel> extractEventEntities(String text, String apiKey) async {
    try {
      // STAGE 1: Try specialized format parsers for specific patterns
      final EventModel specialFormat = parseTeamUpFormat(text);

      // If specialized parser found good results, return them
      if (specialFormat.title != "Untitled Event" &&
          (specialFormat.date != null || specialFormat.time != null)) {
        return specialFormat;
      }

      // STAGE 2: Use Google Natural Language API
      if (text.isEmpty) {
        print('Empty text provided to Natural Language API');
        return EventModel(title: "Untitled Event", description: text);
      }

      final requestBody = {
        'document': {
          'type': 'PLAIN_TEXT',
          'content': text,
        },
        'encodingType': 'UTF8',
      };

      try {
        final response = await http.post(
          Uri.parse('$apiBaseUrl?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final nlpEvent = _processEntityData(data, text);

          // STAGE 3: Use regex parser for supplementary details
          final regexEvent = EventParser.parseEventDetails(text);

          // Merge results with priorities
          final EventModel mergedEvent = EventModel(
            title: nlpEvent.title != "Untitled Event" ? nlpEvent.title : regexEvent.title,
            date: nlpEvent.date ?? regexEvent.date,
            time: nlpEvent.time ?? regexEvent.time,
            location: nlpEvent.location != "Location TBD" ? nlpEvent.location : regexEvent.location,
            description: text,
          );

          // STAGE 4: Direct extraction for missing details
          if (mergedEvent.date == null) {
            // Try direct date extraction from text
            final lines = text.split('\n');
            for (final line in lines) {
              final possibleDate = _tryParseDate(line);
              if (possibleDate != null) {
                mergedEvent.date = possibleDate;
                break;
              }
            }
          }

          if (mergedEvent.time == null) {
            // Try direct time extraction from text
            final lines = text.split('\n');
            for (final line in lines) {
              final possibleTime = _tryParseTime(line);
              if (possibleTime != null) {
                mergedEvent.time = possibleTime;
                break;
              }
            }
          }

          return _cleanupEventModel(mergedEvent, text);
        } else {
          print('NL API error: ${response.statusCode}');
          return EventParser.parseEventDetails(text);
        }
      } catch (e) {
        print('Error in NL API processing: $e');
        return EventParser.parseEventDetails(text);
      }
    } catch (e) {
      print('Error in event extraction: $e');
      return EventParser.parseEventDetails(text);
    }
  }

  /// Process entity data from Google Natural Language API
  static EventModel _processEntityData(Map<String, dynamic> data, String originalText) {
    final eventModel = EventModel(
      title: "Untitled Event",
      description: originalText,
    );

    try {
      // First line as fallback title
      final lines = originalText.split('\n');
      if (lines.isNotEmpty) {
        eventModel.title = lines[0].trim();
      }

      // Check if entities exist
      if (!data.containsKey('entities') || data['entities'] == null) {
        print('No entities found in Natural Language API response');
        return eventModel;
      }

      // Process entities
      final entities = data['entities'] as List<dynamic>;

      // Storage for potential data
      final dates = <DateTime>[];
      final locations = <String>[];
      final times = <TimeOfDay>[];
      final events = <String>[];
      final organizations = <String>[];
      final people = <String>[];

      for (var entity in entities) {
        final type = entity['type'] as String? ?? 'UNKNOWN';
        final name = entity['name'] as String? ?? '';
        final mentions = entity['mentions'] as List<dynamic>? ?? [];

        // Get salience (importance)
        double salience = 0.0;
        if (entity.containsKey('salience') && entity['salience'] != null) {
          if (entity['salience'] is double) {
            salience = entity['salience'] as double;
          } else if (entity['salience'] is int) {
            salience = (entity['salience'] as int).toDouble();
          }
        }

        try {
          switch (type) {
            case 'EVENT':
            // Lower threshold to catch more events
              if (salience > 0.05) {
                events.add(name);
              }
              break;

            case 'LOCATION':
              if (name.isNotEmpty) {
                // Check for prominent position in text
                bool isProminent = _isProminent(mentions, originalText);

                // Add to locations list
                if (isProminent) {
                  locations.insert(0, name);
                } else {
                  locations.add(name);
                }
              }
              break;

            case 'DATE':
            // Check for prominent position
              bool isProminent = _isProminent(mentions, originalText);

              // Try metadata for date
              if (entity.containsKey('metadata') &&
                  entity['metadata'] != null &&
                  entity['metadata'] is Map &&
                  entity['metadata'].containsKey('value') &&
                  entity['metadata']['value'] != null) {
                try {
                  final dateString = entity['metadata']['value'].toString();
                  if (dateString.length >= 10) {
                    final date = DateTime.parse(dateString.substring(0, 10));
                    if (isProminent) {
                      dates.insert(0, date);
                    } else {
                      dates.add(date);
                    }
                  }
                } catch (e) {
                  print('Error parsing date from metadata: $e');
                }
              } else {
                // Try to parse date from entity name
                final possibleDate = _tryParseDate(name);
                if (possibleDate != null) {
                  if (isProminent) {
                    dates.insert(0, possibleDate);
                  } else {
                    dates.add(possibleDate);
                  }
                }
              }

              // Check for time component
              final possibleTime = _tryParseTime(name);
              if (possibleTime != null) {
                times.add(possibleTime);
              }

              // Also look for time ranges
              final timeFromContext = _extractTimeFromDateContext(name);
              if (timeFromContext != null) {
                times.add(timeFromContext);
              }
              break;

            case 'TIME':
              final possibleTime = _tryParseTime(name);
              if (possibleTime != null) {
                times.add(possibleTime);
              }

              // Also check for time ranges
              final timeFromContext = _extractTimeFromDateContext(name);
              if (timeFromContext != null) {
                times.add(timeFromContext);
              }
              break;

            case 'ORGANIZATION':
            // Organizations can be venues or event organizers
              if (salience > 0.1 && name.isNotEmpty) {
                organizations.add(name);
              }
              break;

            case 'PERSON':
            // People can be instructors or speakers
              if (salience > 0.1 && name.isNotEmpty) {
                people.add(name);
              }
              break;
          }
        } catch (e) {
          print('Error processing entity of type $type: $e');
        }
      }

      // Set event title by priority
      if (events.isNotEmpty) {
        eventModel.title = events.first;
      } else if (organizations.isNotEmpty && organizations.first.length > 5) {
        // Use organization if it's long enough to be a meaningful title
        eventModel.title = organizations.first;
      }

      // Set date
      if (dates.isNotEmpty) {
        dates.sort(); // Sort chronologically
        eventModel.date = dates.first;
      }

      // Set time
      if (times.isNotEmpty) {
        eventModel.time = times.first;
      }

      // Set location
      if (locations.isNotEmpty) {
        eventModel.location = locations.first;
      } else if (organizations.isNotEmpty && eventModel.location == "Location TBD") {
        // Organizations are sometimes venues
        eventModel.location = organizations.first;
      }

      // If no title yet, check if instructor/person might be relevant
      if (eventModel.title == "Untitled Event" && people.isNotEmpty) {
        // Check if there's a pattern like "Instructor: [Person]"
        if (originalText.toLowerCase().contains("instructor") ||
            originalText.toLowerCase().contains("host") ||
            originalText.toLowerCase().contains("speaker")) {
          eventModel.title = "${people.first} Event";
        }
      }

      return eventModel;
    } catch (e) {
      print('Error in _processEntityData: $e');
      final lines = originalText.split('\n');
      return EventModel(
        title: lines.isNotEmpty ? lines.first.trim() : "Untitled Event",
        description: originalText,
      );
    }
  }

  /// Check if an entity appears prominently in the text
  static bool _isProminent(List<dynamic> mentions, String originalText) {
    for (var mention in mentions) {
      if (mention['text']?['beginOffset'] != null) {
        int offset = mention['text']['beginOffset'];
        // Check if near beginning or after a newline
        if (offset < 100 || originalText.substring(0, offset).contains('\n')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Parse TeamUp and similar calendar formats
  static EventModel parseTeamUpFormat(String text) {
    // 1. TeamUp Classic format
    final classicPattern = RegExp(
      r'(?:Classic|Nurture)\s*\n(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s+\d{1,2}\s+[A-Za-z]{3}\s+\d{4}',
      caseSensitive: true,
    );

    // 2. TeamUp date/time pattern
    final teamUpDateTimePattern = RegExp(
      r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s+(\d{1,2}\s+[A-Za-z]{3}\s+\d{4}),?\s+(\d{1,2}:\d{2})\s*[-–]\s*(\d{1,2}:\d{2})',
      caseSensitive: false,
    );

    // 3. TeamUp/Messenger identifiers
    final teamUpIdentifiers = [
      RegExp(r'goteamup\.com', caseSensitive: false),
      RegExp(r'All times Europe/London', caseSensitive: false),
      RegExp(r'You are attending this class', caseSensitive: false),
          RegExp(r'LEAVE CLASS', caseSensitive: true),
    ];

    // 4. Instructor pattern
    final instructorPattern = RegExp(
      r'Instructor:?\s*\n?(?:JS)?\s*([A-Za-z]+\s+[A-Za-z]+)',
      caseSensitive: false,
    );

    // First check if it's a TeamUp-style event
    bool isTeamUpEvent = false;
    if (classicPattern.hasMatch(text)) {
      isTeamUpEvent = true;
    } else {
      for (final pattern in teamUpIdentifiers) {
        if (pattern.hasMatch(text)) {
          isTeamUpEvent = true;
          break;
        }
      }
    }

    if (!isTeamUpEvent) {
      return EventModel(title: "Untitled Event"); // Not a TeamUp event
    }

    // Look for date/time in TeamUp format
    DateTime? eventDate;
    TimeOfDay? eventTime;

    // Try the structured date/time pattern
    final dateTimeMatch = teamUpDateTimePattern.firstMatch(text);
    if (dateTimeMatch != null && dateTimeMatch.groupCount >= 2) {
      final dateStr = dateTimeMatch.group(1) ?? "";
      final timeStr = dateTimeMatch.group(2) ?? "";

      // Parse date
      eventDate = _tryParseDate(dateStr);

      // Parse time
      eventTime = _tryParseTime(timeStr);
    }

    // If not found, try separate date and time patterns
    if (eventDate == null || eventTime == null) {
      // Try to find date
      final datePattern = RegExp(
        r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s+\d{1,2}\s+[A-Za-z]{3}\s+\d{4}|[A-Za-z]{3}\s+\d{1,2},\s+\d{4}',
        caseSensitive: false,
      );

      // Try to find time
      final timePattern = RegExp(
        r'\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?(?:\s*[-–]\s*|\s+to\s+)\d{1,2}:\d{2}|\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)',
        caseSensitive: false,
      );

      final dateMatch = datePattern.firstMatch(text);
      final timeMatch = timePattern.firstMatch(text);

      // Parse date if found
      if (dateMatch != null) {
        eventDate = _tryParseDate(dateMatch.group(0) ?? "");
      }

      // Parse time if found
      if (timeMatch != null) {
        eventTime = _tryParseTime(timeMatch.group(0) ?? "");
      }
    }

    // Special case for "May 03, 2025" format
    if (eventDate == null) {
      final mayDatePattern = RegExp(r'May (\d{1,2}),? (\d{4})', caseSensitive: true);
      final mayMatch = mayDatePattern.firstMatch(text);

      if (mayMatch != null && mayMatch.groupCount >= 2) {
        try {
          final day = int.parse(mayMatch.group(1) ?? "1");
          final year = int.parse(mayMatch.group(2) ?? "2025");
          eventDate = DateTime(year, 5, day); // May = 5
        } catch (e) {
          print('Error parsing May date: $e');
        }
      }
    }

    // Find title
    String eventTitle = "Untitled Event";

    // First check for "Classic" or "Nurture" title
    final titleMatch = RegExp(r'^(Classic|Nurture)', caseSensitive: true).firstMatch(text);
    if (titleMatch != null) {
      eventTitle = titleMatch.group(1) ?? "Untitled Event";
    } else {
      // Look for instructor
      final instructorMatch = instructorPattern.firstMatch(text);
      if (instructorMatch != null && instructorMatch.groupCount >= 1) {
        final instructor = instructorMatch.group(1)?.trim() ?? "";
        if (instructor.isNotEmpty) {
          eventTitle = "$instructor Event";
        }
      } else {
        // Try first line that's not a date/time or common header
        final lines = text.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty &&
              !_isDateTimeString(trimmed) &&
              !_isCommonHeader(trimmed)) {
            eventTitle = trimmed;
            break;
          }
        }
      }
    }

    // Extract location
    String location = "Location TBD";
    if (text.contains("Europe/London")) {
      location = "London";
    } else if (text.contains("Europe")) {
      location = "Europe";
    }

    // Return event if we found useful information
    if (eventDate != null || eventTime != null) {
      return EventModel(
        title: eventTitle,
        date: eventDate,
        time: eventTime,
        location: location,
        description: text,
      );
    }

    // Not enough information found
    return EventModel(title: "Untitled Event");
  }

  /// Check if string contains date or time patterns
  static bool _isDateTimeString(String text) {
    final dateTimePatterns = [
      RegExp(r'\d{1,2}:\d{2}'),                 // HH:MM
      RegExp(r'\d{1,2}\s*(?:AM|PM|am|pm)'),     // HH AM/PM
      RegExp(r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'), // Month
      RegExp(r'\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}'), // MM/DD/YYYY
      RegExp(r'(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)'), // Day
    ];

    for (final pattern in dateTimePatterns) {
      if (pattern.hasMatch(text)) {
        return true;
      }
    }

    return false;
  }

  /// Check if a string is a common header to ignore
  static bool _isCommonHeader(String text) {
    final lowerText = text.toLowerCase();
    final commonHeaders = [
      'event details', 'details', 'overview', 'hide', 'instructor:',
      'all times', 'you\'re attending', 'leave class', 'event description',
      'about', 'calendar', 'agenda'
    ];

    for (final header in commonHeaders) {
      if (lowerText.contains(header)) {
        return true;
      }
    }

    return false;
  }

  /// Extract time from a string with time range
  static TimeOfDay? _extractTimeFromDateContext(String dateContext) {
    // Look for time range patterns
    final timeRangePattern = RegExp(
      r'(\d{1,2}):?(\d{2})?\s*(?:am|pm|AM|PM)?(?:\s*[-–]\s*|\s*to\s*)(\d{1,2}):?(\d{2})?\s*(?:am|pm|AM|PM)?',
    );

    final match = timeRangePattern.firstMatch(dateContext);
    if (match != null) {
      try {
        // Extract start time
        int hour = int.parse(match.group(1)!);
        int minute = 0;

        if (match.group(2) != null && match.group(2)!.isNotEmpty) {
          minute = int.parse(match.group(2)!);
        }

        // Check for AM/PM
        bool isPM = false;
        if (dateContext.toLowerCase().contains('pm')) {
          isPM = true;
        }

        // Apply 12-hour clock conversion
        if (isPM && hour < 12) {
          hour += 12;
        } else if (!isPM && hour == 12) {
          hour = 0;
        }

        return TimeOfDay(hour: hour, minute: minute);
      } catch (e) {
        print('Error extracting time from range: $e');
      }
    }

    return null;
  }

  /// Try to parse date with enhanced format support
  static DateTime? _tryParseDate(String dateStr) {
    // Standard date formats
    final formats = [
      'yyyy-MM-dd',          // ISO format
      'MM/dd/yyyy',          // US format
      'dd/MM/yyyy',          // European format
      'MMMM d, yyyy',        // May 3, 2025
      'MMMM d yyyy',         // May 3 2025
      'd MMMM yyyy',         // 3 May 2025
      'MMM d, yyyy',         // May 3, 2025
      'EEE, d MMM yyyy',     // Fri, 3 May 2025
      'd MMM yyyy',          // 3 May 2025
      'EEE d MMM yyyy',      // Fri 3 May 2025
      'yyyy/MM/dd',          // 2025/05/03
      'dd-MM-yyyy',          // 03-05-2025
      'dd.MM.yyyy',          // 03.05.2025
    ];

    // Try each format
    for (final format in formats) {
      try {
        return DateFormat(format).parse(dateStr);
      } catch (e) {
        // Try next format
      }
    }

    // Try specific TeamUp pattern: "Sat, 3 May 2025"
    final teamUpPattern = RegExp(
      r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})',
      caseSensitive: false,
    );

    final teamUpMatch = teamUpPattern.firstMatch(dateStr);
    if (teamUpMatch != null && teamUpMatch.groupCount >= 3) {
      try {
        final day = int.parse(teamUpMatch.group(1) ?? "1");
        final monthText = teamUpMatch.group(2) ?? "";
        final year = int.parse(teamUpMatch.group(3) ?? "2025");

        // Map month name to number
        final Map<String, int> monthMap = {
          'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
          'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
        };

        final month = monthMap[monthText] ?? 1;
        return DateTime(year, month, day);
      } catch (e) {
        print('Error parsing TeamUp date: $e');
      }
    }

    // Try May format: "May 3, 2025"
    final mayPattern = RegExp(r'May\s+(\d{1,2})(?:,|\s)+(\d{4})', caseSensitive: true);
    final mayMatch = mayPattern.firstMatch(dateStr);

    if (mayMatch != null && mayMatch.groupCount >= 2) {
      try {
        final day = int.parse(mayMatch.group(1) ?? "1");
        final year = int.parse(mayMatch.group(2) ?? "2025");
        return DateTime(year, 5, day); // May = 5
      } catch (e) {
        print('Error parsing May date: $e');
      }
    }

    // Try MM/DD/YYYY or DD/MM/YYYY format
    final slashPattern = RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})');
    final slashMatch = slashPattern.firstMatch(dateStr);

    if (slashMatch != null && slashMatch.groupCount >= 3) {
      try {
        final num1 = int.parse(slashMatch.group(1) ?? "1");
        final num2 = int.parse(slashMatch.group(2) ?? "1");
        int year = int.parse(slashMatch.group(3) ?? "2025");

        // Handle 2-digit years
        if (year < 100) {
          year += 2000;
        }

        // Try to determine format
        if (num1 > 12) {
          // DD/MM/YYYY
          return DateTime(year, num2, num1);
        } else if (num2 > 12) {
          // MM/DD/YYYY
          return DateTime(year, num1, num2);
        } else {
          // Ambiguous - prefer MM/DD/YYYY
          return DateTime(year, num1, num2);
        }
      } catch (e) {
        print('Error parsing slash date: $e');
      }
    }

    // Handle relative dates
    final lowerStr = dateStr.toLowerCase();
    final now = DateTime.now();

    if (lowerStr.contains('tomorrow')) {
      return now.add(const Duration(days: 1));
    } else if (lowerStr.contains('today')) {
      return now;
    }

    return null;
  }

  /// Try to parse time from string
  static TimeOfDay? _tryParseTime(String timeStr) {
    // Time with colon and optional AM/PM
    final colonTimePattern = RegExp(r'(\d{1,2}):(\d{2})(?:\s*(AM|PM|am|pm))?');

    // Time without colon but with AM/PM
    final noColonTimePattern = RegExp(r'(\d{1,2})\s*(AM|PM|am|pm)');

    // Check for time with colon
    final colonMatch = colonTimePattern.firstMatch(timeStr);
    if (colonMatch != null && colonMatch.groupCount >= 2) {
      try {
        int hour = int.parse(colonMatch.group(1) ?? "0");
        final minute = int.parse(colonMatch.group(2) ?? "0");
        final ampm = colonMatch.group(3)?.toLowerCase();

        // Handle AM/PM
        if (ampm == 'pm' && hour < 12) {
          hour += 12;
        } else if (ampm == 'am' && hour == 12) {
          hour = 0;
        }

        return TimeOfDay(hour: hour, minute: minute);
      } catch (e) {
        print('Error parsing colon time: $e');
      }
    }

    // Check for time without colon
    final noColonMatch = noColonTimePattern.firstMatch(timeStr);
    if (noColonMatch != null && noColonMatch.groupCount >= 2) {
      try {
        int hour = int.parse(noColonMatch.group(1) ?? "0");
        final ampm = noColonMatch.group(2)?.toLowerCase();

        // Handle AM/PM
        if (ampm == 'pm' && hour < 12) {
          hour += 12;
        } else if (ampm == 'am' && hour == 12) {
          hour = 0;
        }

        return TimeOfDay(hour: hour, minute: 0);
      } catch (e) {
        print('Error parsing no-colon time: $e');
      }
    }

    // Check for time range and extract first time
    final rangePattern = RegExp(r'(\d{1,2}):(\d{2})(?:\s*[-–]\s*|\s+to\s+)');
    final rangeMatch = rangePattern.firstMatch(timeStr);

    if (rangeMatch != null && rangeMatch.groupCount >= 2) {
      try {
        int hour = int.parse(rangeMatch.group(1) ?? "0");
        final minute = int.parse(rangeMatch.group(2) ?? "0");

        // Check for AM/PM
        final isPM = timeStr.toLowerCase().contains('pm');

        // Handle AM/PM
        if (isPM && hour < 12) {
          hour += 12;
        }

        return TimeOfDay(hour: hour, minute: minute);
      } catch (e) {
        print('Error parsing time range: $e');
      }
    }

    return null;
  }

  /// Final cleanup of event model
  static EventModel _cleanupEventModel(EventModel event, String originalText) {
    // Don't modify if we don't have a proper event
    if (event.title == "Untitled Event" && event.date == null && event.time == null) {
      return event;
    }

    // Clean up title - remove trailing punctuation
    if (event.title != "Untitled Event") {
      event.title = event.title.replaceAll(RegExp(r'[:;.,\s]+$'), '').trim();
    }

    // If title contains date/time, try to find a better title
    if (_isDateTimeString(event.title)) {
      final lines = originalText.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty &&
            !_isDateTimeString(trimmed) &&
            !_isCommonHeader(trimmed) &&
            trimmed.length > 3) {
          event.title = trimmed;
          break;
        }
      }
    }

    // Ensure description is set
    if (event.description.isEmpty) {
      event.description = originalText;
    }

    return event;
  }
}