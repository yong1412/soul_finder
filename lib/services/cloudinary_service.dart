import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const String _cloudName = 'dghpgiqr'; 
  static const String _uploadPreset = 'Soul_Finder';

  static Future<String> uploadMedia(XFile file, {bool isVideo = false}) async {
    final String resourceType = isVideo ? 'video' : 'image';
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');

    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

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

  /// 辅助方法：将 Cloudinary 视频链接转换为封面图链接
  static String getVideoThumbnail(String videoUrl) {
    if (!videoUrl.contains('upload/')) return videoUrl;
    // Cloudinary 支持通过更改扩展名直接生成视频封面
    return videoUrl.replaceAll(RegExp(r'\.(mp4|mov|avi|wmv)$'), '.jpg');
  }
}
