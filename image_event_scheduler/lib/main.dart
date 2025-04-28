import 'package:flutter/material.dart';
import 'config.dart';
import 'features/event_scanner/presentation/image_upload_page.dart';
import 'shared/theme/futuristic_theme.dart';
import 'shared/widgets/futuristic_background.dart';
import 'features/event_scanner/domain/services/calendar_service.dart';

void main() {
  CalendarService.initializeTimeZones();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Event Scanner',
      debugShowCheckedModeBanner: false,
      theme: FuturisticTheme.darkTheme,
      home: FuturisticBackground(
        child: const ImageUploadPage(),
      ),
    );
  }
}
