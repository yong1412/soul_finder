class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.name,
    required this.age,
    required this.gender,
    required this.bio,
    required this.interests,
    required this.lookingFor,
    required this.discoveryRadius,
    required this.profileImageBase64,
    this.latitude,
    this.longitude,
  });

  final String uid;
  final String email;
  final String name;
  final int age;
  final String gender;
  final String bio;
  final List<String> interests;
  final String lookingFor;
  final double discoveryRadius;
  final String profileImageBase64;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      gender: json['gender'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      interests: (json['interests'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      lookingFor: json['lookingFor'] as String? ?? '',
      discoveryRadius:
      (json['discoveryRadius'] as num?)?.toDouble() ?? 5.0,
      profileImageBase64:
      json['profileImageBase64'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'age': age,
      'gender': gender,
      'bio': bio,
      'interests': interests,
      'lookingFor': lookingFor,
      'discoveryRadius': discoveryRadius,
      'profileImageBase64': profileImageBase64,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? name,
    int? age,
    String? gender,
    String? bio,
    List<String>? interests,
    String? lookingFor,
    double? discoveryRadius,
    String? profileImageBase64,
    double? latitude,
    double? longitude,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      lookingFor: lookingFor ?? this.lookingFor,
      discoveryRadius: discoveryRadius ?? this.discoveryRadius,
      profileImageBase64:
      profileImageBase64 ?? this.profileImageBase64,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
