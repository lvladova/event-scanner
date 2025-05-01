import 'package:flutter/material.dart';
import 'package:image_event_scheduler/shared/widgets/futuristic_widgets.dart';
import 'package:image_event_scheduler/features/event_scanner/domain/event_model.dart';
import 'package:image_event_scheduler/shared/theme/futuristic_theme.dart';

class MultiEventDetectionModal extends StatefulWidget {
  final List<EventModel> detectedEvents;
  final Function(EventModel) onSelectSingle;
  final Function(List<EventModel>) onScheduleMultiple;
  final Function() onCreateNew;

  const MultiEventDetectionModal({
    Key? key,
    required this.detectedEvents,
    required this.onSelectSingle,
    required this.onScheduleMultiple,
    required this.onCreateNew,
  }) : super(key: key);

  @override
  State<MultiEventDetectionModal> createState() => _MultiEventDetectionModalState();
}

class _MultiEventDetectionModalState extends State<MultiEventDetectionModal> {
  final List<bool> _selectedEvents = [];
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    // Initialize selection state for each event
    _selectedEvents.addAll(List.generate(widget.detectedEvents.length, (_) => false));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121222),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: FuturisticTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      margin: const EdgeInsets.all(16),
      // Using LayoutBuilder to get the available space
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: FuturisticTheme.softBlue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: FuturisticTheme.primaryBlue.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Using Flexible to ensure text doesn't overflow
                    Flexible(
                      child: Text(
                        'Multiple Events Detected',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: FuturisticTheme.primaryBlue,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _selectMode ? Icons.check_box : Icons.check_box_outline_blank,
                        color: FuturisticTheme.primaryBlue,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectMode = !_selectMode;
                          if (!_selectMode) {
                            _selectedEvents.fillRange(0, _selectedEvents.length, false);
                          }
                        });
                      },
                      tooltip: _selectMode ? 'Exit Selection Mode' : 'Select Multiple Events',
                    ),
                  ],
                ),
              ),

              // Event List - Using Expanded within a limited height container
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5, // Reduced from 0.6
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.detectedEvents.length,
                  itemBuilder: (context, index) {
                    final event = widget.detectedEvents[index];
                    return _buildEventTile(event, index);
                  },
                ),
              ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Ensure only takes needed space
                  children: [
                    // Only show multi-schedule button in select mode with at least one selection
                    if (_selectMode && _selectedEvents.contains(true))
                      ElevatedButton.icon(
                        onPressed: () {
                          final selectedEvents = <EventModel>[];
                          for (int i = 0; i < _selectedEvents.length; i++) {
                            if (_selectedEvents[i]) {
                              selectedEvents.add(widget.detectedEvents[i]);
                            }
                          }
                          widget.onScheduleMultiple(selectedEvents);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          'Schedule ${_selectedEvents.where((item) => item).length} Events',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22A45D),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                    // First event selection
                    if (!_selectMode)
                      ElevatedButton.icon(
                        onPressed: () {
                          if (widget.detectedEvents.isNotEmpty) {
                            widget.onSelectSingle(widget.detectedEvents[0]);
                            Navigator.pop(context);
                          }
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Select First Event',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FuturisticTheme.primaryBlue,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Create New Event button
                    TextButton.icon(
                      onPressed: () {
                        widget.onCreateNew();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Event'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEventTile(EventModel event, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _selectedEvents[index]
            ? FuturisticTheme.primaryBlue.withOpacity(0.2)
            : FuturisticTheme.softBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selectedEvents[index]
              ? FuturisticTheme.primaryBlue
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (_selectMode) {
            setState(() {
              _selectedEvents[index] = !_selectedEvents[index];
            });
          } else {
            widget.onSelectSingle(event);
            Navigator.pop(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align to top
            children: [
              // Selection checkbox or radio button
              if (_selectMode)
                Checkbox(
                  value: _selectedEvents[index],
                  onChanged: (value) {
                    setState(() {
                      _selectedEvents[index] = value ?? false;
                    });
                  },
                  activeColor: FuturisticTheme.primaryBlue,
                )
              else
                Radio(
                  value: index,
                  groupValue: -1, // No default selection
                  onChanged: (value) {
                    widget.onSelectSingle(event);
                    Navigator.pop(context);
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
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),

                    const SizedBox(height: 4),

                    // Date & Time - Using Wrap instead of Row
                    if (event.date != null || event.time != null)
                      Wrap(
                        spacing: 8,
                        children: [
                          if (event.date != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: FuturisticTheme.primaryBlue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  event.formattedDate,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),

                          if (event.time != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: FuturisticTheme.primaryBlue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  event.formattedTime,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      )
                    else
                      const Text(
                        'No date/time detected',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
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

              // Edit button
              IconButton(
                icon: const Icon(
                  Icons.edit,
                  size: 20,
                ),
                onPressed: () {
                  widget.onSelectSingle(event);
                  Navigator.pop(context);
                },
                tooltip: 'Edit Event',
                constraints: const BoxConstraints(), // Remove constraints for smaller touch area
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}