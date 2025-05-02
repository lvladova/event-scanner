
import 'package:flutter/material.dart';
import '../features/event_scanner/domain/event_model.dart';
import '../features/event_scanner/domain/services/calendar_service.dart';
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

  // Fixed method to handle single or multiple event scheduling
  static Future<bool> scheduleEvent(
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
      return false;
    }

    HapticFeedback.mediumImpact();

    try {
      // Explicitly create the calendar event with proper formatting
      final result = await CalendarService.createCalendarEvent(eventDetails);

      if (result != null) { // Ensure we got a valid result back
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
        return true;
      } else {
        throw Exception("Calendar service returned null result");
      }
    } catch (e) {
      print('Calendar integration error: $e'); // Debug logging
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to schedule event: $e'),
          backgroundColor: Colors.red,
        ),
      );
      onFailure();
      return false;
    }
  }

  // method to handle bulk scheduling multiple events
  static Future<void> scheduleMultipleEvents(
      BuildContext context,
      List<EventModel> events,
      VoidCallback onComplete,
      Function refreshEvents,
      ) async {
    if (events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No events selected for scheduling'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int successCount = 0;
    int failCount = 0;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Scheduling Events'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Scheduling ${events.length} events...'),
          ],
        ),
      ),
    );

    // Process each event sequentially
    for (var event in events) {
      try {
        bool success = await scheduleEvent(
          context,
          event,
              () {}, // Empty success callback for individual events
              () {}, // Empty failure callback for individual events
              () {}, // Don't refresh after each event
        );

        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
        print('Error scheduling event: $e');
      }
    }

    // Close progress dialog
    Navigator.of(context).pop();

    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scheduled $successCount events successfully${failCount > 0 ? ", $failCount failed" : ""}'),
        backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );

    // Call completion callback
    onComplete();

    // Refresh events list
    refreshEvents();
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
