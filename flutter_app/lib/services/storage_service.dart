import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Cloudinary configuration
class CloudinaryConfig {
  static const String cloudName = 'dnmr9yxyv';
  static const String uploadPreset = 'ocr_unsigned';  // Create this in Cloudinary settings
}

class StorageService {
  /// Upload image to Cloudinary (FREE - no credit card required)
  /// Returns the secure URL of the uploaded image
  Future<String> uploadImage(String userId, String requestId, File file) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload'
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
        ..fields['folder'] = 'ocr_images/$userId'
        ..fields['public_id'] = requestId
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['secure_url'] as String;
      } else {
        final error = json.decode(response.body);
        throw Exception('Upload failed: ${error['error']?['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }
}
