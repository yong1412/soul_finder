import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:soul_finder/models/radar/radar_models.dart';

class StationService {
  static Future<List<Station>> loadStationsFromCsv({
    String assetPath = 'assets/data/stops.csv',
  }) async {
    final List<Station> stations = [];

    try {
      final String rawData = await rootBundle.loadString(assetPath);
      final List<String> lines = rawData.split('\n');

      if (lines.isEmpty) return stations;

      for (int i = 1; i < lines.length; i++) {
        final String line = lines[i].trim();
        if (line.isEmpty) continue;

        final List<String> fields = line.split(',');

        if (fields.length >= 5) {
          final String id = fields[0].replaceAll('"', '').trim();
          final String name = fields[1].replaceAll('"', '').trim();
          final double? lat = double.tryParse(fields[2].replaceAll('"', '').trim());
          final double? lon = double.tryParse(fields[3].replaceAll('"', '').trim());
          final String category = fields[4].replaceAll('"', '').trim().toUpperCase();

          if (lat != null && lon != null) {
            if (category == 'LRT' || category == 'MRT') {
              final StationType type = (category == 'LRT')
                  ? StationType.lrt
                  : StationType.mrt;

              stations.add(
                Station(
                  id: id,
                  name: name,
                  latitude: lat,
                  longitude: lon,
                  type: type,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Reading station CSV data error: $e');
      }
    }

    return stations;
  }

  static Set<Marker> convertToMarkers(
    List<Station> stations, {
    void Function(Station station)? onTap,
  }) {
    final Set<Marker> markers = {};

    for (final station in stations) {
      final double hue = (station.type == StationType.lrt)
          ? BitmapDescriptor.hueRed
          : BitmapDescriptor.hueAzure;

      final String typePrefix = station.type == StationType.lrt ? 'LRT' : 'MRT';

      markers.add(
        Marker(
          markerId: MarkerId(station.id),
          position: LatLng(station.latitude, station.longitude),
          infoWindow: InfoWindow(
            title: '$typePrefix - ${station.name}',
            snippet: 'Station Code: ${station.id}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          onTap: () {
            if (onTap != null) {
              onTap(station);
            }
          },
        ),
      );
    }

    return markers;
  }
}
