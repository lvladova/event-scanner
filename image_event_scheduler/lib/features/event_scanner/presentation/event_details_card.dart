import 'package:flutter/material.dart';
import '../domain/event_model.dart';
import '../../../../shared/theme/futuristic_theme.dart';
import '../../../../shared/widgets/futuristic_widgets.dart';

class EventDetailsCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onEdit;
  final VoidCallback onSchedule;
  final bool isScheduling;

  const EventDetailsCard({
    Key? key,
    required this.event,
    required this.onEdit,
    required this.onSchedule,
    this.isScheduling = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FuturisticWidgets.holographicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.event_note, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Event Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            event.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Date and Time
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text(event.formattedDate),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text(event.formattedTime),
            ],
          ),
          const SizedBox(height: 8),

          // Location
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text(event.location)),
            ],
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isScheduling ? null : onSchedule,
                  icon: isScheduling
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.calendar_month),
                  label: Text(isScheduling ? 'Scheduling...' : 'Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22A45D),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


