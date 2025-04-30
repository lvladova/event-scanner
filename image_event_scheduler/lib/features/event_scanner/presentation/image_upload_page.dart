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
import 'package:image_event_scheduler/features/event_scanner/domain/schedule_model.dart';
import 'package:image_event_scheduler/features/event_scanner/presentation/multi_event_selection_screen.dart';

class ImageUploadPage extends StatefulWidget {
  const ImageUploadPage({Key? key}) : super(key: key);

  @override
  State<ImageUploadPage> createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  File? _image;
  String _ocrText = '';
  EventModel? _eventDetails;
  bool _isLoading = false;
  bool _ocrCompleted = false;
  bool _isScheduling = false;
  List<Map<String, dynamic>> _upcomingEvents = [];
  bool _loadingEvents = false;

  ScheduleModel? _scheduleModel;
  bool _isMultiEvent = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImageHelper.pickImageFromGallery();
    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
        _isLoading = true;
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

    // First try to parse as a schedule
    _scheduleModel = await OCRHelper.tryParseSchedule(_image!);

    // Determine if we should treat as multi or single event
    if (_scheduleModel != null && _scheduleModel!.events.length > 1) {
      setState(() {
        _isMultiEvent = true;
        _isLoading = false;
      });
      _navigateToMultiEventSelection();
    } else if (_scheduleModel != null && _scheduleModel!.events.length == 1) {
      setState(() {
        _eventDetails = _scheduleModel!.events.first;
        _isMultiEvent = false;
        _isLoading = false;
      });
      _navigateToEventDetails();
    } else {
      setState(() {
        _ocrText = "No valid schedule or events detected.";
        _isLoading = false;
      });
      DialogHelper.showRetryDialog(context, _createBlankEvent, _startOCR);
    }
  }

  void _navigateToMultiEventSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MultiEventSelectionScreen(
              schedule: _scheduleModel!,
              onEventsSelected: (selectedEvents) {
                // Handle selected events
                setState(() {
                  _eventDetails =
                  selectedEvents.isNotEmpty ? selectedEvents.first : null;
                  _isMultiEvent = false;
                });
                _navigateToEventDetails();
              },
            ),
      ),
    );
  }

  void _createBlankEvent() {
    setState(() {
      _eventDetails = EventHelper.createBlankEvent();
      _ocrCompleted = true;
    });
    _navigateToEventDetails();
  }

  void _navigateToEventDetails() {
    if (_eventDetails == null) return;

    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 50), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EventDetailsScreen(
            event: _eventDetails!,
            onSave: (updatedEvent) {
              setState(() => _eventDetails = updatedEvent);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Event saved successfully!')),
              );
            },
          ),
        ),
      );
    });
  }

  Future<void> _scheduleEvent() async {
    if (_eventDetails == null) return;

    setState(() => _isScheduling = true);

    await EventHelper.scheduleEvent(
      context,
      _eventDetails!,
          () => setState(() => _isScheduling = false),
          () => setState(() => _isScheduling = false),
      _fetchUpcomingEvents,
    );

    setState(() {
      _eventDetails = null;  // After scheduling, clear the event card
    });
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
                    if (_eventDetails != null)
                      EventDetailsCard(
                        event: _eventDetails!,
                        onEdit: _navigateToEventDetails,
                        onSchedule: _scheduleEvent,
                        isScheduling: _isScheduling,
                      ),
                    if (_upcomingEvents.isNotEmpty) _buildUpcomingEvents(),
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
                      _eventDetails = null;
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
          ListView.builder(
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