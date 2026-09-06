import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String _cloudName = 'dghpgiqr'; 
  static const String _uploadPreset = 'Soul_Finder';

  static Future<String> uploadMedia(XFile file, {bool isVideo = false, bool isAudio = false}) async {
    final String resourceType = (isVideo || isAudio) ? 'video' : 'image';
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');

    try {
      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty ? file.name : 'upload_${DateTime.now().millisecondsSinceEpoch}';

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: filename,
          ),
        );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseData);
        return jsonResponse['secure_url'] as String;
      } else {
        throw Exception('Cloudinary upload failed: ${response.statusCode} - $responseData');
      }
    } catch (e) {
      throw Exception('Failed to upload media to Cloudinary: $e');
    }
  }

  static String getVideoThumbnail(String videoUrl) {
    if (!videoUrl.contains('upload/')) return videoUrl;
    return videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv)$'), '.jpg');
  }
}
