# Image Event Scheduler

A Flutter-based mobile application that extracts event information from images and automatically schedules them to your calendar.

## Overview

Image Event Scheduler uses AI-driven image recognition and OCR (Optical Character Recognition) to extract event details from posters, flyers, and other visual content. With just a photo, the app identifies event titles, dates, times, and locations, allowing you to quickly add events to your calendar.

## Features

- **Image Recognition**: Capture or upload images of event posters
- **Automated Text Extraction**: Uses Google Cloud Vision API for accurate OCR
- **Smart Detail Parsing**: Intelligently identifies event dates, times, and locations
- **Manual Verification**: Review and edit extracted information before saving
- **Calendar Integration**: Add events directly to your device calendar
- **Modern UI**: Sleek, futuristic interface with intuitive navigation

## Getting Started

### Prerequisites

- Flutter 3.7 or higher
- Dart 3.0 or higher
- A Google Cloud Vision API key

### Installation

1. Clone this repository
   ```
   git clone https://github.com/yourusername/image_event_scheduler.git
   ```

2. Navigate to the project directory
   ```
   cd image_event_scheduler
   ```

3. Create a config.dart file in the lib directory with your API key
   ```dart
   class Config {
     static const String visionApiKey = 'YOUR_GOOGLE_CLOUD_VISION_API_KEY';
     static const bool useNaturalLanguageAPI = true;
   }
   ```

4. Install dependencies
   ```
   flutter pub get
   ```

5. Run the app
   ```
   flutter run
   ```

### Permissions

The app requires the following permissions:
- Camera (for capturing images)
- Gallery access (for selecting images)
- Calendar access (for adding events)

## Technology Stack

- **Frontend**: Flutter
- **OCR**: Google Cloud Vision API
- **Calendar Integration**: device_calendar package
- **State Management**: Flutter's built-in state management

## Project Structure

```
lib/
├── core/                # Core utilities
├── features/           
│   └── event_scanner/   # Event scanning feature
│       ├── domain/      # Business logic and models
│       └── presentation/ # UI components
├── screens/             # App screens
├── shared/              # Shared components
│   ├── theme/           # Styling and theming
│   └── widgets/         # Reusable widgets
└── main.dart            # App entry point
```

## Future Enhancements

- Enhanced event recognition accuracy
- Template-based recognition for specific event formats
- Cloud synchronization
- Recurring event detection
- Multi-event scanning from a single image

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Research paper: "AI-Driven Image Recognition for Automated Event Scheduling in Calendar Applications"
- Google Cloud Vision API documentation
- Flutter and Dart documentation