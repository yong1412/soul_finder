import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ImageUploadService {
  static const String _apiKey = '4178054791d9da8835876b76e5556440';
  static const String _apiUrl = 'https://api.imgbb.com/1/upload';

  /// Uploads an image to ImgBB and returns the direct image URL.
  static Future<String> uploadImage(XFile imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_apiUrl));
      request.fields['key'] = _apiKey;
      
      final file = await http.MultipartFile.fromPath('image', imageFile.path);
      request.files.add(file);

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(responseBody);
        return jsonResponse['data']['url'] as String;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Image upload error: $e');
    }
  }
}
