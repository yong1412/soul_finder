import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/radar/radar_models.dart';
import '../../services/radar/location_service.dart';
import '../../services/radar/transport_service.dart';

class RadarController extends ChangeNotifier {
  RadarController({double? initialRadius}) : radarRadius = initialRadius ?? 200.0;

  final LocationService _locationService = LocationService();
  final TransportService _transportService = TransportService();

  Set<String> scanMode = {'friends'};
  final List<RadarDot> dots = [];
  Position? currentPosition;
  bool isLocationLoaded = false;
  bool isScanning = false;
  int soulsFound = 0;
  Station? currentStationHotspot;
  double? minDistanceToStation;
  Station? nearestStation;
  double radarRadius = 200.0; // Default to 200m
  final List<VisitRecord> recentStations = [];
  final Map<String, StationStayRecord> stationStayStats = {};

  List<StationStayRecord> get topStayStations {
    final list = stationStayStats.values.toList();
    list.sort((a, b) {
      final cmp = b.totalDurationMinutes.compareTo(a.totalDurationMinutes);
      if (cmp != 0) return cmp;
      return b.lastSeen.compareTo(a.lastSeen);
    });
    return list;
  }

  StreamSubscription<Position>? _positionSubscription;

  void setScanMode(Set<String> mode) {
    scanMode = mode;
    if (currentPosition != null) {
      performRadarScan(currentPosition!);
    }
    notifyListeners();
  }

  void setRadarRadius(double radius) {
    radarRadius = radius;
    if (currentPosition != null) {
      performRadarScan(currentPosition!);
    }
    notifyListeners();
  }

  void startLocationTracking() async {
    final hasPermission = await _locationService.handleLocationPermission();
    if (!hasPermission) return;

    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      _updatePosition(position);
    }

    _positionSubscription = _locationService.getLocationStream().listen((position) {
      _updatePosition(position);
    });
  }

  void _updatePosition(Position position) {
    currentPosition = position;
    isLocationLoaded = true;
    notifyListeners();
    performRadarScan(position);
  }

  Future<void> performRadarScan(Position position) async {
    if (isScanning) return;
    isScanning = true;
    notifyListeners();

    var stations = await _transportService.getNearbyStations(
      position.latitude,
      position.longitude
    );

    // If API returns no stations (e.g. invalid API key or no real stations nearby), 
    // provide some mock LRT/MRT stations for testing/demo purposes.
    if (stations.isEmpty) {
      stations = _generateMockStations(position);
    }

    isScanning = false;
    _generateSoulsFromHotspots(position, stations);
    notifyListeners();
  }

  List<Station> _generateMockStations(Position pos) {
    return [
      Station(
        id: 'mock_lrt_1',
        name: 'KLCC LRT Station (Mock)',
        latitude: pos.latitude + 0.002,
        longitude: pos.longitude + 0.001,
        type: StationType.lrt,
      ),
      Station(
        id: 'mock_mrt_1',
        name: 'Bukit Bintang MRT (Mock)',
        latitude: pos.latitude - 0.003,
        longitude: pos.longitude + 0.004,
        type: StationType.mrt,
      ),
    ];
  }

  void _generateSoulsFromHotspots(Position current, List<Station> stations) {
    dots.clear();
    final random = math.Random();

    currentStationHotspot = null;
    nearestStation = null;
    double minDistance = double.infinity;

    for (var station in stations) {
      double distance = _calculateDistance(
        current.latitude, current.longitude,
        station.latitude, station.longitude
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestStation = station;
      }

      if (distance <= radarRadius / 1000.0) { // Use selected radarRadius
        currentStationHotspot = station;
        _addToRecentStations(station);
        _recordStationStay(station);

        int soulsAtStation = 1 + random.nextInt(3);
        for (int i = 0; i < soulsAtStation; i++) {
          double offsetLat = (random.nextDouble() - 0.5) * 0.005;
          final double offsetLng = (random.nextDouble() - 0.5) * 0.005;

          double relativeLat = (station.latitude + offsetLat) - current.latitude;
          double relativeLng = (station.longitude + offsetLng) - current.longitude;

          double radarDist = math.sqrt(relativeLat * relativeLat + relativeLng * relativeLng) * 1000;
          double angle = math.atan2(relativeLat, relativeLng);

          // Normalize distance relative to radarRadius (outer edge of visual radar)
          dots.add(RadarDot(
            distance: (radarDist / radarRadius).clamp(0.1, 0.98),
            angle: angle,
            size: 4.0 + random.nextDouble() * 4,
          ));
        }
      }
    }
    soulsFound = dots.length;
    minDistanceToStation = minDistance == double.infinity ? null : minDistance;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = math.cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) *
            (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  void _recordStationStay(Station station) {
    final now = DateTime.now();
    if (stationStayStats.containsKey(station.id)) {
      final record = stationStayStats[station.id]!;
      final diffMins = now.difference(record.lastSeen).inMinutes;
      if (diffMins >= 1) {
        record.totalDurationMinutes += diffMins;
        record.lastSeen = now;
      } else {
        record.lastSeen = now;
      }
    } else {
      stationStayStats[station.id] = StationStayRecord(
        station: station,
        firstSeen: now,
        lastSeen: now,
        totalDurationMinutes: 1,
        visitCount: 1,
      );
    }
  }

  void _addToRecentStations(Station station) {
    final now = DateTime.now();
    bool existsRecently = recentStations.any((r) =>
      r.station.id == station.id &&
      now.difference(r.timestamp).inMinutes < 60
    );

    if (!existsRecently) {
      recentStations.insert(0, VisitRecord(
        station: station,
        timestamp: now,
      ));
      if (recentStations.length > 10) {
        recentStations.removeLast();
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }
}
