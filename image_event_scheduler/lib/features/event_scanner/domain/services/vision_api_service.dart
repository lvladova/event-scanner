import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<String> extractTextFromImage(File imageFile, String apiKey) async {
  final bytes = await imageFile.readAsBytes();
  final base64Image = base64Encode(bytes);

  final response = await http.post(
    Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey'),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "requests": [
        {
          "image": {"content": base64Image},
          "features": [{"type": "TEXT_DETECTION", "maxResults": 1}]
        }
      ]
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['responses']?.isEmpty || data['responses'][0]['textAnnotations'] == null) {
      return "No text found in image";
    }
    final description = data['responses'][0]['textAnnotations'][0]['description'];
    return description ?? "No text found";
  } else {
    // Print detailed error message
    print('API Error Response: ${response.body}');
    throw Exception('Failed to extract text: ${response.statusCode}');
  }
}
