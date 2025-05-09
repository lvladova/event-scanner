import 'package:flutter/services.dart';

class CalendarPlatformInterface {
  static const MethodChannel _channel = MethodChannel('com.example.image_event_scheduler/calendar');

  static Future<bool> openCalendarAtDate(DateTime date) async {
    try {
      final bool result = await _channel.invokeMethod('openCalendarAtDate', {
        'timestamp': date.millisecondsSinceEpoch,
      });
      return result;
    } on PlatformException catch (e) {
      print('Failed to open calendar at date: ${e.message}');
      return false;
    }
  }

  static Future<bool> openDefaultCalendar() async {
    try {
      final bool result = await _channel.invokeMethod('openDefaultCalendar');
      return result;
    } on PlatformException catch (e) {
      print('Failed to open default calendar: ${e.message}');
      return false;
    }
  }
}