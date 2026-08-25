class MeetingVenue {
  const MeetingVenue({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.mapsUrl,
    this.distanceFromMidpointKm = 0,
  });

  final String id;
  final String name;
  final String category;
  final String address;
  final double latitude;
  final double longitude;
  final String mapsUrl;
  final double distanceFromMidpointKm;

  factory MeetingVenue.fromJson(Map<String, dynamic> json) {
    return MeetingVenue(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Meeting place',
      category: json['category'] as String? ?? 'Public place',
      address: json['address'] as String? ?? 'Address unavailable',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      mapsUrl: json['mapsUrl'] as String? ??
          json['mapUrl'] as String? ??
          '',
      distanceFromMidpointKm:
      (json['distanceFromMidpointKm'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'mapsUrl': mapsUrl,
      'distanceFromMidpointKm': distanceFromMidpointKm,
    };
  }
}
