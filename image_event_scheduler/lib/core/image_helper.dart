import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// A helper class to handle image picking from the gallery or camera.
class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> pickImageFromGallery() async {
    HapticFeedback.lightImpact();
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    return pickedFile != null ? File(pickedFile.path) : null;
  }

  static Future<File?> takePhotoWithCamera() async {
    HapticFeedback.lightImpact();
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
    return pickedFile != null ? File(pickedFile.path) : null;
  }
}
