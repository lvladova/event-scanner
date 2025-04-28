import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../event_model.dart';
import 'dart:io' show Platform;

class CalendarService {
  static final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  // Initialize time zones - call this from main.dart before runApp()
  static void initializeTimeZones() {
    try {
      tz_data.initializeTimeZones();
      // Get the device's current timezone
      final String timezoneName = DateTime.now().timeZoneName;
      // Try to find a matching timezone or use a fallback
      try {
        final location = tz.getLocation(timezoneName);
        tz.setLocalLocation(location);
      } catch (e) {
        // Fallback to a common timezone like UTC
        final location = tz.getLocation('Etc/UTC');
        tz.setLocalLocation(location);
        print('Falling back to UTC timezone: $e');
      }
    } catch (e) {
      print('Error initializing timezones: $e');
    }
  }

  static Future<Map<String, dynamic>> createCalendarEvent(EventModel event) async {
    // Verify required fields
    if (event.date == null || event.time == null) {
      throw Exception('Date and time must be set to create a calendar event');
    }

    try {
      // Request permission
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && permissionsGranted.data == false) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || permissionsGranted.data == false) {
          throw Exception('Calendar permissions not granted');
        }
      }

      // Get available calendars and show a bit more detail for debugging
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      final calendars = calendarsResult.data;

      if (calendars == null || calendars.isEmpty) {
        throw Exception('No calendars found on device');
      }

      // Find default calendar - preferably one that syncs
      String? calendarId;

      // First try to find a non-local calendar (one that syncs)
      for (final calendar in calendars) {
        print('Calendar: ${calendar.name}, ID: ${calendar.id}, isReadOnly: ${calendar.isReadOnly}');

        if (calendar.id != null &&
            calendar.isReadOnly == false &&
            (calendar.accountName?.contains('@') ?? false)) {
          // This looks like a syncing account-based calendar
          calendarId = calendar.id;
          print('Selected syncing calendar: ${calendar.name}');
          break;
        }
      }

      // If no syncing calendar found, use the first writable calendar
      if (calendarId == null) {
        for (final calendar in calendars) {
          if (calendar.id != null && calendar.isReadOnly == false) {
            calendarId = calendar.id;
            print('Selected local calendar: ${calendar.name}');
            break;
          }
        }
      }

      // If still no suitable calendar, just use the first one
      if (calendarId == null && calendars.first.id != null) {
        calendarId = calendars.first.id;
        print('Falling back to first available calendar: ${calendars.first.name}');
      }

      if (calendarId == null) {
        throw Exception('No writable calendar found on device');
      }

      // Create start and end times with timezone awareness
      final regularStartDateTime = DateTime(
        event.date!.year,
        event.date!.month,
        event.date!.day,
        event.time!.hour,
        event.time!.minute,
      );

      // Convert to timezone-aware datetime objects
      final startDateTime = tz.TZDateTime.from(regularStartDateTime, tz.local);
      final endDateTime = startDateTime.add(const Duration(hours: 1));

      // Create the event with all available details
      final newEvent = Event(
        calendarId,
        title: event.title,
        description: event.description,
        start: startDateTime,
        end: endDateTime,
      );

      // Add location if available
      if (event.location.isNotEmpty && event.location != "Location TBD") {
        newEvent.location = event.location;
      }

      // Add reminders for 15 minutes before
      newEvent.reminders = [
        Reminder(minutes: 15)
      ];

      // Save the event
      final createResult = await _deviceCalendarPlugin.createOrUpdateEvent(newEvent);

      if (createResult?.isSuccess == true && createResult?.data != null) {
        print('Event created successfully with ID: ${createResult!.data}');

        // Return complete event details
        return {
          'id': createResult.data,
          'summary': event.title,
          'location': event.location,
          'description': event.description,
          'status': 'success',
          'calendarId': calendarId
        };
      } else {
        print('Failed to create event. Errors: ${createResult?.errors?.join(", ")}');
        throw Exception('Failed to create event: ${createResult?.errors?.join(", ")}');
      }
    } catch (e) {
      print('Detailed calendar error: $e');
      throw Exception('Failed to create calendar event: $e');
    }
  }

  // The rest of your methods would remain the same as in the previous example...
  static Future<List<Map<String, dynamic>>> getUpcomingEvents() async {
    try {
      // Request permission
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsGranted.isSuccess && permissionsGranted.data == false) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || permissionsGranted.data == false) {
          throw Exception('Calendar permissions not granted');
        }
      }

      // Get available calendars
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      final calendars = calendarsResult.data;

      if (calendars == null || calendars.isEmpty) {
        return [];
      }

      // Get events from all calendars
      List<Map<String, dynamic>> allEvents = [];
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30)); // Next 30 days

      for (final calendar in calendars) {
        if (calendar.id == null) continue;

        final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
          calendar.id!,
          RetrieveEventsParams(
            startDate: now,
            endDate: endDate,
          ),
        );

        if (eventsResult.isSuccess && eventsResult.data != null) {
          for (final event in eventsResult.data!) {
            allEvents.add({
              'id': event.eventId,
              'summary': event.title ?? 'Untitled Event',
              'location': event.location ?? '',
              'start': {
                'dateTime': event.start?.toIso8601String(),
              },
              'calendarName': calendar.name,
              'calendarId': calendar.id,
            });
          }
        }
      }

      // Sort by start date
      allEvents.sort((a, b) {
        final aDate = a['start']?['dateTime'] != null
            ? DateTime.parse(a['start']['dateTime'])
            : DateTime.now();
        final bDate = b['start']?['dateTime'] != null
            ? DateTime.parse(b['start']['dateTime'])
            : DateTime.now();
        return aDate.compareTo(bDate);
      });

      print('Retrieved ${allEvents.length} upcoming events');
      return allEvents.take(10).toList(); // Return top 10 events
    } catch (e) {
      print('Failed to fetch events: $e');
      return [];
    }
  }

  static Future<bool> deleteEvent(String calendarId, String eventId) async {
    try {
      final deleteResult = await _deviceCalendarPlugin.deleteEvent(calendarId, eventId);
      return deleteResult?.isSuccess ?? false;
    } catch (e) {
      print('Failed to delete event: $e');
      return false;
    }
  }
static Future<void> openEventInCalendar(String? eventUrl) async {
  if (eventUrl == null || eventUrl.isEmpty) {
    return; // Exit if no event URL is provided
  }

  try {
    // First try to parse and launch as a URL (for Google/web calendar links)
    final uri = Uri.parse(eventUrl);

    // If it's a URL, launch it in an external app
    if (eventUrl.startsWith('http')) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // For Android device calendar events
    else if (Platform.isAndroid) {
      // Try to parse event ID for Android (content://com.android.calendar/events/ID format)
      final String eventId = eventUrl.split('/').last;
      final eventUri = Uri.parse('content://com.android.calendar/events/$eventId');

      if (await canLaunchUrl(eventUri)) {
        await launchUrl(eventUri);
        return;
      }
    }
    // For iOS device calendar events
    else if (Platform.isIOS) {
      // iOS uses calshow: URI scheme
      final eventUri = Uri.parse('calshow:$eventUrl');

      if (await canLaunchUrl(eventUri)) {
        await launchUrl(eventUri);
        return;
      }
    }

    // Fallback - just open the calendar app
    if (Platform.isAndroid) {
      final calendarUri = Uri.parse('content://com.android.calendar/time');
      await launchUrl(calendarUri);
    } else if (Platform.isIOS) {
      final calendarUri = Uri.parse('calshow:');
      await launchUrl(calendarUri);
    }
  } catch (e) {
    print('Error opening calendar event: $e');
    // Show a user-friendly message instead of throwing an exception
    // You could use a SnackBar or Toast here
  }
}
}