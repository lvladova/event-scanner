import 'package:flutter/material.dart';
import '../domain/event_model.dart';
import 'package:intl/intl.dart';

class EventListView extends StatelessWidget {
  final List<EventModel> events;
  final EventModel? selectedEvent;
  final Function(EventModel) onEventSelected;
  final Function(EventModel) onEventEdit;
  final Function(EventModel) onEventSchedule;
  final bool isScheduling;

  const EventListView({
    Key? key,
    required this.events,
    required this.selectedEvent,
    required this.onEventSelected,
    required this.onEventEdit,
    required this.onEventSchedule,
    this.isScheduling = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text(
            'DETECTED EVENTS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final isSelected = selectedEvent == event;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withOpacity(0.2)
                    : const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: ListTile(
                title: Text(
                  event.title,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (event.date != null) ...[
                          const Icon(Icons.calendar_today, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy').format(event.date!),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (event.time != null) ...[
                          const Icon(Icons.access_time, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            '${event.time!.format(context)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                    if (event.location != "Location TBD") ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                leading: Radio<EventModel>(
                  value: event,
                  groupValue: selectedEvent,
                  onChanged: (value) {
                    if (value != null) {
                      onEventSelected(value);
                    }
                  },
                  activeColor: Colors.blue,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => onEventEdit(event),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: isScheduling && event == selectedEvent
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.calendar_month, size: 18),
                      onPressed: isScheduling && event == selectedEvent
                          ? null
                          : () => onEventSchedule(event),
                      tooltip: 'Schedule',
                    ),
                  ],
                ),
                onTap: () => onEventSelected(event),
              ),
            );
          },
        ),
        if (events.length > 1)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: const Text('Schedule All Events'),
                    onPressed: isScheduling ? null : () {
                      // Implement batch scheduling
                      for (final event in events) {
                        onEventSchedule(event);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}