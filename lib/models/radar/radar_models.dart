enum StationType { lrt, mrt, event }

class Station {
  final String id;
  final String name; // Place name
  final String? eventTitle; // Event Title (used when type == StationType.event)
  final double latitude;
  final double longitude;
  final StationType type;
  final String? address;

  Station({
    required this.id,
    required this.name,
    this.eventTitle,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.address,
  });
}

class VisitRecord {
  final Station station;
  final DateTime timestamp;

  VisitRecord({
    required this.station,
    required this.timestamp,
  });
}

class StationStayRecord {
  final Station station;
  DateTime firstSeen;
  DateTime lastSeen;
  int initialHistoryDurationMinutes; // Accumulated minutes loaded from Firestore before current session
  DateTime currentSessionFirstSeen; // Session start timestamp
  int totalDurationMinutes;
  int visitCount;

  StationStayRecord({
    required this.station,
    required this.firstSeen,
    required this.lastSeen,
    this.initialHistoryDurationMinutes = 0,
    DateTime? currentSessionFirstSeen,
    required this.totalDurationMinutes,
    this.visitCount = 1,
  }) : currentSessionFirstSeen = currentSessionFirstSeen ?? DateTime.now();

  String get formattedDuration {
    if (totalDurationMinutes < 1) return "< 1 min";
    final hours = totalDurationMinutes ~/ 60;
    final mins = totalDurationMinutes % 60;
    if (hours > 0) {
      return "${hours}h ${mins}m";
    }
    return "${mins}m";
  }
}

class RadarDot {
  final double distance;
  final double angle;
  final double size;

  RadarDot({
    required this.distance,
    required this.angle,
    required this.size,
  });
}
