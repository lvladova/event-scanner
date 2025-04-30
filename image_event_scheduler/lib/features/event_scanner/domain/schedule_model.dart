import 'package:flutter/material.dart';
import 'event_model.dart';

class ScheduleModel {
  final String title;
  final DateTime? scheduleDate;
  final String location;
  final List<EventModel> events;
  final String rawText;

  ScheduleModel({
    this.title = "Untitled Schedule",
    this.scheduleDate,
    this.location = "Location TBD",
    this.events = const [],
    this.rawText = "",
  });

  // Group events by date
  Map<DateTime, List<EventModel>> get eventsByDate {
    final Map<DateTime, List<EventModel>> result = {};

    for (final event in events) {
      if (event.date != null) {
        final dateKey = DateTime(
          event.date!.year,
          event.date!.month,
          event.date!.day,
        );

        if (!result.containsKey(dateKey)) {
          result[dateKey] = [];
        }

        result[dateKey]!.add(event);
      }
    }

    return result;
  }

  // Find events matching search text
  List<EventModel> searchEvents(String query) {
    final String normalizedQuery = query.toLowerCase();
    return events.where((event) {
      return event.title.toLowerCase().contains(normalizedQuery) ||
          event.location.toLowerCase().contains(normalizedQuery) ||
          event.description.toLowerCase().contains(normalizedQuery);
    }).toList();
  }
}
