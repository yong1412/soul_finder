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
    this.profileImageBase64 = '',
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
    };
  }

  factory UserProfile.fromJson(
      Map<String, dynamic> json,
      ) {
    return UserProfile(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      age: (json['age'] as num?)?.toInt() ?? 18,
      gender:
      json['gender'] as String? ?? 'Prefer not to say',
      bio: json['bio'] as String? ?? '',
      interests: List<String>.from(
        json['interests'] as List? ?? const [],
      ),
      lookingFor:
      json['lookingFor'] as String? ?? 'Friendship',
      discoveryRadius:
      (json['discoveryRadius'] as num?)?.toDouble() ?? 5,
      profileImageBase64:
      json['profileImageBase64'] as String? ?? '',
    );
  }
}