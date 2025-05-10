import 'package:intl/intl.dart';
import '../event_model.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// EventParser class to handle parsing of event details from OCR text
class EventParser {
  /// Parse raw OCR text into structured event information
  static EventModel parseEventDetails(String ocrText) {
    final List<String> lines = ocrText.split('\n');

    // Default title to first line, or "Untitled Event" if no text
    final String title = lines.isNotEmpty ? lines[0] : "Untitled Event";

    // Extract date, time and location using enhanced methods
    DateTime? eventDate = extractEventDate(ocrText, lines);
    TimeOfDay? eventTime = extractEventTime(ocrText);
    String location = extractLocation(ocrText, lines);

    // Create and return event model
    return EventModel(
      title: title,
      date: eventDate,
      time: eventTime,
      location: location,
      description: ocrText,
    );
  }

  /// Extract date from OCR text using multiple detection strategies
  static DateTime? extractEventDate(String ocrText, List<String> lines) {
    // Define regex patterns for date detection
    final RegExp datePattern = RegExp(
      // Full month name formats
      r'\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?(?:,)?\s+\d{4}\b|'
      // Abbreviated month formats with year
      r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,)?\s+\d{4}\b|'
      // Day first with month name
      r'\b\d{1,2}(?:st|nd|rd|th)?\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?(?:,)?\s+\d{4}\b|'
      // Common date separators (/, -, .)
      r'\b\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}\b|'
      // ISO format
      r'\b\d{4}[/.-]\d{1,2}[/.-]\d{1,2}\b|'
      // Short month formats without year
      r'\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?\b|'
      // Day + month name without year
      r'\b\d{1,2}(?:st|nd|rd|th)?\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\b|'
      // Month name + day without year
      r'\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?\b|'
      // Day of week + month + day
      r'\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tues|Tue|Wed|Thurs|Thu|Fri|Sat|Sun)\.?,?\s+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?\b',
      caseSensitive: false,
    );

    // Patterns for context-aware date extraction
    final RegExp dateContextPattern = RegExp(
      r'\b(?:held on|on|date[s]?|scheduled for|event date|opening|happening on)\s+([^\n\.]+)',
      caseSensitive: false,
    );

    // Extract day of week separately to help with context
    final RegExp weekdayPattern = RegExp(
      r'\b(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday|Mon|Tues|Tue|Wed|Thurs|Thu|Fri|Sat|Sun)\.?\b',
      caseSensitive: false,
    );

    // Multiple date detection strategies
    DateTime? eventDate;

    // STRATEGY 1: Look for explicit date indicators
    final dateContextMatch = dateContextPattern.firstMatch(ocrText);
    if (dateContextMatch != null && dateContextMatch.groupCount >= 1) {
      String dateContext = dateContextMatch.group(1)!;
      final dateInContextMatch = datePattern.firstMatch(dateContext);
      if (dateInContextMatch != null) {
        final dateStr = dateInContextMatch.group(0)!;
        eventDate = parseDateWithMultipleFormats(dateStr);
      }
    }

    // STRATEGY 2: Look for standard date patterns
    if (eventDate == null) {
      final dateMatch = datePattern.firstMatch(ocrText);
      if (dateMatch != null) {
        final dateStr = dateMatch.group(0)!;
        eventDate = parseDateWithMultipleFormats(dateStr);
      }
    }

    // STRATEGY 3: Check for date ranges and extract start date
    if (eventDate == null) {
      final dateRangePattern = RegExp(
        r'\b(?:from|between)?\s*(\d{1,2}(?:st|nd|rd|th)?(?:\s+)?(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?)\s*(?:-|to|until|through|–)\s*(\d{1,2}(?:st|nd|rd|th)?(?:\s+)?(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?)',
        caseSensitive: false,
      );

      final rangeMatch = dateRangePattern.firstMatch(ocrText);
      if (rangeMatch != null && rangeMatch.groupCount >= 1) {
        // Extract start date from range
        final startDateStr = rangeMatch.group(1)!;
        eventDate = parseDateWithMultipleFormats(startDateStr);
      }
    }

    // STRATEGY 4: Look for day-month patterns near event-related words
    if (eventDate == null) {
      final eventWordsPattern = RegExp(
        r'\b(?:event|concert|show|exhibition|performance|festival|party|meeting|conference|seminar|webinar|workshop|class|session)\b',
        caseSensitive: false,
      );

      final eventMatch = eventWordsPattern.firstMatch(ocrText);
      if (eventMatch != null) {
        // Check nearby text for date patterns
        final int matchPos = eventMatch.start;
        final int searchStart = matchPos > 50 ? matchPos - 50 : 0;
        final int searchEnd = matchPos + 100 < ocrText.length ? matchPos + 100 : ocrText.length;

        final String nearbyText = ocrText.substring(searchStart, searchEnd);
        final nearbyDateMatch = datePattern.firstMatch(nearbyText);

        if (nearbyDateMatch != null) {
          final dateStr = nearbyDateMatch.group(0)!;
          eventDate = parseDateWithMultipleFormats(dateStr);
        }
      }
    }

    // STRATEGY 5: Extract from weekday + numeric day pattern
    if (eventDate == null) {
      final weekdayMatch = weekdayPattern.firstMatch(ocrText);
      if (weekdayMatch != null) {
        // Get the matched weekday and look for a nearby date or day number
        final int startPos = weekdayMatch.start;
        final int endPos = weekdayMatch.end;

        // Check if there's a number within 10 characters after the weekday
        final RegExp nearbyNumberPattern = RegExp(r'\b\d{1,2}\b');
        final String textAfterWeekday = ocrText.substring(endPos,
            endPos + 20 > ocrText.length ? ocrText.length : endPos + 20);

        final nearbyNumberMatch = nearbyNumberPattern.firstMatch(textAfterWeekday);
        if (nearbyNumberMatch != null) {
          // Try to figure out which month it might be
          final currentMonth = DateTime.now().month;
          final dayNumber = int.parse(nearbyNumberMatch.group(0)!);

          // Create a date in current month
          DateTime possibleDate = DateTime(DateTime.now().year, currentMonth, dayNumber);

          // Adjust to next month if the day is in the past
          if (possibleDate.isBefore(DateTime.now())) {
            possibleDate = DateTime(DateTime.now().year,
                currentMonth < 12 ? currentMonth + 1 : 1, dayNumber);
          }

          // Set this as our event date
          eventDate = possibleDate;
        }
      }
    }

    // STRATEGY 6: Simple numeric dates (as last resort)
    if (eventDate == null) {
      // Look for standalone day numbers that might be event dates
      for (String line in lines) {
        // Skip very short lines
        if (line.length < 3) continue;

        // Look for lines that are just numbers between 1-31 (likely dates)
        if (RegExp(r'^\s*\d{1,2}\s*$').hasMatch(line)) {
          try {
            int day = int.parse(line.trim());
            if (day >= 1 && day <= 31) {
              // Assume current/next month
              final now = DateTime.now();
              int month = now.month;
              int year = now.year;

              // Create date object
              DateTime possibleDate = DateTime(year, month, day);

              // If date is in the past, move to next month
              if (possibleDate.isBefore(now)) {
                month = month < 12 ? month + 1 : 1;
                year = month == 1 ? year + 1 : year;
                possibleDate = DateTime(year, month, day);
              }

              eventDate = possibleDate;
              break;
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }
      }
    }

    return eventDate;
  }

  /// Helper method to parse dates with multiple format attempts
  static DateTime? parseDateWithMultipleFormats(String dateStr) {
    DateTime? parsedDate;

    try {
      // First try formats with year
      final formats = [
        'MMMM d, yyyy', 'MMMM d yyyy', 'd MMMM yyyy',
        'd MMM yyyy', 'MM/dd/yyyy', 'dd/MM/yyyy',
        'MM-dd-yyyy', 'dd-MM-yyyy', 'yyyy-MM-dd',
        'MMM d, yyyy', 'MMM d yyyy', 'd MMM, yyyy',
        'EEEE, MMMM d, yyyy', 'EEEE, MMM d, yyyy'
      ];

      for (final format in formats) {
        try {
          parsedDate = DateFormat(format).parse(dateStr);
          break;
        } catch (e) {
          // Try next format
        }
      }

      // If no date with year was found, try without year (assume current year)
      if (parsedDate == null) {
        final currentYear = DateTime.now().year;
        // Try to add year if it doesn't have one
        String dateWithYearStr = dateStr;
        if (!dateStr.contains(currentYear.toString())) {
          dateWithYearStr = '$dateStr, $currentYear';
        }

        final formatsWithoutYear = [
          'MMMM d, yyyy', 'd MMMM, yyyy', 'MMM d, yyyy',
          'EEEE, MMMM d, yyyy', 'EEEE, MMM d, yyyy',
          'd MMM, yyyy'
        ];

        for (final format in formatsWithoutYear) {
          try {
            parsedDate = DateFormat(format).parse(dateWithYearStr);
            break;
          } catch (e) {
            // Try next format
          }
        }
      }

      // For day and month only formats (no year mentioned)
      if (parsedDate == null) {
        final currentYear = DateTime.now().year;
        final monthDayFormats = [
          'MMMM d', 'd MMMM', 'MMM d', 'd MMM',
          'EEEE, MMMM d', 'EEEE, d MMMM',
          'EEEE MMM d', 'EEEE d MMM'
        ];

        for (final format in monthDayFormats) {
          try {
            // Parse without year, then add current year
            parsedDate = DateFormat(format).parse(dateStr);
            if (parsedDate != null) {
              // Recreate with current year
              parsedDate = DateTime(
                currentYear,
                parsedDate.month,
                parsedDate.day,
              );

              // If date is in the past, assume next year
              if (parsedDate!.isBefore(DateTime.now())) {
                parsedDate = DateTime(
                  currentYear + 1,
                  parsedDate.month,
                  parsedDate.day,
                );
              }
              break;
            }
          } catch (e) {
            // Try next format
          }
        }
      }

      // For numeric formats like MM/DD or DD/MM
      if (parsedDate == null && RegExp(r'\d{1,2}[/.-]\d{1,2}').hasMatch(dateStr)) {
        final currentYear = DateTime.now().year;
        final parts = dateStr.split(RegExp(r'[/.-]'));

        if (parts.length >= 2) {
          try {
            // Try MM/DD format
            int month = int.parse(parts[0]);
            int day = int.parse(parts[1]);

            if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
              parsedDate = DateTime(currentYear, month, day);

              // If date is in the past, assume next year
              if (parsedDate!.isBefore(DateTime.now())) {
                parsedDate = DateTime(currentYear + 1, month, day);
              }
            }
          } catch (e) {
            // Try next approach
          }

          // If MM/DD didn't work, try DD/MM format
          if (parsedDate == null) {
            try {
              int day = int.parse(parts[0]);
              int month = int.parse(parts[1]);

              if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
                parsedDate = DateTime(currentYear, month, day);

                // If date is in the past, assume next year
                if (parsedDate!.isBefore(DateTime.now())) {
                  parsedDate = DateTime(currentYear + 1, month, day);
                }
              }
            } catch (e) {
              // Ignore parsing errors
            }
          }
        }
      }

      // Extract from day+month text components
      if (parsedDate == null) {
        final dayPattern = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?\b');
        final monthPattern = RegExp(r'\b(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\b', caseSensitive: false);

        final dayMatch = dayPattern.firstMatch(dateStr);
        final monthMatch = monthPattern.firstMatch(dateStr);

        if (dayMatch != null && monthMatch != null) {
          // We have both day and month
          try {
            final day = int.parse(dayMatch.group(1)!);
            String monthStr = monthMatch.group(1)!.toLowerCase();

            // Map month name to month number
            final Map<String, int> monthMap = {
              'january': 1, 'jan': 1,
              'february': 2, 'feb': 2,
              'march': 3, 'mar': 3,
              'april': 4, 'apr': 4,
              'may': 5,
              'june': 6, 'jun': 6,
              'july': 7, 'jul': 7,
              'august': 8, 'aug': 8,
              'september': 9, 'sep': 9,
              'october': 10, 'oct': 10,
              'november': 11, 'nov': 11,
              'december': 12, 'dec': 12,
            };

            // Find the matching month number
            int? month;
            monthMap.forEach((key, value) {
              if (monthStr.startsWith(key)) {
                month = value;
              }
            });

            if (month != null && day >= 1 && day <= 31) {
              final currentYear = DateTime.now().year;
              parsedDate = DateTime(currentYear, month!, day);

              // If date is in the past, assume next year
              if (parsedDate!.isBefore(DateTime.now())) {
                parsedDate = DateTime(currentYear + 1, month!, day);
              }
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }
      }
    } catch (e) {
      print('Error in parseDateWithMultipleFormats: $e');
    }

    return parsedDate;
  }

  /// Extract time from OCR text using multiple detection strategies
  static TimeOfDay? extractEventTime(String ocrText) {
    // Define enhanced time pattern recognition
    final RegExp timePattern = RegExp(
      // Standard time formats with colon
      r'\b\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?\b|'
      // Hour only with AM/PM
      r'\b\d{1,2}\s*(?:AM|PM|am|pm)\b|'
      // Time with leading phrases
      r'\b(?:from|at|by|after)\s+\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?\b|'
      // Event start indicators
      r'\b(?:starts?|begins?|opening|doors? open|kicks off)(?:\s+at)?\s+\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)\b|'
      // Time ranges (extract start time)
      r'\b\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?\s*(?:-|to|–|till|until)\s*\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)\b|'
      // 24-hour format
      r'\b(?:[01]?[0-9]|2[0-3]):[0-5][0-9](?:\s*(?:hours|hrs|h))?\b|'
      // Time with H suffix (e.g., 20:00H)
      r'\b(?:[01]?[0-9]|2[0-3])(?::|\.)[0-5][0-9]\s*[hH]\b',
      caseSensitive: false,
    );

    // Phrases that indicate time context
    final RegExp timeContextPattern = RegExp(
      r'\b(?:time|starts?|begins?|opens?|doors? open|schedule|when)(?:\s+at|:|\s+is|\s+are)?\s+([^\n\.,]+)',
      caseSensitive: false,
    );

    // Find time with multiple strategies
    TimeOfDay? eventTime;

    // STRATEGY 1: Look for explicit time indicators
    final timeContextMatch = timeContextPattern.firstMatch(ocrText);
    if (timeContextMatch != null && timeContextMatch.groupCount >= 1) {
      String timeContext = timeContextMatch.group(1)!;
      final timeInContextMatch = timePattern.firstMatch(timeContext);
      if (timeInContextMatch != null) {
        final timeStr = timeInContextMatch.group(0)!;
        eventTime = parseTimeWithMultipleFormats(timeStr);
      }
    }

    // STRATEGY 2: Look for standard time patterns
    if (eventTime == null) {
      final timeMatch = timePattern.firstMatch(ocrText);
      if (timeMatch != null) {
        final timeStr = timeMatch.group(0)!;
        eventTime = parseTimeWithMultipleFormats(timeStr);
      }
    }

    // STRATEGY 3: Look for time ranges and extract start time
    if (eventTime == null) {
      final timeRangePattern = RegExp(
        r'\b(\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?)\s*(?:-|to|–|till|until)\s*(\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?)\b',
        caseSensitive: false,
      );

      final rangeMatch = timeRangePattern.firstMatch(ocrText);
      if (rangeMatch != null && rangeMatch.groupCount >= 2) {
        // Extract start time from range
        final startTimeStr = rangeMatch.group(1)!;
        eventTime = parseTimeWithMultipleFormats(startTimeStr);
      }
    }

    // STRATEGY 4: Look for 24-hour format times
    if (eventTime == null) {
      final militaryTimePattern = RegExp(r'\b([01]?[0-9]|2[0-3])[\.:][0-5][0-9]\b');
      final militaryMatch = militaryTimePattern.firstMatch(ocrText);

      if (militaryMatch != null) {
        final timeStr = militaryMatch.group(0)!;
        final parts = timeStr.split(RegExp(r'[\.:h]'));

        if (parts.length >= 2) {
          try {
            int hour = int.parse(parts[0]);
            int minute = int.parse(parts[1]);

            if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
              eventTime = TimeOfDay(hour: hour, minute: minute);
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }
      }
    }

    // STRATEGY 5: Look for times near event-related words
    if (eventTime == null) {
      final eventTimeWordsPattern = RegExp(
        r'\b(?:performance|show|concert|doors|opening|meeting|starts|begins)\b',
        caseSensitive: false,
      );

      final eventMatch = eventTimeWordsPattern.firstMatch(ocrText);
      if (eventMatch != null) {
        // Check nearby text for time patterns
        final int matchPos = eventMatch.start;
        final int searchStart = matchPos > 30 ? matchPos - 30 : 0;
        final int searchEnd = matchPos + 50 < ocrText.length ? matchPos + 50 : ocrText.length;

        final String nearbyText = ocrText.substring(searchStart, searchEnd);
        final nearbyTimeMatch = timePattern.firstMatch(nearbyText);

        if (nearbyTimeMatch != null) {
          final timeStr = nearbyTimeMatch.group(0)!;
          eventTime = parseTimeWithMultipleFormats(timeStr);
        }
      }
    }

    return eventTime;
  }

  /// Parse time string into TimeOfDay object supporting multiple formats
  static TimeOfDay? parseTimeWithMultipleFormats(String timeStr) {
    TimeOfDay? parsedTime;

    try {
      // Clean up the time string to extract just hours and minutes
      String cleanTimeStr = timeStr.replaceAll(RegExp(r'(from|at|starts?|begins?|opening|doors? open)(\s+at)?'), '').trim();

      // Check if it's just hours with AM/PM (e.g., "8PM")
      if (RegExp(r'^\d{1,2}\s*(?:AM|PM|am|pm)$').hasMatch(cleanTimeStr)) {
        final parts = cleanTimeStr.split(RegExp(r'\s+'));
        int hour = int.parse(parts[0]);
        bool isPM = parts.length > 1 && parts[1].toLowerCase() == 'pm';

        if (isPM && hour < 12) {
          hour += 12;
        } else if (!isPM && hour == 12) {
          hour = 0;
        }

        parsedTime = TimeOfDay(hour: hour, minute: 0);
      }
      // Standard HH:MM AM/PM format
      else if (cleanTimeStr.contains(':') && (cleanTimeStr.toLowerCase().contains('am') || cleanTimeStr.toLowerCase().contains('pm'))) {
        final parts = cleanTimeStr.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);

          // Handle the minutes and AM/PM part
          String minutePart = parts[1];
          int minute = 0;

          // Extract AM/PM
          bool isPM = minutePart.toLowerCase().contains('pm');
          bool isAM = minutePart.toLowerCase().contains('am');

          if (isPM && hour < 12) {
            hour += 12;
          } else if (isAM && hour == 12) {
            hour = 0;
          }

          // Extract just the digits for minutes
          final minuteMatch = RegExp(r'\d{1,2}').firstMatch(minutePart);
          if (minuteMatch != null) {
            minute = int.parse(minuteMatch.group(0)!);
          }

          parsedTime = TimeOfDay(hour: hour, minute: minute);
        }
      }
      // 24-hour format (e.g., "20:00", "20:00h")
      else if (cleanTimeStr.contains(':') || cleanTimeStr.contains('.')) {
        final parts = cleanTimeStr.split(RegExp(r'[:.]'));
        if (parts.length >= 2) {
          try {
            int hour = int.parse(parts[0]);

            // Extract just the digits for minutes
            final minuteMatch = RegExp(r'\d{1,2}').firstMatch(parts[1]);
            int minute = 0;
            if (minuteMatch != null) {
              minute = int.parse(minuteMatch.group(0)!);
            }

            if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
              parsedTime = TimeOfDay(hour: hour, minute: minute);
            }
          } catch (e) {
            // Ignore parsing errors
          }
        }
      }
      // Fall back to extracting numbers
      else {
        // Try to extract hours and minutes from the string
        final hourPattern = RegExp(r'\b(\d{1,2})\b');
        final hourMatch = hourPattern.firstMatch(cleanTimeStr);

        if (hourMatch != null) {
          int hour = int.parse(hourMatch.group(1)!);

          // Check if AM/PM is specified
          bool isPM = cleanTimeStr.toLowerCase().contains('pm');
          bool isAM = cleanTimeStr.toLowerCase().contains('am');

          // Apply AM/PM adjustment
          if (isPM && hour < 12) {
            hour += 12;
          } else if (isAM && hour == 12) {
            hour = 0;
          }

          parsedTime = TimeOfDay(hour: hour, minute: 0);
        }
      }
    } catch (e) {
      print('Error parsing time: $e');
    }

    return parsedTime;
  }

  /// Enhanced location extraction using multiple approaches
  static String extractLocation(String fullText, List<String> lines) {
    // Default location if nothing is found
    String location = "Location TBD";

    // 1. Look for common location indicators
    final locationKeywords = [
      // Original keywords
      "Hall", "Room", "Theater", "Theatre", "Stadium", "Center", "Centre", "Venue",
      "Arena", "Auditorium", "Convention", "Building", "Club", "Bar", "Lounge",
      "Gallery", "Museum", "Campus", "University", "College", "School", "Pavilion",
      "Street", "Avenue", "Road", "Lane", "Drive", "Boulevard", "Plaza", "Square",
      "Floor", "Suite", "Apt", "Apartment", "Location", "Venue", "Place", "Park",
      "Ballroom", "Studio", "Amphitheater", "Garden", "House", "Mall", "Hotel",

      // Additional venue types
      "Conference", "Festival", "Fair", "Expo", "Exhibition", "Showroom", "Concert",
      "Stage", "Coliseum", "Dome", "Gymnasium", "Gym", "Café", "Cafe", "Restaurant",
      "Bistro", "Pub", "Tavern", "Brewery", "Winery", "Distillery", "Palace", "Castle",

      // More buildings/facilities
      "Library", "Church", "Temple", "Mosque", "Synagogue", "Chapel", "Cathedral",
      "Office", "Tower", "Skyscraper", "Complex", "Court", "Hub", "Lab", "Laboratory",
      "Observatory", "Planetarium", "Zoo", "Aquarium", "Sanctuary", "Retreat", "Resort",
      "Hostel", "Motel", "Inn", "Lodge", "Cabin", "Chalet", "Villa", "Mansion", "Estate",

      // More street/address types
      "Way", "Alley", "Circle", "Court", "Crescent", "Terrace", "Parkway", "Highway",
      "Freeway", "Expressway", "Bypass", "Loop", "Trail", "Path", "Junction", "Corner",
      "Crossing", "Block", "District", "Zone", "Quarter", "Area", "Region", "Neighborhood",

      // International terms
      "Platz", "Strasse", "Straße", "Rue", "Via", "Piazza", "Plaza", "Paseo", "Calle",

      // More specific location types
      "Atrium", "Basement", "Wing", "Annex", "Hall A", "Hall B", "North Wing", "South Wing",
      "East Wing", "West Wing", "Mezzanine", "Rooftop", "Terrace", "Courtyard", "Quad",
      "Banquet Hall", "Reception Hall", "Board Room", "Meeting Room", "Conference Room",

      // Outdoor and public spaces
      "Beach", "Lakefront", "Riverside", "Harbor", "Harbour", "Port", "Dock", "Marina",
      "Pier", "Wharf", "Boardwalk", "Promenade", "Fields", "Grounds", "Forest", "Woods",
      "Meadow", "Grove", "Valley", "Hill", "Mountain", "Courtyard", "Terrace", "Patio",
      "Deck", "Veranda", "Grounds", "Commons", "Green", "Lawn", "Monument", "Memorial",

      // Transportation related
      "Station", "Terminal", "Airport", "Port", "Depot", "Hangar", "Dock", "Garage"
    ];

    // 2. Look for explicit location indicators
    final explicitIndicators = [
      RegExp(r'(?:at|location|venue|place|address)[:\s]+([^\n\.]+)', caseSensitive: false),
      RegExp(r'(?:held at|takes place at|located at)[:\s]+([^\n\.]+)', caseSensitive: false),
      RegExp(r'(?:venue)[:\s]+([^\n\.]+)', caseSensitive: false),
    ];

    // 3. Look for address patterns
    final addressPatterns = [
      RegExp(r'\d+\s+[A-Za-z]+(?:\s+[A-Za-z]+)*(?:\s+Street|St\.?|Avenue|Ave\.?|Road|Rd\.?|Lane|Ln\.?|Drive|Dr\.?|Boulevard|Blvd\.?|Place|Pl\.?)', caseSensitive: false),
      RegExp(r'[A-Za-z]+(?:\s+[A-Za-z]+)*(?:\s+Street|St\.?|Avenue|Ave\.?|Road|Rd\.?|Lane|Ln\.?|Drive|Dr\.?|Boulevard|Blvd\.?|Place|Pl\.?)[,\s]+(?:[A-Za-z\s]+)[,\s]+(?:[A-Z]{2})[,\s]+(?:\d{5}(?:-\d{4})?)', caseSensitive: false),
      RegExp(r'\b(?:Floor|level)\s+\d+\b', caseSensitive: false),
    ];

    // First try explicit location indicators
    for (var pattern in explicitIndicators) {
      final match = pattern.firstMatch(fullText);
      if (match != null && match.groupCount >= 1) {
        String extracted = match.group(1)!.trim();
        // Only use if it's reasonably long (to avoid false positives)
        if (extracted.length > 5) {
          return extracted;
        }
      }
    }

    // Next try to find address patterns
    for (var pattern in addressPatterns) {
      final match = pattern.firstMatch(fullText);
      if (match != null) {
        return match.group(0)!.trim();
      }
    }

    // Next check each line for location keywords
    for (String line in lines) {
      // Skip very short lines or lines that are likely to be the title
      if (line.length < 3 || (lines.isNotEmpty && line == lines[0])) {
        continue;
      }

      for (String keyword in locationKeywords) {
        if (line.toLowerCase().contains(keyword.toLowerCase())) {
          // Make sure we're not picking up random words; check if it's a substantive location
          if (line.length > keyword.length + 2) {
            return line.trim();
          }
        }
      }
    }

    // As a last resort, try to find lines that start with "at" or "in" and aren't the first line
    for (int i = 1; i < lines.length; i++) {
      String line = lines[i].trim();
      if ((line.toLowerCase().startsWith('at ') || line.toLowerCase().startsWith('in ')) &&
          line.length > 4) {
        return line.trim();
      }
    }

    return location;
  }
}