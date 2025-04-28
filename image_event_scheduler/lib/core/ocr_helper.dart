import 'dart:io';
import '../../features/event_scanner/domain/event_model.dart';
import '../../features/event_scanner/domain/services/vision_api_service.dart';
import '../../features/event_scanner/domain/services/event_parser.dart';
import '../../features/event_scanner/domain/services/natural_language_service.dart';
import '../../config.dart';

class OCRHelper {
  static Future<String> extractTextOnly(File image) async {
    try {
      return await extractTextFromImage(image, Config.visionApiKey);
    } catch (e) {
      print('OCR failed: $e');
      return "";
    }
  }

  static Future<EventModel?> tryParseEvent(String text) async {
    if (Config.useNaturalLanguageAPI) {
      try {
        return await NaturalLanguageService.extractEventEntities(text, Config.visionApiKey);
      } catch (e) {
        print('NLP parsing failed: $e');
        // Fallback
      }
    }
    try {
      return EventParser.parseEventDetails(text);
    } catch (e) {
      print('Traditional parsing failed: $e');
      return null;
    }
  }
}

