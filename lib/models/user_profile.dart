import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/report_service.dart';

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
    this.isOnline = true,
    this.hideOnlineStatus = false,
    this.radarMode = 'friends',
    this.accountStatus = 'active', // 'active', 'suspended', 'banned'
    this.reportCount = 0,
    this.bannedUntil,
    this.heightCm,
    this.weightKg,
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
  final bool isOnline;
  final bool hideOnlineStatus;
  final String radarMode; // 'friends' or 'couple'
  final String accountStatus; // 'active', 'suspended', 'banned'
  final int reportCount;
  final DateTime? bannedUntil;
  final double? heightCm;
  final double? weightKg;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  /// Public online status visible to others (Hidden if user activated hideOnlineStatus)
  bool get isPubliclyOnline => isOnline && !hideOnlineStatus;

  /// Check if user is currently banned for 3 days due to 10+ reports from 3+ reporters
  bool get isBanned {
    if (accountStatus == 'banned') {
      if (bannedUntil == null) return true;
      return DateTime.now().isBefore(bannedUntil!);
    }
    return false;
  }

  /// Check if user account is marked as suspended (> 5 reports)
  bool get isSuspended {
    if (isBanned) return false;
    return accountStatus == 'suspended' || reportCount >= 5;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final uid = json['uid'] as String? ?? '';
    final bannedTimestamp = json['bannedUntil'] as Timestamp?;

    // Check cached moderation status evaluated from reports
    final cachedStatus = ReportService.getModerationStatus(uid);
    final rawStatus = json['accountStatus'] as String? ?? 'active';
    final rawReportCount = (json['reportCount'] as num?)?.toInt() ?? 0;

    final finalAccountStatus = cachedStatus?.status ?? rawStatus;
    final finalReportCount = cachedStatus != null
        ? math.max(cachedStatus.reportCount, rawReportCount)
        : rawReportCount;
    final finalBannedUntil = cachedStatus?.bannedUntil ?? bannedTimestamp?.toDate();

    return UserProfile(
      uid: uid,
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
      ((json['discoveryRadius'] as num?)?.toDouble() ?? 0.2).clamp(0.05, 0.2),
      profileImageBase64:
      json['profileImageBase64'] as String? ?? '',
      isOnline: json['isOnline'] as bool? ?? true,
      hideOnlineStatus: json['hideOnlineStatus'] as bool? ?? false,
      radarMode: json['radarMode'] as String? ?? 'friends',
      accountStatus: finalAccountStatus,
      reportCount: finalReportCount,
      bannedUntil: finalBannedUntil,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
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
      'isOnline': isOnline,
      'hideOnlineStatus': hideOnlineStatus,
      'radarMode': radarMode,
      'accountStatus': accountStatus,
      'reportCount': reportCount,
      if (bannedUntil != null) 'bannedUntil': Timestamp.fromDate(bannedUntil!),
      if (heightCm != null) 'heightCm': heightCm,
      if (weightKg != null) 'weightKg': weightKg,
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
    bool? isOnline,
    bool? hideOnlineStatus,
    String? radarMode,
    String? accountStatus,
    int? reportCount,
    DateTime? bannedUntil,
    double? heightCm,
    double? weightKg,
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
      discoveryRadius: (discoveryRadius ?? this.discoveryRadius).clamp(0.05, 0.2),
      profileImageBase64:
      profileImageBase64 ?? this.profileImageBase64,
      isOnline: isOnline ?? this.isOnline,
      hideOnlineStatus: hideOnlineStatus ?? this.hideOnlineStatus,
      radarMode: radarMode ?? this.radarMode,
      accountStatus: accountStatus ?? this.accountStatus,
      reportCount: reportCount ?? this.reportCount,
      bannedUntil: bannedUntil ?? this.bannedUntil,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
