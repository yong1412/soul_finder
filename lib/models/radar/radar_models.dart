enum StationType { bus, lrt, mrt }

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
