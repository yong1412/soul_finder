import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/radar/radar_models.dart';
import '../../services/event_hotspot_service.dart';
import '../../services/radar/location_service.dart';
import '../../services/radar/transport_service.dart';

class RadarController extends ChangeNotifier {
  RadarController({
    double? initialRadius,
    String? initialMode,
  })  : radarRadius = initialRadius ?? 200.0,
        scanMode = {initialMode == 'couple' ? 'couple' : 'friends'};

  final LocationService _locationService = LocationService();
  final TransportService _transportService = TransportService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 💾 Static memory cache storing loaded stay stats per user UID
  static final Map<String, Map<String, StationStayRecord>> _userStayStatsCache = {};
  static final Map<String, List<VisitRecord>> _userRecentStationsCache = {};

  Set<String> scanMode = {'friends'};
  final List<RadarDot> dots = [];
  Position? currentPosition;
  bool isLocationLoaded = false;
  bool isScanning = false;
  bool isHistoryLoaded = false; // 🔒 Guard flag
  int soulsFound = 0;
  Station? currentStationHotspot;
  double? minDistanceToStation;
  Station? nearestStation;
  double radarRadius = 200.0; // Default to 200m
  final List<VisitRecord> recentStations = [];
  final Map<String, StationStayRecord> stationStayStats = {};

  StreamSubscription<Position>? _positionSubscription;
  Timer? _stayTimer; // ⏰ Periodic timer to update stay duration while stationary at hotspot

  List<StationStayRecord> get topStayStations {
    final list = stationStayStats.values.toList();
    list.sort((a, b) {
      final cmp = b.totalDurationMinutes.compareTo(a.totalDurationMinutes);
      if (cmp != 0) return cmp;
      return b.lastSeen.compareTo(a.lastSeen);
    });
    return list;
  }

  /// 🚀 Pre-load user hotspot history from Firestore in the background BEFORE Radar starts
  static Future<void> preloadHotspotHistoryForUser(String uid) async {
    if (uid.isEmpty) return;

    try {
      debugPrint("PRELOAD HOTSPOTS: Starting background pre-load for user $uid...");
      final firestore = FirebaseFirestore.instance;

      final Map<String, StationStayRecord> stayStats = {};
      final List<VisitRecord> recents = [];

      // 1. Read parent document map 'visitedHotspots'
      final userDoc = await firestore.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final visitedMap = userData['visitedHotspots'] as Map<String, dynamic>? ?? {};

      visitedMap.forEach((stationId, data) {
        if (data is Map<String, dynamic>) {
          _parseHotspotDoc(stationId, data, stayStats, recents);
        }
      });

      // 2. Also read subcollection 'visited_hotspots' and merge with maximum values
      try {
        final snapshot = await firestore
            .collection('users')
            .doc(uid)
            .collection('visited_hotspots')
            .get();

        for (final doc in snapshot.docs) {
          _parseHotspotDoc(doc.id, doc.data(), stayStats, recents);
        }
      } catch (e) {
        debugPrint("Notice loading subcollection: $e");
      }

      recents.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _userStayStatsCache[uid] = stayStats;
      _userRecentStationsCache[uid] = recents;

      debugPrint("PRELOAD HOTSPOTS SUCCESS: Preloaded ${stayStats.length} saved hotspots for user $uid.");
    } catch (e) {
      debugPrint("Error preloading hotspot history for $uid: $e");
    }
  }

  static void _parseHotspotDoc(
    String id,
    Map<String, dynamic> data,
    Map<String, StationStayRecord> stayStats,
    List<VisitRecord> recents,
  ) {
    final stationTypeStr = data['stationType'] as String? ?? 'lrt';
    final stationType = StationType.values.firstWhere(
      (e) => e.name == stationTypeStr,
      orElse: () => StationType.lrt,
    );

    final station = Station(
      id: data['stationId'] as String? ?? id,
      name: data['stationName'] as String? ?? 'Hotspot',
      eventTitle: data['eventTitle'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      type: stationType,
      address: data['address'] as String?,
    );

    final lastSeen = DateTime.tryParse(data['lastSeen'] as String? ?? '') ?? DateTime.now();
    final firstSeen = DateTime.tryParse(data['firstSeen'] as String? ?? '') ?? lastSeen;
    final totalDuration = (data['totalDurationMinutes'] as num?)?.toInt() ?? 1;
    final visitCount = (data['visitCount'] as num?)?.toInt() ?? 1;

    if (stayStats.containsKey(station.id)) {
      // 🎯 Merge with maximum duration & visit count
      final existing = stayStats[station.id]!;
      final maxDuration = math.max(existing.totalDurationMinutes, totalDuration);
      existing.totalDurationMinutes = maxDuration;
      existing.initialHistoryDurationMinutes = maxDuration;
      existing.visitCount = math.max(existing.visitCount, visitCount);
      if (lastSeen.isAfter(existing.lastSeen)) {
        existing.lastSeen = lastSeen;
      }
    } else {
      final stayRecord = StationStayRecord(
        station: station,
        firstSeen: firstSeen,
        lastSeen: lastSeen,
        initialHistoryDurationMinutes: totalDuration, // Preserved history duration
        currentSessionFirstSeen: DateTime.now(), // Current session starts now
        totalDurationMinutes: totalDuration, // Preserved loaded duration
        visitCount: visitCount,
      );

      stayStats[station.id] = stayRecord;
      recents.add(VisitRecord(station: station, timestamp: lastSeen));
    }
  }

  void setScanMode(Set<String> mode) {
    scanMode = mode;
    final modeStr = mode.contains('couple') ? 'couple' : 'friends';
    _syncRadarModeToFirestore(modeStr);

    if (currentPosition != null) {
      performRadarScan(currentPosition!);
    }
    notifyListeners();
  }

  Future<void> _syncRadarModeToFirestore(String modeStr) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      await _firestore.collection('users').doc(uid).set({
        'radarMode': modeStr,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("RADAR MODE SYNCED TO FIRESTORE for $uid: $modeStr");
    } catch (e) {
      debugPrint("Notice syncing radar mode: $e");
    }
  }

  /// Update radar radius locally during dragging (0ms, no network scan yet)
  void setRadarRadiusLocal(double radius) {
    if ((radarRadius - radius).abs() < 0.1) return;
    radarRadius = radius;
    notifyListeners();
  }

  /// Commit new radar radius and perform network radar scan
  void setRadarRadius(double radius) {
    radarRadius = radius;
    if (currentPosition != null && !isScanning) {
      performRadarScan(currentPosition!);
    }
    notifyListeners();
  }

  void startLocationTracking() async {
    // 💾 1. Load this user's specific visited hotspots history
    await loadUserHotspotHistory();

    // ⏰ 2. Start periodic timer to accumulate stay duration even when phone is stationary
    _startStayTimer();

    try {
      final hasPermission = await _locationService.handleLocationPermission();
      if (!hasPermission) return;

      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        _updatePosition(position);
      }

      _positionSubscription = _locationService.getLocationStream().listen((position) {
        _updatePosition(position);
      }, onError: (e) {
        debugPrint("Location stream notice: $e");
      });
    } catch (e) {
      debugPrint("Location tracking start notice: $e");
    }
  }

  /// ⏰ Periodic timer running every 30 seconds to update stay duration and sync to Firestore
  void _startStayTimer() {
    _stayTimer?.cancel();
    _stayTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      try {
        if (currentStationHotspot != null) {
          _recordStationStay(currentStationHotspot!);
          notifyListeners();
        } else if (nearestStation != null && (minDistanceToStation ?? 1.0) <= 0.25) {
          _recordStationStay(nearestStation!);
          notifyListeners();
        }
      } catch (e) {
        debugPrint("Notice in stay timer: $e");
      }
    });
  }

  /// 💾 Load user's persistent visited hotspots & stay stats
  Future<void> loadUserHotspotHistory() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      isHistoryLoaded = true;
      notifyListeners();
      return;
    }

    // ⚡ If preloaded in memory cache, load instantly in 0ms!
    if (_userStayStatsCache.containsKey(uid)) {
      debugPrint("HOTSPOT SYNC: Instant load from preloaded memory cache for user $uid!");
      stationStayStats.clear();
      recentStations.clear();
      stationStayStats.addAll(_userStayStatsCache[uid]!);
      recentStations.addAll(_userRecentStationsCache[uid] ?? []);
      isHistoryLoaded = true;
      notifyListeners();
      return;
    }

    // Otherwise, fetch from Firestore
    await preloadHotspotHistoryForUser(uid);
    if (_userStayStatsCache.containsKey(uid)) {
      stationStayStats.clear();
      recentStations.clear();
      stationStayStats.addAll(_userStayStatsCache[uid]!);
      recentStations.addAll(_userRecentStationsCache[uid] ?? []);
    }

    isHistoryLoaded = true;
    notifyListeners();
  }

  /// 💾 Sync visited hotspot & stay duration to Firestore users/{uid} AND subcollection
  Future<void> _syncHotspotToFirestore(Station station, StationStayRecord record) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      debugPrint("HOTSPOT SYNC FAIL: No logged-in user UID.");
      return;
    }

    final String hotspotDisplayTitle = (station.eventTitle != null && station.eventTitle!.trim().isNotEmpty)
        ? station.eventTitle!
        : station.name;

    final Map<String, dynamic> hotspotData = {
      'stationId': station.id,
      'stationName': station.name,
      'eventTitle': station.eventTitle ?? '',
      'stationType': station.type.name,
      'latitude': station.latitude,
      'longitude': station.longitude,
      'address': station.address ?? '',
      'totalDurationMinutes': record.totalDurationMinutes,
      'visitCount': record.visitCount,
      'firstSeen': record.firstSeen.toIso8601String(),
      'lastSeen': record.lastSeen.toIso8601String(),
    };

    try {
      debugPrint("HOTSPOT SYNC START: Writing visitedHotspots for user $uid... (Duration: ${record.totalDurationMinutes} mins, Visits: ${record.visitCount})");

      final userDocRef = _firestore.collection('users').doc(uid);

      // 1. Write using dot notation 'visitedHotspots.${station.id}' to merge map keys safely without replacing other stations!
      try {
        await userDocRef.update({
          'visitedHotspotIds': FieldValue.arrayUnion([station.id]),
          'lastVisitedHotspot': hotspotDisplayTitle,
          'lastVisitedHotspotName': station.name,
          'hotspotUpdatedAt': FieldValue.serverTimestamp(),
          'visitedHotspots.${station.id}': hotspotData,
        });
      } catch (_) {
        // Fallback to set if document is new
        await userDocRef.set({
          'visitedHotspotIds': FieldValue.arrayUnion([station.id]),
          'lastVisitedHotspot': hotspotDisplayTitle,
          'lastVisitedHotspotName': station.name,
          'hotspotUpdatedAt': FieldValue.serverTimestamp(),
          'visitedHotspots': {
            station.id: hotspotData,
          },
        }, SetOptions(merge: true));
      }

      // 2. Also write to subcollection users/{uid}/visited_hotspots/{station.id}
      try {
        await userDocRef.collection('visited_hotspots').doc(station.id).set(hotspotData, SetOptions(merge: true));
      } catch (subErr) {
        debugPrint("Subcollection write notice: $subErr");
      }

      debugPrint("HOTSPOT SYNC SUCCESS: Successfully wrote visitedHotspots for user $uid -> ${station.id} (${record.totalDurationMinutes} mins, ${record.visitCount} visits)");
    } catch (e, stack) {
      debugPrint("HOTSPOT SYNC ERROR: Failed to write to Firestore for $uid: $e\n$stack");
    }
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

    if (stations.isEmpty) {
      stations = _generateMockStations(position);
    }

    // Include Event Hotspots (e.g., Serimas Condominium Pearl Tower) as active Radar locations
    final eventStations = EventHotspotService().getEventStations();
    stations.addAll(eventStations);

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

      // Check if user is inside the hotspot radius
      if (distance <= radarRadius / 1000.0) { // Use selected radarRadius (e.g., 200m)
        currentStationHotspot = station;
        _addToRecentStations(station);
        _recordStationStay(station);

        int soulsAtStation = 2 + random.nextInt(3);
        for (int i = 0; i < soulsAtStation; i++) {
          double angle = (i * (2 * math.pi / soulsAtStation)) + (random.nextDouble() - 0.5) * 0.8;
          // Spread dots out to outer radar rings (0.42 to 0.92 radius ratio) for clear visibility
          double outerRadius = 0.42 + (random.nextDouble() * 0.50);

          dots.add(RadarDot(
            distance: outerRadius,
            angle: angle,
            size: 6.0 + random.nextDouble() * 4,
          ));
        }
      }
    }

    // Force record nearest station/event if user is within 250m vicinity
    if (currentStationHotspot == null && nearestStation != null && minDistance <= 0.25) {
      _addToRecentStations(nearestStation!);
      _recordStationStay(nearestStation!);
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
    if (!isHistoryLoaded) {
      debugPrint("HOTSPOT SYNC: Skipped recording - Waiting for Firestore history to finish loading.");
      return;
    }

    final now = DateTime.now();
    late StationStayRecord record;

    if (stationStayStats.containsKey(station.id)) {
      record = stationStayStats[station.id]!;

      // 🎯 Check if this is a new visit session (> 30 mins since last seen at this hotspot)
      final minsSinceLastSeen = now.difference(record.lastSeen).inMinutes;
      if (minsSinceLastSeen > 30) {
        record.visitCount++; // Increments visit count on new visit session!
        record.currentSessionFirstSeen = now;
        debugPrint("HOTSPOT SYNC: New visit session detected for ${station.id}! Visit count is now ${record.visitCount}");
      }

      // Calculate total duration in minutes since initial arrival at this hotspot
      final minutesInSession = now.difference(record.currentSessionFirstSeen).inMinutes;
      final newTotalMinutes = record.initialHistoryDurationMinutes + minutesInSession + 1;

      if (newTotalMinutes > record.totalDurationMinutes) {
        final addedMins = newTotalMinutes - record.totalDurationMinutes;
        record.totalDurationMinutes = newTotalMinutes;

        // If it's an Event Hotspot, also increment Event's total stay duration in EventHotspotService!
        if (station.type == StationType.event) {
          EventHotspotService().recordStayMinutes(station.id, addedMins);
        }
      }

      record.lastSeen = now;
    } else {
      record = StationStayRecord(
        station: station,
        firstSeen: now,
        lastSeen: now,
        initialHistoryDurationMinutes: 0,
        currentSessionFirstSeen: now,
        totalDurationMinutes: 1,
        visitCount: 1,
      );
      stationStayStats[station.id] = record;
    }

    _syncHotspotToFirestore(station, record);
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
    _stayTimer?.cancel();
    super.dispose();
  }
}
