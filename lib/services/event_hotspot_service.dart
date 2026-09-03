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
        id: 'serimas_pearl_tower_01',
        placeId: '0x31cc37638b0709ed:0x6249f472d36b8fae', // Exact Google Maps Place Hex CID
        name: 'Serimas Condo • Pearl Tower', // 👈 Exact Google Maps Name
        eventTitle: 'Pearl Tower Community & Soul Gathering',
        description: 'Serimas Condo • Pearl Tower Swimming Pool Deck & Lounge',
        latitude: 3.1126352, // 👈 Exact Google Maps Latitude
        longitude: 101.7225298, // 👈 Exact Google Maps Longitude
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
