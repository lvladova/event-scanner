import 'package:flutter/material.dart';
import '../domain/event_model.dart';
import '../../../shared/theme/futuristic_theme.dart';
import '../../../shared/widgets/futuristic_widgets.dart';
import '../../../screens/map_screen.dart';

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
              const Expanded(
                child: Text(
                  'Event Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              event.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),

          // Date and Time - Responsive layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 300) {
                  // Narrow screen: stack vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateTimeItem(Icons.calendar_today, event.formattedDate),
                      const SizedBox(height: 8),
                      _buildDateTimeItem(Icons.access_time, event.formattedTime),
                    ],
                  );
                } else {
                  // Wide screen: row layout
                  return Row(
                    children: [
                      Expanded(
                        child: _buildDateTimeItem(Icons.calendar_today, event.formattedDate),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateTimeItem(Icons.access_time, event.formattedTime),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 8),

          // Location with Map Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.location,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (event.location != "Location TBD")
                  IconButton(
                    icon: const Icon(Icons.map, color: Colors.blue),
                    tooltip: 'View on Map',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapScreen(
                            locationQuery: event.location,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons - Responsive layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 300) {
                  // Narrow screen: stack buttons vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildEditButton(),
                      const SizedBox(height: 8),
                      _buildScheduleButton(),
                    ],
                  );
                } else {
                  // Wide screen: horizontal layout
                  return Row(
                    children: [
                      Expanded(child: _buildEditButton()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildScheduleButton()),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeItem(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton() {
    return ElevatedButton.icon(
      onPressed: onEdit,
      icon: const Icon(Icons.edit),
      label: const Text(
        'Edit Details',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _buildScheduleButton() {
    return ElevatedButton.icon(
      onPressed: isScheduling ? null : onSchedule,
      icon: isScheduling
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.calendar_month),
      label: Text(
        isScheduling ? 'Scheduling...' : 'Schedule',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF22A45D),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}