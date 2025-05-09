import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../features/event_scanner/domain/services/calendar_service.dart';

class CalendarHelper {
  /// Opens a calendar event in the device's default calendar app
  static Future<void> openEventInCalendar(Map<String, dynamic> event) async {
    // If there's an htmlLink, use it directly
    if (event['htmlLink'] != null && event['htmlLink'].isNotEmpty) {
      CalendarService.openEventInCalendar(event['htmlLink']);
      return;
    }

    // Otherwise, navigate to the date of the event
    if (event['start']?['dateTime'] != null) {
      final eventDate = DateTime.parse(event['start']['dateTime']);
      openCalendarAtDate(eventDate);
    } else {
      // If no date found, just open the default calendar
      openDefaultCalendar();
    }
  }

  /// Opens the calendar app at a specific date
  static Future<void> openCalendarAtDate(DateTime eventDate) async {
    try {
      Uri uri;
      if (Platform.isAndroid) {
        final timestamp = eventDate.millisecondsSinceEpoch;
        uri = Uri.parse('content://com.android.calendar/time/$timestamp');
      } else if (Platform.isIOS) {
        final timestamp = eventDate.millisecondsSinceEpoch / 1000; // iOS uses seconds
        uri = Uri.parse('calshow:$timestamp');
      } else {
        // Web fallback
        final year = eventDate.year;
        final month = eventDate.month;
        final day = eventDate.day;
        uri = Uri.parse('https://calendar.google.com/calendar/u/0/r/day/$year/$month/$day');
      }

      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await openDefaultCalendar();
      }
    } catch (e) {
      print('Error opening calendar at date: $e');
      await openDefaultCalendar();
    }
  }

  /// Opens the device's default calendar app
  static Future<void> openDefaultCalendar() async {
    try {
      Uri uri;
      if (Platform.isAndroid) {
        uri = Uri.parse('content://com.android.calendar/time');
      } else if (Platform.isIOS) {
        uri = Uri.parse('calshow:');
      } else {
        uri = Uri.parse('https://calendar.google.com');
      }

      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('Cannot launch calendar app');
      }
    } catch (e) {
      print('Error opening default calendar: $e');
    }
  }

  /// Opens a specific work event (example from screenshot)
  static Future<void> openWorkEvent() async {
    final workEventDate = DateTime(2025, 5, 4, 17, 30);
    await openCalendarAtDate(workEventDate);
  }
}