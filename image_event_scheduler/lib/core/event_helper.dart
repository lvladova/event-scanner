import 'package:flutter/material.dart';
import '../../features/event_scanner/domain/event_model.dart';
import '../../features/event_scanner/domain/services/calendar_service.dart';
import 'package:flutter/services.dart';

class EventHelper {
  static EventModel createBlankEvent() {
    return EventModel(
      title: "New Event",
      date: DateTime.now(),
      time: TimeOfDay.now(),
      location: "Location TBD",
      description: "",
    );
  }

  static Future<void> scheduleEvent(
      BuildContext context,
      EventModel eventDetails,
      VoidCallback onSuccess,
      VoidCallback onFailure,
      Function refreshEvents,
      ) async {
    if (eventDetails.date == null || eventDetails.time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set both date and time for the event'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    try {
      await CalendarService.createCalendarEvent(eventDetails);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Event "${eventDetails.title}" scheduled successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      HapticFeedback.heavyImpact();
      onSuccess();
      refreshEvents();
    } catch (e) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to schedule event: $e'),
          backgroundColor: Colors.red,
        ),
      );
      onFailure();
    }
  }

  static Future<List<Map<String, dynamic>>> fetchUpcomingEvents() async {
    try {
      return await CalendarService.getUpcomingEvents();
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }
}
