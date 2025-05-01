import 'package:flutter/material.dart';
import 'package:image_event_scheduler/features/event_scanner/domain/event_model.dart';
import 'package:image_event_scheduler/shared/theme/futuristic_theme.dart';

class DetectedEventsCard extends StatelessWidget {
  final List<EventModel> events;
  final Function(EventModel) onEditEvent;
  final Function(EventModel) onScheduleEvent;
  final Function(List<EventModel>) onScheduleAll;
  final List<int> selectedIndices;
  final Function(int, bool) onToggleSelection;
  final bool isScheduling;

  const DetectedEventsCard({
    Key? key,
    required this.events,
    required this.onEditEvent,
    required this.onScheduleEvent,
    required this.onScheduleAll,
    required this.selectedIndices,
    required this.onToggleSelection,
    this.isScheduling = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: FuturisticTheme.softBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.event_note, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(  // Added Expanded to prevent overflow
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        events.length == 1 ? 'Event Detected' : 'Multiple Events Detected',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        events.length == 1
                            ? 'Please review and schedule'
                            : 'Select events to schedule',
                        style: const TextStyle(fontSize: 14, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Events List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final isSelected = selectedIndices.contains(index);

              return _buildEventCard(event, index, isSelected);
            },
          ),

          // Action Buttons
          if (events.length > 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final selectedEvents = selectedIndices
                        .map((index) => events[index])
                        .toList();
                    if (selectedEvents.isNotEmpty) {
                      onScheduleAll(selectedEvents);
                    }
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    selectedIndices.isEmpty
                        ? 'Select events to schedule'
                        : 'Schedule ${selectedIndices.length} selected event${selectedIndices.length != 1 ? 's' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(EventModel event, int index, bool isSelected) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withOpacity(0.2) : FuturisticTheme.backgroundDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selection radio if multiple events
            if (events.length > 1)
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: GestureDetector(
                  onTap: () => onToggleSelection(index, !isSelected),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.blue : Colors.white70,
                    size: 24,
                  ),
                ),
              ),

            // Event details
            Expanded(  // Added Expanded to prevent overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Details grid
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (event.date != null)
                        _buildDetailItem(Icons.calendar_today, event.formattedDate),
                      if (event.time != null)
                        _buildDetailItem(Icons.access_time, event.formattedTime),
                      if (event.location != "Location TBD")
                        _buildDetailItem(Icons.location_on, event.location, maxWidth: 120),
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => onEditEvent(event),
                    tooltip: 'Edit',
                    color: Colors.blue,
                  ),
                  IconButton(
                    icon: isScheduling
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.calendar_month, size: 20),
                    onPressed: isScheduling ? null : () => onScheduleEvent(event),
                    tooltip: 'Schedule',
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text, {double maxWidth = 200}) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),  // Prevent overflow
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Flexible(  // Added Flexible to prevent overflow
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}