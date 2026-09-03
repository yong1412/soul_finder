import 'package:flutter/foundation.dart';
import '../models/event_hotspot.dart';
import '../models/radar/radar_models.dart';
import 'google_place_service.dart';

class EventHotspotService extends ChangeNotifier {
  static final EventHotspotService _instance = EventHotspotService._internal();
  factory EventHotspotService() => _instance;
  EventHotspotService._internal() {
    _initSampleData();
  }

  final List<EventHotspot> _events = [];

  List<EventHotspot> get events => List.unmodifiable(_events);

  void _initSampleData() {
    _events.add(
      EventHotspot(
        id: 'pv9_residence_01',
        placeId: '0x31cc3868d78cf65d:0x8797f6534766c032', // Exact Google Maps Place Hex CID
        name: 'PV 9 Residence',
        eventTitle: 'PV 9 Residence Community Event',
        description: 'PV 9 Residence Lounge & Pool Deck Area',
        latitude: 3.2179226, // Exact Google Maps Latitude
        longitude: 101.7251751, // Exact Google Maps Longitude
        radiusMeters: 300.0,
        interestedCount: 165,
        activeAttendees: 18,
        totalStayMinutes: 620,
        eventTime: DateTime.now().add(const Duration(hours: 2)),
        organizerName: 'PV 9 Resident Association',
      ),
    );

    _events.add(
      EventHotspot(
        id: 'tarumt_block_b_02',
        placeId: '0x31cc39eae76d5993:0x695c30c1a3b16071', // Exact Google Maps Place Hex CID
        name: 'Block B, TARUMT',
        eventTitle: 'TARUMT Block B Student & Campus Gathering',
        description: 'Tunku Abdul Rahman University Management & Technology - Block B',
        latitude: 3.2154575, // Exact Google Maps Latitude
        longitude: 101.7266504, // Exact Google Maps Longitude
        radiusMeters: 200.0,
        interestedCount: 240,
        activeAttendees: 35,
        totalStayMinutes: 1120,
        eventTime: DateTime.now().add(const Duration(hours: 4)),
        organizerName: 'TARUMT Student Society',
      ),
    );

    _events.add(
      EventHotspot(
        id: 'serimas_pearl_tower_01',
        placeId: '0x31cc37638b0709ed:0x6249f472d36b8fae', // Exact Google Maps Place Hex CID
        name: 'Serimas Condo • Pearl Tower',
        eventTitle: 'Pearl Tower Community & Soul Gathering',
        description: 'Serimas Condo • Pearl Tower Swimming Pool Deck & Lounge',
        latitude: 3.1126352,
        longitude: 101.7225298,
        radiusMeters: 200.0,
        interestedCount: 128,
        activeAttendees: 15,
        totalStayMinutes: 840,
        eventTime: DateTime.now().add(const Duration(hours: 3)),
        organizerName: 'Serimas Resident Committee',
      ),
    );

    _events.add(
      EventHotspot(
        id: 'klcc_park_event_02',
        placeId: 'ChIJz2q8C6Q3zDER4q_62i1q6hM', // KLCC Place ID
        name: 'KLCC Symphony Lake Park',
        eventTitle: 'Evening Soul Walking & Fountain Light Show',
        description: 'KLCC Esplanade Fountain Area',
        latitude: 3.1578,
        longitude: 101.7119,
        radiusMeters: 250.0,
        interestedCount: 310,
        activeAttendees: 42,
        totalStayMinutes: 1950,
        eventTime: DateTime.now().add(const Duration(hours: 5)),
        organizerName: 'KLCC Transit Club',
      ),
    );
  }

  /// Synchronize & update event location using Google Place ID or Text Search
  Future<bool> syncLocationWithGooglePlace(String hotspotId) async {
    final index = _events.indexWhere((e) => e.id == hotspotId);
    if (index == -1) return false;

    final event = _events[index];
    Map<String, dynamic>? details;

    if (event.placeId != null && event.placeId!.isNotEmpty) {
      details = await GooglePlaceService.getPlaceDetailsById(event.placeId!);
    }

    // Fallback to text search if Place ID returned no result
    if (details == null) {
      details = await GooglePlaceService.searchPlaceCoordinates(event.name);
    }

    if (details != null) {
      final double lat = details['latitude'];
      final double lng = details['longitude'];
      event.updateCoordinates(lat, lng);
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Toggle Interested status (+1 interested count)
  void toggleInterested(String id) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index != -1) {
      final event = _events[index];
      if (event.isInterested) {
        event.decrementInterested();
      } else {
        event.incrementInterested();
      }
      notifyListeners();
    }
  }

  /// Record accumulated stay time in minutes
  void recordStayMinutes(String id, int minutes) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index != -1) {
      _events[index].addStayMinutes(minutes);
      notifyListeners();
    }
  }

  /// Returns Event Hotspots formatted as Stations for Radar scanning
  List<Station> getEventStations() {
    return _events.map((e) => e.toStation()).toList();
  }
}
