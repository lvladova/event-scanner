// lib/models/event_model.dart
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show TimeOfDay;

class EventModel {
  String title;
  DateTime? date;
  TimeOfDay? time;
  String location;
  String description;

  EventModel({
    this.title = "Untitled Event",
    this.date,
    this.time,
    this.location = "Location TBD",
    this.description = "",
  });

  // Format date for display
  String get formattedDate {
    if (date == null) return "Date not set";
    final DateFormat formatter = DateFormat('MMM dd, yyyy');
    return formatter.format(date!);
  }

  // Format time for display
  String get formattedTime {
    if (time == null) return "Time not set";
    final String period = time!.period.name.toUpperCase();
    return '${time!.hourOfPeriod}:${time!.minute.toString().padLeft(2, '0')} $period';
  }

  // Convert to Calendar event format
  Map<String, dynamic> toCalendarEvent() {
    if (date == null || time == null) {
      throw Exception("Date and time must be set to create a calendar event");
    }

    final DateTime startDateTime = DateTime(
      date!.year,
      date!.month,
      date!.day,
      time!.hour,
      time!.minute,
    );

    final DateTime endDateTime = startDateTime.add(const Duration(hours: 1));

    return {
      'summary': title,
      'location': location,
      'description': description,
      'start': {
        'dateTime': startDateTime.toIso8601String(),
        'timeZone': 'UTC',
      },
      'end': {
        'dateTime': endDateTime.toIso8601String(),
        'timeZone': 'UTC',
      },
    };
  }
}