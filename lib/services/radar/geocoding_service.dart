import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final String displayName;
  final String road;
  final String suburb;
  final String city;
  final String state;

  GeocodingResult({
    required this.displayName,
    required this.road,
    required this.suburb,
    required this.city,
    required this.state,
  });

  String get shortAddress {
    final parts = <String>[];
    if (road.isNotEmpty) parts.add(road);
    if (suburb.isNotEmpty) parts.add(suburb);
    if (city.isNotEmpty && city != suburb) parts.add(city);
    return parts.isNotEmpty ? parts.join(', ') : displayName;
  }
}

class GeocodingService {
  // In-memory cache for fast reverse geocoding lookups
  static final Map<String, GeocodingResult> _cache = {};

  /// Reverse Geocode: Convert Latitude & Longitude to Human Readable LRT/MRT Station Address
  Future<GeocodingResult?> reverseGeocode(double lat, double lng) async {
    final cacheKey = "${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}";
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SoulFinderApp/1.0',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['address'] as Map<String, dynamic>? ?? {};

        final result = GeocodingResult(
          displayName: data['display_name'] as String? ?? 'Unknown Station Area',
          road: address['road'] as String? ?? address['pedestrian'] as String? ?? '',
          suburb: address['suburb'] as String? ?? address['neighbourhood'] as String? ?? address['quarter'] as String? ?? '',
          city: address['city'] as String? ?? address['town'] as String? ?? address['county'] as String? ?? '',
          state: address['state'] as String? ?? '',
        );

        _cache[cacheKey] = result;
        return result;
      }
    } catch (e) {
      debugPrint("Geocoding failed for $lat,$lng: $e");
    }
    return null;
  }

  /// Forward Geocode: Search LRT/MRT Station by Name -> Lat & Lng
  Future<Map<String, double>?> searchStationCoordinates(String stationName) async {
    final query = Uri.encodeComponent("$stationName station Malaysia");
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1');

    try {
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'SoulFinderApp/1.0',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        if (results.isNotEmpty) {
          final first = results.first;
          final lat = double.parse(first['lat']);
          final lon = double.parse(first['lon']);
          return {'latitude': lat, 'longitude': lon};
        }
      }
    } catch (e) {
      debugPrint("Forward geocoding failed for $stationName: $e");
    }
    return null;
  }
}
