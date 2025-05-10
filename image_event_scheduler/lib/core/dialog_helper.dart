import 'package:flutter/material.dart';

/// A helper class to show a dialog for retrying OCR or entering event details manually.
class DialogHelper {
  static void showRetryDialog(BuildContext context, VoidCallback onManualEntry, VoidCallback onRetry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2C),
        title: const Text('OCR Failed'),
        content: const Text('Unable to extract text from the image. Would you like to try again or enter event details manually?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onManualEntry();
            },
            child: const Text('Enter Manually'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
