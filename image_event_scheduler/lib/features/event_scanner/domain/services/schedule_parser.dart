import '../event_model.dart';
import '../schedule_model.dart';
import 'event_parser.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class ScheduleParser {
  static ScheduleModel parseSchedule(String ocrText, Map<String, dynamic> visionResponse) {
    try {
      // Extract the common schedule title (usually first line)
      final List<String> lines = ocrText.split('\n');
      final String scheduleTitle = lines.isNotEmpty ? lines[0] : "Untitled Schedule";

      // Try to extract a common location and date if applicable
      String commonLocation = _extractCommonLocation(ocrText);
      DateTime? commonDate = _extractCommonDate(ocrText);

      // Process the structured data from Vision API response
      List<EventModel> events = _extractEventsFromStructuredData(ocrText, visionResponse);

      // If structured approach didn't yield multiple events, try rules-based approach
      if (events.length <= 1) {
        events = _extractEventsWithRules(ocrText);
      }

      // If we still don't have multiple events, create at least one with traditional parser
      if (events.isEmpty) {
        events = [EventParser.parseEventDetails(ocrText)];
      }

      // Apply common date and location if individual events don't have them set
      events = _applyCommonProperties(events, commonDate, commonLocation);

      return ScheduleModel(
        title: scheduleTitle,
        scheduleDate: commonDate,
        location: commonLocation,
        events: events,
        rawText: ocrText,
      );
    } catch (e) {
      print('Error parsing schedule: $e');
      // Fallback - create a ScheduleModel with a single event
      return ScheduleModel(
        title: "Recovered Schedule",
        events: [EventParser.parseEventDetails(ocrText)],
        rawText: ocrText,
      );
    }
  }

  static String _extractCommonLocation(String text) {
    // Check for location that appears to apply to the entire schedule
    final commonLocationPatterns = [
      RegExp(r'Location[:\s]+([^\n\.]+)', caseSensitive: false),
      RegExp(r'Venue[:\s]+([^\n\.]+)', caseSensitive: false),
      RegExp(r'Place[:\s]+([^\n\.]+)', caseSensitive: false),
      RegExp(r'at\s+the\s+([^\n\.]+(?:Center|Theatre|Theater|Hall|Stadium|Arena))', caseSensitive: false),
    ];

    for (final pattern in commonLocationPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        return match.group(1)!.trim();
      }
    }

    return "Location TBD";
  }

  static DateTime? _extractCommonDate(String text) {
    // Look for a date that appears to apply to the entire schedule
    final commonDatePatterns = [
      RegExp(r'Date[:\s]+([^\n\.]+)', caseSensitive: false),
      RegExp(r'Schedule for[:\s]+([^\n\.]+)', caseSensitive: false),
      RegExp(r'(?:on|for)\s+(\d{1,2}(?:st|nd|rd|th)?\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*(?:\s+\d{4})?)', caseSensitive: false),
    ];

    for (final pattern in commonDatePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final dateString = match.group(1)!.trim();
        return EventParser.parseDateWithMultipleFormats(dateString);
      }
    }

    return null;
  }

  static List<EventModel> _extractEventsFromStructuredData(String ocrText, Map<String, dynamic> visionResponse) {
    List<EventModel> events = [];

    try {
      // Extract blocks that represent table structures if available
      if (visionResponse.containsKey('fullTextAnnotation') &&
          visionResponse['fullTextAnnotation'].containsKey('pages')) {

        final pages = visionResponse['fullTextAnnotation']['pages'];

        for (final page in pages) {
          if (page.containsKey('blocks')) {
            for (final block in page['blocks']) {
              // Check if this is a table block
              if (block.containsKey('blockType') &&
                  block['blockType'] == 'TABLE') {
                events.addAll(_processTableBlock(block));
              }
            }
          }
        }
      }

      // Use text blocks and their positions to identify event groups
      if (visionResponse.containsKey('textAnnotations')) {
        final textAnnotations = visionResponse['textAnnotations'];
        if (textAnnotations.length > 1) { // Skip the first one which is full text
          events.addAll(_processTextBlocks(textAnnotations.sublist(1)));
        }
      }
    } catch (e) {
      print('Error extracting structured data: $e');
    }

    return events;
  }

  static List<EventModel> _processTableBlock(Map<String, dynamic> tableBlock) {
    List<EventModel> events = [];

    // Extract rows and columns from the table
    // This is a simplified implementation - real tables would need more complex analysis
    try {
      if (tableBlock.containsKey('rows')) {
        // Determine if the first row contains headers
        final rows = tableBlock['rows'];
        bool hasHeaderRow = false;
        List<String> headers = [];

        if (rows.length > 1) {
          hasHeaderRow = true;
          // Extract headers from first row
          final headerRow = rows[0];
          if (headerRow.containsKey('cells')) {
            for (final cell in headerRow['cells']) {
              if (cell.containsKey('text')) {
                headers.add(cell['text']);
              } else {
                headers.add(''); // Empty header
              }
            }
          }
        }

        // Process data rows
        for (int i = hasHeaderRow ? 1 : 0; i < rows.length; i++) {
          final row = rows[i];
          if (row.containsKey('cells')) {
            final cells = row['cells'];

            // Check if this row contains enough data to form an event
            if (cells.length >= 2) {
              // Create event from row data
              String title = '';
              String dateTimeStr = '';
              String location = '';

              // Apply headers if they exist, otherwise use position-based logic
              if (hasHeaderRow && headers.length == cells.length) {
                for (int j = 0; j < cells.length; j++) {
                  final headerText = headers[j].toLowerCase();
                  final cellText = cells[j]['text'] ?? '';

                  if (headerText.contains('event') ||
                      headerText.contains('title') ||
                      headerText.contains('description')) {
                    title = cellText;
                  } else if (headerText.contains('date') ||
                      headerText.contains('time') ||
                      headerText.contains('when')) {
                    dateTimeStr = cellText;
                  } else if (headerText.contains('location') ||
                      headerText.contains('venue') ||
                      headerText.contains('where')) {
                    location = cellText;
                  }
                }
              } else {
                // No headers, use position-based inference
                // Assume first column is title/description, second is date/time
                title = cells[0]['text'] ?? '';
                dateTimeStr = cells.length > 1 ? cells[1]['text'] ?? '' : '';
                location = cells.length > 2 ? cells[2]['text'] ?? '' : '';
              }

              // Parse date and time
              DateTime? date;
              TimeOfDay? time;

              if (dateTimeStr.isNotEmpty) {
                date = EventParser.extractEventDate(dateTimeStr, [dateTimeStr]);
                time = EventParser.extractEventTime(dateTimeStr);
              }

              // Create event if we have at least a title
              if (title.isNotEmpty) {
                events.add(EventModel(
                  title: title,
                  date: date,
                  time: time,
                  location: location,
                  description: title,
                ));
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error processing table block: $e');
    }

    return events;
  }

  static List<EventModel> _processTextBlocks(List<dynamic> textAnnotations) {
    List<EventModel> events = [];

    // Group text blocks by vertical position (y-coordinate)
    // This is a simplified approach - more sophisticated grouping would be needed
    Map<int, List<Map<String, dynamic>>> rowGroups = {};

    for (final annotation in textAnnotations) {
      if (annotation.containsKey('boundingPoly') &&
          annotation.containsKey('description')) {
        // Calculate center y-coordinate of the bounding box
        final vertices = annotation['boundingPoly']['vertices'];
        if (vertices.length == 4) {
          final y1 = vertices[0]['y'] is int ? vertices[0]['y'] : 0;
          final y2 = vertices[2]['y'] is int ? vertices[2]['y'] : 0;
          final centerY = ((y1 + y2) / 2).round();

          // Group with tolerance of 10 pixels
          int groupKey = (centerY / 10).round() * 10;

          if (!rowGroups.containsKey(groupKey)) {
            rowGroups[groupKey] = [];
          }

          rowGroups[groupKey]!.add({
            'text': annotation['description'],
            'x': vertices[0]['x'] is int ? vertices[0]['x'] : 0,
            'y': centerY,
          });
        }
      }
    }

    // Sort row groups by vertical position
    final sortedKeys = rowGroups.keys.toList()..sort();

    // Process rows to extract events
    String currentTitle = '';
    String currentDateTimeStr = '';
    String currentLocation = '';

    for (final key in sortedKeys) {
      // Sort by x-coordinate within this row
      final row = rowGroups[key]!..sort((a, b) => a['x'].compareTo(b['x']));

      // Build text for this row
      final rowText = row.map((item) => item['text']).join(' ');

      // Check what kind of information this row might contain
      if (_containsDateOrTime(rowText)) {
        // This row has date/time information
        if (currentTitle.isNotEmpty) {
          // We have a title from previous rows, so create an event
          DateTime? date = EventParser.extractEventDate(rowText, [rowText]);
          TimeOfDay? time = EventParser.extractEventTime(rowText);

          events.add(EventModel(
            title: currentTitle,
            date: date,
            time: time,
            location: currentLocation.isNotEmpty ? currentLocation : "Location TBD",
            description: '$currentTitle $rowText',
          ));

          // Reset for next event
          currentTitle = '';
          currentDateTimeStr = '';
          currentLocation = '';
        } else {
          // Store date/time for upcoming title
          currentDateTimeStr = rowText;
        }
      } else if (_containsLocation(rowText)) {
        // This row has location information
        currentLocation = rowText;
      } else if (rowText.length > 5 && !_isLikelyHeaderOrFooter(rowText)) {
        // This might be a title
        if (currentTitle.isNotEmpty && currentDateTimeStr.isNotEmpty) {
          // We already have a title and date/time, so create an event
          DateTime? date = EventParser.extractEventDate(currentDateTimeStr, [currentDateTimeStr]);
          TimeOfDay? time = EventParser.extractEventTime(currentDateTimeStr);

          events.add(EventModel(
            title: currentTitle,
            date: date,
            time: time,
            location: currentLocation.isNotEmpty ? currentLocation : "Location TBD",
            description: '$currentTitle $currentDateTimeStr',
          ));

          // Reset and start new event
          currentTitle = rowText;
          currentDateTimeStr = '';
          currentLocation = '';
        } else {
          // First title we've encountered
          currentTitle = rowText;
        }
      }
    }

    // Handle any remaining event data
    if (currentTitle.isNotEmpty && currentDateTimeStr.isNotEmpty) {
      DateTime? date = EventParser.extractEventDate(currentDateTimeStr, [currentDateTimeStr]);
      TimeOfDay? time = EventParser.extractEventTime(currentDateTimeStr);

      events.add(EventModel(
        title: currentTitle,
        date: date,
        time: time,
        location: currentLocation.isNotEmpty ? currentLocation : "Location TBD",
        description: '$currentTitle $currentDateTimeStr',
      ));
    }

    return events;
  }

  static bool _containsDateOrTime(String text) {
    return RegExp(r'\d{1,2}[\/\.-]\d{1,2}|(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)|(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)|(?:\d{1,2}:\d{2})|(?:\d{1,2}\s*(?:am|pm))', caseSensitive: false).hasMatch(text);
  }

  static bool _containsLocation(String text) {
    return RegExp(r'(?:room|hall|theater|theatre|stadium|center|venue|building|floor|suite|plaza|arena)', caseSensitive: false).hasMatch(text);
  }

  static bool _isLikelyHeaderOrFooter(String text) {
    return RegExp(r'(?:page|copyright|all rights reserved|schedule|timetable|program)', caseSensitive: false).hasMatch(text);
  }

  static List<EventModel> _extractEventsWithRules(String ocrText) {
    List<EventModel> events = [];

    // Split the text into lines
    final List<String> lines = ocrText.split('\n');

    // Pattern for lines that look like they could start a new event
// Numbered item (e.g. "1. Event")
    final numberedPattern = RegExp(r'^\d+\.\s+[A-Z]');

// Bullet point item (e.g. "• Event" or "* Event")
    final bulletPattern = RegExp(r'^\*\s+[A-Z]');

// Hyphen item (e.g. "- Event")
    final hyphenPattern = RegExp(r'^-\s+[A-Z]');

// Parenthesis numbered (e.g. "(1) Event")
    final parenthesisPattern = RegExp(r'^\(\d+\)\s+[A-Z]');

// Capitalized text that might be an event title
    final capitalizedPattern = RegExp(r'^[A-Z][a-zA-Z0-9\s]+');

// Function to check if a line might be an event start
    bool isLikelyEventStart(String line) {
      return numberedPattern.hasMatch(line) ||
          bulletPattern.hasMatch(line) ||
          hyphenPattern.hasMatch(line) ||
          parenthesisPattern.hasMatch(line) ||
          (capitalizedPattern.hasMatch(line) && line.contains(':'));
    }
    // Process the lines
    int i = 0;
    while (i < lines.length) {
      if (isLikelyEventStart(lines[i])) {
        String eventText = lines[i];
        int j = i + 1;

        // Collect lines that are part of this event
        // (until we hit another line that looks like an event start)
        while (j < lines.length && !isLikelyEventStart(lines[j])) {
          eventText += '\n' + lines[j];
          j++;
        }

        // Parse this event text chunk
        final event = EventParser.parseEventDetails(eventText);

        // Only add if we have a reasonable title
        if (event.title.length > 3) {
          events.add(event);
        }

        // Move to the next potential event
        i = j;
      } else {
        // Not an event start, move to next line
        i++;
      }
    }

    // Calendar events often have a list of days with activities
    if (events.isEmpty) {
      events = _extractCalendarEvents(lines);
    }

    return events;
  }

  static List<EventModel> _extractCalendarEvents(List<String> lines) {
    List<EventModel> events = [];

    // Pattern for days of the week
    final dayPattern = RegExp(r'^(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tue|Wed|Thu|Fri|Sat|Sun)\.?(?:,|:|\s-|\s+\d|\s+[A-Z])', caseSensitive: false);

    DateTime? currentDate;
    String currentLocation = "Location TBD";

    for (int i = 0; i < lines.length; i++) {
      // Check if this line contains a day of the week
      if (dayPattern.hasMatch(lines[i])) {
        // Extract date from this line
        currentDate = EventParser.extractEventDate(lines[i], [lines[i]]);

        // Look ahead for activities on this day
        int j = i + 1;
        while (j < lines.length && !dayPattern.hasMatch(lines[j])) {
          String activityLine = lines[j];

          // Check if this line has enough content to be an activity
          if (activityLine.length > 5) {
            // Try to extract time
            TimeOfDay? activityTime = EventParser.extractEventTime(activityLine);

            // Extract title
            String title = activityLine;

            // If we have a time, remove it from the title
            if (activityTime != null) {
              title = title.replaceAll(RegExp(r'\d{1,2}:\d{2}(?:\s*(?:AM|PM|am|pm))?'), '').trim();
              title = title.replaceAll(RegExp(r'\d{1,2}\s*(?:AM|PM|am|pm)'), '').trim();
            }

            // Clean up title
            title = title.replaceAll(RegExp(r'^[-:•*\s]+'), '').trim();

            // Create event if we have a reasonable title
            if (title.length > 3) {
              events.add(EventModel(
                title: title,
                date: currentDate,
                time: activityTime,
                location: currentLocation,
                description: activityLine,
              ));
            }
          }

          j++;
        }

        // Move to the next day
        i = j - 1;
      } else if (_containsLocation(lines[i])) {
        // Update current location
        currentLocation = lines[i];
      }
    }

    return events;
  }

  static List<EventModel> _applyCommonProperties(List<EventModel> events, DateTime? commonDate, String commonLocation) {
    return events.map((event) {
      // Apply common date if event doesn't have one
      final DateTime? eventDate = event.date ?? commonDate;

      // Apply common location if event doesn't have one
      final String eventLocation = event.location == "Location TBD" ? commonLocation : event.location;

      // Return new event with potentially updated fields
      return EventModel(
        title: event.title,
        date: eventDate,
        time: event.time,
        location: eventLocation,
        description: event.description,
      );
    }).toList();
  }
}