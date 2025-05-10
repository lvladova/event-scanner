import 'package:flutter/material.dart';

/// A widget that displays OCR information in a card format.
class OCRInfoCard extends StatelessWidget {
  final String ocrText;

  const OCRInfoCard({Key? key, required this.ocrText}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.info_outline, color: Colors.blue),
        title: const Text(
          'OCR text extracted successfully',
          style: TextStyle(color: Colors.white),
        ),
        trailing: TextButton(
          onPressed: () {
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
                            ocrText,
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
          },
          child: const Text('View Raw Text', style: TextStyle(color: Colors.blue)),
        ),
      ),
    );
  }
}
