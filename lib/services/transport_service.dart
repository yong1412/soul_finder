import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/station.dart';

class TransportService {
  // Replace with your actual Google Maps API Key
  static const String _apiKey = 'AIzaSyCdU2CI4os8Xo6W4P-ePIwE4mc5idrPUQQ';

  Future<List<Station>> getNearbyStations(double lat, double lng) async {
    const String url = 'https://places.googleapis.com/v1/places:searchNearby';
    
    final Map<String, dynamic> body = {
      "includedTypes": [
        "transit_station", 
        "light_rail_station", 
        "subway_station", 
        "train_station",
        "bus_station"
      ],
      "maxResultCount": 10,
      "locationRestriction": {
        "circle": {
          "center": {
            "latitude": lat,
            "longitude": lng
          },
          "radius": 2000.0 // 2km radius
        }
      }
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'places.id,places.displayName,places.location,places.types',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> places = data['places'] ?? [];
        
        return places.map((place) {
          final types = List<String>.from(place['types'] ?? []);
          StationType type = StationType.bus;
          
          if (types.contains('subway_station') || types.contains('light_rail_station')) {
            type = StationType.lrt;
          } else if (types.contains('train_station')) {
            type = StationType.mrt;
          }

          return Station(
            id: place['id'],
            name: place['displayName']['text'],
            latitude: place['location']['latitude'],
            longitude: place['location']['longitude'],
            type: type,
          );
        }).toList();
      } else {
        print('Places API Error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception fetching places: $e');
      return [];
    }
  }
}
