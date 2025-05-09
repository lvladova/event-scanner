import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import '../features/event_scanner/domain/services/calendar_service.dart';
import 'calendar_platform_interface.dart';

class CalendarHelper {
  /// Opens a calendar event in the device's default calendar app
  static Future<void> openEventInCalendar(Map<String, dynamic> event) async {
    try {
      // If there's an htmlLink, use it directly
      if (event['htmlLink'] != null && event['htmlLink'].isNotEmpty) {
        CalendarService.openEventInCalendar(event['htmlLink']);
        return;
      }

      // Otherwise, navigate to the date of the event
      if (event['start']?['dateTime'] != null) {
        final eventDate = DateTime.parse(event['start']['dateTime']);
        await openCalendarAtDate(eventDate);
      } else {
        // If no date found, just open the default calendar
        await openDefaultCalendar();
      }
    } catch (e) {
      print('Error opening event in calendar: $e');
      await openDefaultCalendar();
    }
  }

  /// Opens the calendar app at a specific date
  static Future<void> openCalendarAtDate(DateTime eventDate) async {
    try {
      if (Platform.isAndroid) {
        // Use the platform-specific implementation for Android
        final success = await CalendarPlatformInterface.openCalendarAtDate(eventDate);
        if (success) return;

        // If native approach fails, try web calendar
        await _tryOpenWebCalendar(eventDate);
      }
      else if (Platform.isIOS) {
        // iOS uses the calshow: scheme
        final timestamp = eventDate.millisecondsSinceEpoch / 1000;
        final uri = Uri.parse('calshow:$timestamp');

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }

        // Fallback to web calendar
        await _tryOpenWebCalendar(eventDate);
      }
      else {
        // For other platforms, use web calendar
        await _tryOpenWebCalendar(eventDate);
      }
    } catch (e) {
      print('Error opening calendar at date: $e');
      await openDefaultCalendar();
    }
  }

  /// Helper to try opening a web calendar
  static Future<void> _tryOpenWebCalendar(DateTime date) async {
    try {
      final year = date.year;
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      final uri = Uri.parse('https://calendar.google.com/calendar/r/day/$year/$month/$day');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Failed to open web calendar: $e');
    }
  }

  /// Opens the device's default calendar app
  static Future<void> openDefaultCalendar() async {
    try {
      if (Platform.isAndroid) {
        // Try the platform-specific implementation first
        final success = await CalendarPlatformInterface.openDefaultCalendar();
        if (success) return;

        // Fallback to URL launcher
        final uri = Uri.parse('https://calendar.google.com');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
      else if (Platform.isIOS) {
        final uri = Uri.parse('calshow:');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
      else {
        final uri = Uri.parse('https://calendar.google.com');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      print('Cannot launch calendar app: $e');
    }
  }

  /// Opens a specific work event from the screenshot example
  static Future<void> openWorkEvent() async {
    final workEventDate = DateTime(2025, 5, 4, 17, 30);
    await openCalendarAtDate(workEventDate);
  }
}