import 'package:soul_finder/models/radar/radar_models.dart';

class EventHotspot {
  final String id;
  final String? placeId;
  final String name;
  final String eventTitle;
  final String description;
  double latitude;
  double longitude;
  final double radiusMeters;
  
  int interestedCount;
  int activeAttendees;
  int totalStayMinutes;
  
  final DateTime eventTime;
  final String organizerName;
  bool isInterested;

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

  void updateCoordinates(double newLat, double newLng) {
    latitude = newLat;
    longitude = newLng;
  }

  void incrementInterested() {
    interestedCount++;
    isInterested = true;
  }

  void decrementInterested() {
    if (interestedCount > 0) interestedCount--;
    isInterested = false;
  }

  void addStayMinutes(int mins) {
    totalStayMinutes += mins;
  }

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
