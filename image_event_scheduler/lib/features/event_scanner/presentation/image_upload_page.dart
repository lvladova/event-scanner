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
import 'package:image_event_scheduler/shared/theme/futuristic_theme.dart';
import 'package:image_event_scheduler/shared/widgets/futuristic_widgets.dart';
import 'package:image_event_scheduler/shared/widgets/futuristic_animations.dart';
import 'package:flutter/services.dart';

import 'widgets/multi_event_detection_modal.dart';
import 'widgets/detected_events_card.dart';

class ImageUploadPage extends StatefulWidget {
  const ImageUploadPage({Key? key}) : super(key: key);

  @override
  State<ImageUploadPage> createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  File? _image;
  String _ocrText = '';
  List<EventModel> _detectedEvents = [];
  List<int> _selectedEventIndices = [];
  bool _isLoading = false;
  bool _ocrCompleted = false;
  bool _isScheduling = false;
  List<Map<String, dynamic>> _upcomingEvents = [];
  bool _loadingEvents = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImageHelper.pickImageFromGallery();
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
        _isLoading = true;
        // Clear previous results
        _detectedEvents = [];
        _selectedEventIndices = [];
        _ocrText = '';
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
        // Clear previous results
        _detectedEvents = [];
        _selectedEventIndices = [];
        _ocrText = '';
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
      // Extract text from image
      final extractedText = await OCRHelper.extractTextOnly(_image!);

      if (extractedText.isEmpty) {
        setState(() {
          _ocrText = "No text detected in the image.";
          _isLoading = false;
        });
        DialogHelper.showRetryDialog(context, _createBlankEvent, _startOCR);
        return;
      }

      // Save the raw OCR text
      setState(() {
        _ocrText = extractedText;
      });

      // Extract multiple events using the hybrid parser
      final events = await OCRHelper.extractMultipleEvents(extractedText);

      setState(() {
        _detectedEvents = events;
        _ocrCompleted = true;
        _isLoading = false;
      });

      // If multiple events detected, show modal to let user select
      if (events.length > 1) {
        _showMultiEventDetectionModal(events);
      } else if (events.length == 1) {
        // With just one event, set it as selected
        setState(() {
          _selectedEventIndices = [0];
        });
      } else {
        // No events detected, create blank event
        _createBlankEvent();
      }
    } catch (e) {
      print('OCR error: $e');
      setState(() {
        _ocrText = 'Error: $e';
        _isLoading = false;
      });
      DialogHelper.showRetryDialog(context, _createBlankEvent, _startOCR);
    }
  }

  void _showMultiEventDetectionModal(List<EventModel> events) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: MultiEventDetectionModal(
            detectedEvents: events,
            onSelectSingle: (event) {
              setState(() {
                _detectedEvents = [event];
                _selectedEventIndices = [0];
              });
            },
            onScheduleMultiple: (selectedEvents) {
              _scheduleMultipleEvents(selectedEvents);
            },
            onCreateNew: _createBlankEvent,
          ),
        );
      },
    );
  }

  void _createBlankEvent() {
    setState(() {
      _detectedEvents = [EventHelper.createBlankEvent()];
      _selectedEventIndices = [0];
      _ocrCompleted = true;
    });
    _navigateToEventDetails(_detectedEvents[0]);
  }

  void _navigateToEventDetails(EventModel event) {
    FocusScope.of(context).unfocus();

    Future.delayed(const Duration(milliseconds: 50), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventDetailsScreen(
            event: event,
            onSave: (updatedEvent) {
              setState(() {
                final index = _detectedEvents.indexOf(event);
                if (index != -1) {
                  _detectedEvents[index] = updatedEvent;
                } else {
                  _detectedEvents.add(updatedEvent);
                  _selectedEventIndices = [_detectedEvents.length - 1];
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Event saved successfully!')),
              );
            },
          ),
        ),
      );
    });
  }

  Future<void> _scheduleEvent(EventModel event) async {
    if (event.date == null || event.time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set both date and time for the event'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isScheduling = true);

    await EventHelper.scheduleEvent(
      context,
      event,
          () {
        setState(() {
          _isScheduling = false;
          // Clear this event
          final index = _detectedEvents.indexOf(event);
          if (index != -1) {
            _detectedEvents.removeAt(index);
            _selectedEventIndices.remove(index);
            // Update indices that were higher than the removed index
            _selectedEventIndices = _selectedEventIndices.map((i) => i > index ? i - 1 : i).toList();
          }
        });
      },
          () => setState(() => _isScheduling = false),
      _fetchUpcomingEvents,
    );
  }

  Future<void>_scheduleMultipleEvents(List<EventModel> events) async {
    if (events.isEmpty) return;

    setState(() => _isScheduling = true);

    try {
      await EventHelper.scheduleMultipleEvents(
        context,
        events,
            () {
          setState(() {
            _isScheduling = false;

            // Remove all scheduled events from the detected events list
            for (var event in events) {
              final index = _detectedEvents.indexOf(event);
              if (index != -1) {
                _detectedEvents.removeAt(index);
              }
            }

            // Clear selected indices
            _selectedEventIndices = [];
          });
        },
        _fetchUpcomingEvents,
      );
    } catch (e) {
      setState(() => _isScheduling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error scheduling events: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchUpcomingEvents() async {
    if (_loadingEvents) return;

    setState(() => _loadingEvents = true);

    try {
      final events = await EventHelper.fetchUpcomingEvents();
      setState(() {
        _upcomingEvents = events;
        _loadingEvents = false;
      });
    } catch (e) {
      print('Error fetching events: $e');
      setState(() => _loadingEvents = false);
    }
  }

  void _toggleEventSelection(int index, bool selected) {
    setState(() {
      if (selected) {
        if (!_selectedEventIndices.contains(index)) {
          _selectedEventIndices.add(index);
        }
      } else {
        _selectedEventIndices.remove(index);
      }
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

                    // Show detected events
                    if (_detectedEvents.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: DetectedEventsCard(
                          events: _detectedEvents,
                          onEditEvent: _navigateToEventDetails,
                          onScheduleEvent: _scheduleEvent,
                          onScheduleAll: (events) async {
                            // Convert the function signature
                            await _scheduleMultipleEvents(events);
                          },
                          selectedIndices: _selectedEventIndices,
                          onToggleSelection: _toggleEventSelection,
                          isScheduling: _isScheduling,
                        ),
                      ),

                    // OCR Information if available
                    if (_ocrText.isNotEmpty && _detectedEvents.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: _buildOcrInfoCard(),
                      ),

                    // Show upcoming events
                    if (_upcomingEvents.isNotEmpty)
                      _buildUpcomingEventsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          fit: StackFit.expand,
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
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.zoom_in,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _image = null;
                    _ocrText = '';
                    _ocrCompleted = false;
                    _detectedEvents = [];
                    _selectedEventIndices = [];
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Delete',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
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
            const Text(
              'Upload Event Image',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
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

  Widget _buildOcrInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FuturisticTheme.softBlue.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FuturisticTheme.gridLineColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Extracted ${_detectedEvents.length} event${_detectedEvents.length != 1 ? 's' : ''} from OCR text',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _showOcrTextModal,
            child: const Text(
              'View Raw Text',
              style: TextStyle(color: Colors.blue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showOcrTextModal() {
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

  Widget _buildUpcomingEventsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 32, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'UPCOMING EVENTS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 1.2,
                ),
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

          // Loading indicator or events list
          _loadingEvents
              ? const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
              : _upcomingEvents.isEmpty
              ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FuturisticTheme.softBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'You have no upcoming events',
                style: TextStyle(color: Colors.white70),
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
                  color: FuturisticTheme.softBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  title: Text(
                    event['summary'] ?? 'Untitled Event',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    startTime != null
                        ? '${startTime.month}/${startTime.day}/${startTime.year} ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}'
                        : 'No date specified',
                    style: const TextStyle(fontSize: 12),
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: FuturisticTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.event,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    onPressed: () => CalendarService.openEventInCalendar(event['htmlLink']),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}