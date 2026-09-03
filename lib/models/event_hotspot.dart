import 'radar/radar_models.dart';

class EventHotspot {
  final String id;
  final String? placeId; // 👈 Google Place ID for high-precision building identification
  final String name; // e.g., "Serimas Condominium Pearl Tower"
  final String eventTitle; // e.g., "Pearl Tower Resident & Soul Gathering"
  final String description;
  double latitude; // Mutable in case coordinates are refreshed via Place ID
  double longitude;
  final double radiusMeters;
  
  // 📈 Incremental fields
  int interestedCount; // Interested people count
  int activeAttendees; // People currently in vicinity
  int totalStayMinutes; // Cumulative stay duration in minutes
  
  final DateTime eventTime;
  final String organizerName;
  bool isInterested; // Whether current user is interested

  EventHotspot({
    required this.id,
    this.placeId,
    required this.name,
    required this.eventTitle,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 200.0,
    this.interestedCount = 128,
    this.activeAttendees = 15,
    this.totalStayMinutes = 840,
    required this.eventTime,
    required this.organizerName,
    this.isInterested = false,
  });

  /// Update coordinates if fetched from Google Place ID Details API
  void updateCoordinates(double newLat, double newLng) {
    latitude = newLat;
    longitude = newLng;
  }

  /// Increment interested count
  void incrementInterested() {
    interestedCount++;
    isInterested = true;
  }

  /// Decrement interested count
  void decrementInterested() {
    if (interestedCount > 0) interestedCount--;
    isInterested = false;
  }

  /// Increment stay duration
  void addStayMinutes(int mins) {
    totalStayMinutes += mins;
  }

  /// Convert EventHotspot to a Station for Radar integration
  Station toStation() {
    return Station(
      id: id,
      name: name,
      eventTitle: eventTitle,
      latitude: latitude,
      longitude: longitude,
      type: StationType.event,
      address: description,
    );
  }
}
