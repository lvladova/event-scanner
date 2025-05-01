import 'package:flutter/material.dart';
import 'package:image_event_scheduler/shared/widgets/futuristic_widgets.dart';
import 'package:image_event_scheduler/features/event_scanner/domain/event_model.dart';
import 'package:image_event_scheduler/shared/theme/futuristic_theme.dart';

class DetectedEventsCard extends StatefulWidget {
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
  State<DetectedEventsCard> createState() => _DetectedEventsCardState();
}

class _DetectedEventsCardState extends State<DetectedEventsCard> {
  bool _isSelectionMode = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            children: [
              Text(
                'DETECTED EVENTS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: FuturisticTheme.primaryBlue,
                  letterSpacing: 1.2,
                ),
              ),
              if (widget.events.length > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: FuturisticTheme.primaryBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '(${widget.events.length})',
                    style: TextStyle(
                      fontSize: 12,
                      color: FuturisticTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // Multi-select toggle
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                    });
                  },
                  icon: Icon(
                    _isSelectionMode ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                  ),
                  label: Text(
                    _isSelectionMode ? 'Done' : 'Select',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: FuturisticTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ],
          ),
        ),

        if (widget.events.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FuturisticTheme.softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No events detected',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.events.length,
            itemBuilder: (context, index) {
              final event = widget.events[index];
              final isSelected = widget.selectedIndices.contains(index);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? FuturisticTheme.primaryBlue.withOpacity(0.15)
                      : FuturisticTheme.softBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? FuturisticTheme.primaryBlue.withOpacity(0.8)
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: _isSelectionMode
                      ? () {
                    widget.onToggleSelection(index, !isSelected);
                  }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Selection checkbox or radio button
                        if (_isSelectionMode)
                          Checkbox(
                            value: isSelected,
                            onChanged: (value) {
                              widget.onToggleSelection(index, value ?? false);
                            },
                            activeColor: FuturisticTheme.primaryBlue,
                          )
                        else
                          Radio<int>(
                            value: index,
                            groupValue: isSelected ? index : -1,
                            onChanged: (value) {
                              if (value != null) {
                                widget.onToggleSelection(index, !isSelected);
                              }
                            },
                            activeColor: FuturisticTheme.primaryBlue,
                          ),

                        // Event information
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                event.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 4),

                              // Date & Time
                              Row(
                                children: [
                                  if (event.date != null)
                                  // Wrap the Row containing date info with Flexible
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min, // Prevent unnecessary expansion
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: FuturisticTheme.primaryBlue,
                                          ),
                                          const SizedBox(width: 4),
                                          // Wrap Text with Flexible to allow shrinking/ellipsis
                                          Flexible(
                                            child: Text(
                                              event.formattedDate,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1, // Ensure single line
                                              overflow: TextOverflow.ellipsis, // Handle overflow
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (event.time != null)
                                  // Wrap the Row containing time info with Flexible
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min, // Prevent unnecessary expansion
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: FuturisticTheme.primaryBlue,
                                          ),
                                          const SizedBox(width: 4),
                                          // Wrap Text with Flexible to allow shrinking/ellipsis
                                          Flexible(
                                            child: Text(
                                              event.formattedTime,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1, // Ensure single line
                                              overflow: TextOverflow.ellipsis, // Handle overflow
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),

                              // Location
                              if (event.location != "Location TBD")
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: FuturisticTheme.primaryBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        event.location,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),

                        // Action buttons
                        Row(
                          children: [
                            // Edit button
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => widget.onEditEvent(event),
                              tooltip: 'Edit Event',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(8),
                            ),

                            // Calendar button for individual scheduling
                            if (!_isSelectionMode)
                              IconButton(
                                icon: const Icon(Icons.calendar_month, size: 18),
                                onPressed: () => widget.onScheduleEvent(event),
                                tooltip: 'Schedule Event',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(8),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

        // Multi-selection actions
        if (_isSelectionMode && widget.selectedIndices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: ElevatedButton.icon(
              onPressed: widget.isScheduling
                  ? null
                  : () {
                final selectedEvents = widget.selectedIndices
                    .map((i) => widget.events[i])
                    .toList();
                widget.onScheduleAll(selectedEvents);
              },
              icon: widget.isScheduling
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.calendar_month),
              label: Text(
                widget.isScheduling
                    ? 'Scheduling...'
                    : 'Schedule ${widget.selectedIndices.length} Events',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22A45D),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}