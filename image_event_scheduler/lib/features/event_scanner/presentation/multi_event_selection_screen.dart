// lib/features/event_scanner/presentation/multi_event_selection_screen.dart
import 'package:flutter/material.dart';
import '../domain/event_model.dart';
import '../domain/schedule_model.dart';
import '../domain/services/calendar_service.dart';
import 'package:image_event_scheduler/shared/theme/futuristic_theme.dart';

class MultiEventSelectionScreen extends StatefulWidget {
  final ScheduleModel schedule;
  final Function(List<EventModel>) onEventsSelected;

  const MultiEventSelectionScreen({
    Key? key,
    required this.schedule,
    required this.onEventsSelected,
  }) : super(key: key);

  @override
  _MultiEventSelectionScreenState createState() => _MultiEventSelectionScreenState();
}

class _MultiEventSelectionScreenState extends State<MultiEventSelectionScreen> {
  late List<EventModel> _events;
  final Set<int> _selectedIndices = {};
  String _searchQuery = '';
  bool _isScheduling = false;

  @override
  void initState() {
    super.initState();
    _events = widget.schedule.events;
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedIndices.clear();
      for (int i = 0; i < _events.length; i++) {
        _selectedIndices.add(i);
      }
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  void _scheduleSelectedEvents() async {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one event')),
      );
      return;
    }

    // Get the selected events
    final selectedEvents = _selectedIndices.map((index) => _events[index]).toList();

    setState(() {
      _isScheduling = true;
    });

    try {
      // Use the batch scheduling method
      final results = await CalendarService.createCalendarEventBatch(selectedEvents);

      // Count successes and failures
      int successCount = 0;
      List<String> failedEvents = [];

      for (final result in results) {
        if (result['status'] == 'success') {
          successCount++;
        } else {
          failedEvents.add(result['title']);
        }
      }

      // Show result message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failedEvents.isEmpty
                ? 'Successfully scheduled $successCount events'
                : 'Scheduled $successCount events, ${failedEvents.length} failed',
          ),
          backgroundColor: failedEvents.isEmpty ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );

      // Return to previous screen with the scheduled events
      widget.onEventsSelected(selectedEvents);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to schedule events: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isScheduling = false;
      });
    }
  }

  void _filterEvents() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _events = widget.schedule.events;
      } else {
        _events = widget.schedule.searchEvents(_searchQuery);
      }

      // Update selected indices to remain valid with new list
      _selectedIndices.removeWhere((index) => index >= _events.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multiple Events Detected'),
        backgroundColor: FuturisticTheme.softBlue,
        actions: [
          IconButton(
            icon: Icon(Icons.select_all),
            onPressed: _selectAll,
            tooltip: 'Select All',
          ),
          IconButton(
            icon: Icon(Icons.deselect),
            onPressed: _deselectAll,
            tooltip: 'Deselect All',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search events...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: FuturisticTheme.softBlue,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _filterEvents();
                });
              },
            ),
          ),

          // Schedule title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.schedule.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: FuturisticTheme.primaryBlue,
                    ),
                  ),
                ),
                Text(
                  'Select events to schedule',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Statistics bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FuturisticTheme.softBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statItem('Total Events', _events.length.toString()),
                  _statItem('Selected', _selectedIndices.length.toString()),
                  _statItem(
                    'Has Date',
                    _events.where((e) => e.date != null).length.toString(),
                  ),
                  _statItem(
                    'Has Time',
                    _events.where((e) => e.time != null).length.toString(),
                  ),
                ],
              ),
            ),
          ),

          // Event list
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                final isSelected = _selectedIndices.contains(index);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: isSelected ? FuturisticTheme.softBlue : Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? FuturisticTheme.primaryBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(index),
                      activeColor: FuturisticTheme.primaryBlue,
                    ),
                    title: Text(
                      event.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.date != null ? event.formattedDate : 'No date',
                          style: TextStyle(
                            color: event.date != null ? Colors.white70 : Colors.orange,
                          ),
                        ),
                        Text(
                          event.time != null ? event.formattedTime : 'No time',
                          style: TextStyle(
                            color: event.time != null ? Colors.white70 : Colors.orange,
                          ),
                        ),
                        if (event.location != "Location TBD")
                          Text(
                            event.location,
                            style: TextStyle(color: Colors.white70),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    onTap: () => _toggleSelection(index),
                    trailing: IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () {
                        // Navigate to edit screen
                        // This would be implemented in a similar way to the single event edit
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FuturisticTheme.softBlue,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isScheduling ? null : _scheduleSelectedEvents,
                icon: _isScheduling
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                    : Icon(Icons.calendar_today),
                label: Text(_isScheduling ? 'Scheduling...' : 'Schedule Selected Events'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: FuturisticTheme.primaryBlue,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}