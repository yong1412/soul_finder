enum StationType { lrt, mrt }

class Station {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final StationType type;

  Station({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
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
  int totalDurationMinutes;
  int visitCount;

  StationStayRecord({
    required this.station,
    required this.firstSeen,
    required this.lastSeen,
    this.totalDurationMinutes = 1,
    this.visitCount = 1,
  });

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
