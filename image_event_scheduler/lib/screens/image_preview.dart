import 'package:flutter/material.dart';
import 'dart:io';



// Create a new widget for image preview with zoom
class ImagePreviewScreen extends StatelessWidget {
  final File image;

  const ImagePreviewScreen({Key? key, required this.image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(image),
        ),
      ),
    );
  }
}