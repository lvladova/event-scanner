import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_event_scheduler/core/image_helper.dart';
import 'package:image_event_scheduler/core/ocr_helper.dart';
import 'package:image_event_scheduler/core/dialog_helper.dart';
import 'package:image_event_scheduler/core/event_helper.dart';
import 'package:image_event_scheduler/features/event_scanner/domain/event_model.dart';
import 'package:image_event_scheduler/screens/event_details_screen.dart';
import 'package:image_event_scheduler/screens/settings_screen.dart';
import 'package:image_event_scheduler/screens/image_preview.dart';
import 'package:image_event_scheduler/features/event_scanner/domain/services/calendar_service.dart';
import 'package:image_event_scheduler/features/event_scanner/presentation/event_details_card.dart';
import 'package:image_event_scheduler/features/event_scanner/presentation/event_list_view.dart';
import 'package:image_event_scheduler/shared/theme/futuristic_theme.dart';
import 'package:image_event_scheduler/shared/widgets/futuristic_widgets.dart';
import 'package:image_event_scheduler/shared/widgets/futuristic_animations.dart';
import 'package:image_event_scheduler/config.dart';

class ImageUploadPage extends StatefulWidget {
  const ImageUploadPage({Key? key}) : super(key: key);

  @override
  State<ImageUploadPage> createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  File? _image;
  String _ocrText = '';
  Map<String, dynamic> _structuredData = {};
  List<EventModel> _detectedEvents = [];
  EventModel? _selectedEvent;
  bool _isLoading = false;
  bool _ocrCompleted = false;
  bool _isScheduling = false;
  List<Map<String, dynamic>> _upcomingEvents = [];
  bool _loadingEvents = false;
  bool _multipleEventsDetected = false;

  @override
  void initState() {
    super.initState();
    // Fetch upcoming events on initial load
    _fetchUpcomingEvents();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImageHelper.pickImageFromGallery();
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
        _isLoading = true;
        _detectedEvents = [];
        _selectedEvent = null;
        _multipleEventsDetected = false;
        _structuredData = {};
      });
      _startOCR();
    }
  }

  Future<void> _takePhoto() async {
    final pickedFile = await ImageHelper.takePhotoWithCamera();
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
        _isLoading = true;
        _detectedEvents = [];
        _selectedEvent = null;
        _multipleEventsDetected = false;
        _structuredData = {};
      });
      _startOCR();
    }
  }

  Future<void> _startOCR() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
      _ocrCompleted = false;
    });

    try {
      // Use the enhanced processing method that handles structured text
      final events = await OCRHelper.processEventImage(_image!,
          detectMultiple: Config.enableMultiEventDetection);

      // Handle the result
      setState(() {
        _detectedEvents = events;
        _multipleEventsDetected = events.length > 1;
        _selectedEvent = events.isNotEmpty ? events.first : null;
        _ocrCompleted = true;
        _ocrText = events.isNotEmpty ? events.first.description : '';
        _isLoading = false;
      });

      if (events.length > 1) {
        // Optional: Show multi-event dialog
        _showMultiEventDialog(events);
      } else if (events.length == 1 && Config.enableAutoOCR) {
        // Auto-navigate to event details
        _navigateToEventDetails();
      }
    } catch (e) {
      print('OCR error: $e');
      setState(() {
        _ocrText = "Error processing image: $e";
        _isLoading = false;
      });
      DialogHelper.showRetryDialog(context, _createBlankEvent, _startOCR);
    }
  }

  Future<List<EventModel>> _tryExtractMultipleEvents(String text) async {
    // This could be expanded to use more sophisticated algorithms
    // For now, we'll use a simple approach to detect date patterns

    final events = <EventModel>[];

    // Split by multiple newlines
    final blocks = text.split(RegExp(r'\n{3,}'));

    for (final block in blocks) {
      if (block.trim().length > 20) { // Minimum text length for an event
        try {
          final event = await OCRHelper.tryParseEvent(block);
          if (event != null) {
            events.add(event);
          }
        } catch (e) {
          print('Error parsing event block: $e');
        }
      }
    }

    // If we couldn't extract multiple events, return an empty list
    return events;
  }

  void _showMultiEventDialog(List<EventModel> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('Multiple Events Detected'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return ListTile(
                title: Text(event.title),
                subtitle: Text(
                  '${event.date != null ? event.formattedDate : "No date"} | '
                      '${event.time != null ? event.formattedTime : "No time"}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedEvent = event;
                    });
                    _navigateToEventDetails();
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedEvent = event;
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _createBlankEvent();
            },
            child: const Text('Create New Event'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('Select First Event'),
          ),
        ],
      ),
    );
  }

  void _createBlankEvent() {
    setState(() {
      _selectedEvent = EventHelper.createBlankEvent();
      _detectedEvents = [_selectedEvent!];
      _ocrCompleted = true;
      _multipleEventsDetected = false;
    });
    _navigateToEventDetails();
  }

  void _navigateToEventDetails() {
    if (_selectedEvent == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailsScreen(
          event: _selectedEvent!,
          onSave: (updatedEvent) {
            setState(() {
              _selectedEvent = updatedEvent;
              // Update in the detected events list if it exists there
              final index = _detectedEvents.indexWhere(
                      (e) => e.title == _selectedEvent!.title &&
                      e.date == _selectedEvent!.date
              );
              if (index >= 0) {
                _detectedEvents[index] = updatedEvent;
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Event saved successfully!')),
            );
          },
        ),
      ),
    );
  }

  Future<void> _scheduleEvent() async {
    if (_selectedEvent == null) return;

    setState(() => _isScheduling = true);

    await EventHelper.scheduleEvent(
      context,
      _selectedEvent!,
          () {
        setState(() {
          _isScheduling = false;
          // Remove the event from detected events list
          _detectedEvents.remove(_selectedEvent);

          // If we have more events, select the next one
          if (_detectedEvents.isNotEmpty) {
            _selectedEvent = _detectedEvents.first;
          } else {
            _selectedEvent = null;
            _image = null; // Clear image once all events are processed
          }
        });
      },
          () {
        setState(() => _isScheduling = false);
      },
      _fetchUpcomingEvents,
    );
  }

  Future<void> _scheduleAllEvents() async {
    if (_detectedEvents.isEmpty) return;

    setState(() => _isScheduling = true);

    int successCount = 0;
    for (final event in _detectedEvents) {
      try {
        await CalendarService.createCalendarEvent(event);
        successCount++;
      } catch (e) {
        print('Failed to schedule event: $e');
      }
    }

    setState(() {
      _isScheduling = false;
      if (successCount == _detectedEvents.length) {
        // All events scheduled successfully
        _detectedEvents = [];
        _selectedEvent = null;
        _image = null; // Clear image once all events are processed
      } else if (successCount > 0) {
        // Remove successfully scheduled events
        _detectedEvents = _detectedEvents.sublist(successCount);
        _selectedEvent = _detectedEvents.isNotEmpty ? _detectedEvents.first : null;
      }
    });

    // Show feedback to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Scheduled $successCount out of ${_detectedEvents.length} events'),
        backgroundColor: successCount > 0 ? Colors.green : Colors.orange,
      ),
    );

    // Refresh upcoming events
    _fetchUpcomingEvents();
  }

  Future<void> _fetchUpcomingEvents() async {
    if (_loadingEvents) return;

    setState(() => _loadingEvents = true);

    final events = await EventHelper.fetchUpcomingEvents();
    setState(() {
      _upcomingEvents = events;
      _loadingEvents = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FuturisticAnimations.holographicScanner(
          isScanning: _isLoading,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildImageArea(),

                    // Multi-event indicator (if multiple events detected)
                    if (_multipleEventsDetected && _detectedEvents.length > 1)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.event_note, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Multiple Events (${_detectedEvents.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const Spacer(),
                                if (_detectedEvents.length > 1)
                                  TextButton.icon(
                                    icon: const Icon(Icons.calendar_month, size: 16),
                                    label: const Text('Schedule All'),
                                    onPressed: _isScheduling ? null : _scheduleAllEvents,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select an event to edit or schedule below.',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Add EventListView here
                    if (_multipleEventsDetected && _detectedEvents.length > 1)
                      EventListView(
                        events: _detectedEvents,
                        selectedEvent: _selectedEvent,
                        onEventSelected: (event) {
                          setState(() {
                            _selectedEvent = event;
                          });
                        },
                        onEventEdit: (event) {
                          setState(() {
                            _selectedEvent = event;
                          });
                          _navigateToEventDetails();
                        },
                        onEventSchedule: (event) {
                          setState(() {
                            _selectedEvent = event;
                          });
                          _scheduleEvent();
                        },
                        isScheduling: _isScheduling,
                      ),

                    // Selected event card - only show if not multiple events or if using navigation mode
                    if (!_multipleEventsDetected && _selectedEvent != null)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        child: EventDetailsCard(
                          event: _selectedEvent!,
                          onEdit: _navigateToEventDetails,
                          onSchedule: _scheduleEvent,
                          isScheduling: _isScheduling,
                        ),
                      ),

                    // Raw OCR info button
                    if (_ocrText.isNotEmpty && _selectedEvent != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        child: TextButton.icon(
                          icon: const Icon(Icons.text_snippet, size: 16),
                          label: const Text('View Raw OCR Text'),
                          onPressed: _showOcrText,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),

                    // Upcoming events section
                    if (_upcomingEvents.isNotEmpty)
                      _buildUpcomingEvents(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getSelectedEventIndex() {
    if (_selectedEvent == null) return 0;
    final index = _detectedEvents.indexOf(_selectedEvent!);
    return index >= 0 ? index : 0;
  }

  void _showOcrText() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Raw OCR Text',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _ocrText,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FuturisticTheme.softBlue,
        boxShadow: [
          BoxShadow(
            color: FuturisticTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          FuturisticAnimations.pulsingSphere(
            size: 50,
            color: FuturisticTheme.primaryBlue,
          ),
          const SizedBox(width: 12),
          const Text(
            'Event Scanner',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildImageArea() {
    return FuturisticWidgets.holographicCard(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.3,
        constraints: const BoxConstraints(minHeight: 200, maxHeight: 350),
        child: _image != null
            ? Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ImagePreviewScreen(image: _image!),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _image!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _image = null;
                      _ocrText = '';
                      _ocrCompleted = false;
                      _selectedEvent = null;
                      _detectedEvents = [];
                      _multipleEventsDetected = false;
                      _structuredData = {};
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FuturisticAnimations.pulsingSphere(
              size: 100,
              color: FuturisticTheme.primaryBlue,
            ),
            const SizedBox(height: 16),
            const Text('Upload Event Image', style: TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FuturisticWidgets.futuristicButton(
                  onPressed: _pickImage,
                  child: const Text('Gallery'),
                ),
                const SizedBox(width: 16),
                FuturisticWidgets.futuristicButton(
                  onPressed: _takePhoto,
                  child: const Text('Camera'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEvents() {
    return Container(
      margin: const EdgeInsets.only(top: 32, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'UPCOMING EVENTS',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _fetchUpcomingEvents,
                tooltip: 'Refresh events',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _loadingEvents
              ? const Center(
            child: CircularProgressIndicator(),
          )
              : _upcomingEvents.isEmpty
              ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'You have no upcoming events',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = _upcomingEvents[index];
              final startTime = event['start']?['dateTime'] != null
                  ? DateTime.parse(event['start']['dateTime'])
                  : null;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  title: Text(event['summary'] ?? 'Untitled Event'),
                  subtitle: Text(
                    startTime != null
                        ? '${startTime.month}/${startTime.day}/${startTime.year} ${startTime.hour}:${startTime.minute}'
                        : 'No date specified',
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event, color: Colors.blue),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () {
                      CalendarService.openEventInCalendar(event['htmlLink']);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}