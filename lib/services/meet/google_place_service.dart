import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GooglePlaceService {
  static const String _apiKey = 'AIzaSyCdU2CI4os8Xo6W4P-ePIwE4mc5idrPUQQ';

  static Future<Map<String, dynamic>?> getPlaceDetailsById(String placeId) async {
    final Uri url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=name,geometry,formatted_address,place_id&key=$_apiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];

          return {
            'placeId': result['place_id'] as String? ?? placeId,
            'name': result['name'] as String? ?? 'Serimas Condo • Pearl Tower',
            'address': result['formatted_address'] as String? ?? '',
            'latitude': (location['lat'] as num).toDouble(),
            'longitude': (location['lng'] as num).toDouble(),
          };
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Google Places API PlaceDetails Error: $e');
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> searchPlaceCoordinates(String query) async {
    final Uri url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}&key=$_apiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          final firstResult = data['results'][0];
          final location = firstResult['geometry']['location'];

          return {
            'placeId': firstResult['place_id'] as String,
            'name': firstResult['name'] as String,
            'address': firstResult['formatted_address'] as String,
            'latitude': (location['lat'] as num).toDouble(),
            'longitude': (location['lng'] as num).toDouble(),
          };
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Google Places API TextSearch Error: $e');
      }
    }
    return null;
  }
}
