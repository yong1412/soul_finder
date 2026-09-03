import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../models/user_profile.dart';

class MatchCandidate {
  const MatchCandidate({
    required this.profile,
    required this.compatibilityScore,
    required this.commonInterests,
    this.distanceKm,
  });

  final UserProfile profile;
  final double compatibilityScore;
  final List<String> commonInterests;
  final double? distanceKm;
}

class MatchPairData {
  const MatchPairData({
    required this.currentUser,
    required this.otherUser,
    this.distanceKm,
    this.midpointLatitude,
    this.midpointLongitude,
  });

  final UserProfile currentUser;
  final UserProfile otherUser;
  final double? distanceKm;
  final double? midpointLatitude;
  final double? midpointLongitude;
}

class LikeNotification {
  const LikeNotification({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromProfileImageBase64,
    required this.toUid,
    required this.isMatched,
    required this.isRead,
    this.createdAt,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String fromProfileImageBase64;
  final String toUid;
  final bool isMatched;
  final bool isRead;
  final Timestamp? createdAt;

  factory LikeNotification.fromDocument(
      QueryDocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();
    return LikeNotification(
      id: document.id,
      fromUid: data['fromUid'] as String? ?? '',
      fromName: data['fromName'] as String? ?? 'A user',
      fromProfileImageBase64:
      data['fromProfileImageBase64'] as String? ?? '',
      toUid: data['toUid'] as String? ?? '',
      isMatched: data['matched'] as bool? ?? false,
      isRead: data['read'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  LikeNotification copyWith({
    String? fromName,
    String? fromProfileImageBase64,
  }) {
    return LikeNotification(
      id: id,
      fromUid: fromUid,
      fromName: fromName ?? this.fromName,
      fromProfileImageBase64:
      fromProfileImageBase64 ?? this.fromProfileImageBase64,
      toUid: toUid,
      isMatched: isMatched,
      isRead: isRead,
      createdAt: createdAt,
    );
  }
}

class MatchService {
  MatchService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _likes =>
      _firestore.collection('likes');

  CollectionReference<Map<String, dynamic>> get _matches =>
      _firestore.collection('matches');

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> _notificationItems(
      String userUid,
      ) {
    return _firestore
        .collection('notifications')
        .doc(userUid)
        .collection('items');
  }

  String _requireCurrentUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User is not signed in.');
    }
    return uid;
  }

  String _matchId(String firstUid, String secondUid) {
    final ids = [firstUid, secondUid]..sort();
    return ids.join('_');
  }

  Stream<List<MatchCandidate>> watchCandidates() {
    final currentUid = _requireCurrentUid();

    return _users.snapshots().map((snapshot) {
      final profiles = snapshot.docs
          .map((doc) => UserProfile.fromJson(doc.data()))
          .where((profile) => profile.uid.isNotEmpty)
          .toList();

      UserProfile? currentProfile;
      for (final profile in profiles) {
        if (profile.uid == currentUid) {
          currentProfile = profile;
          break;
        }
      }

      if (currentProfile == null) {
        return <MatchCandidate>[];
      }

      final candidates = <MatchCandidate>[];
      for (final other in profiles) {
        if (other.uid == currentUid) {
          continue;
        }

        // Radar discovery radius is 50m - 200m (0.05 km - 0.2 km)
        final effectiveRadiusKm = currentProfile.discoveryRadius.clamp(0.05, 0.2);

        final distance = _distanceBetween(currentProfile, other);

        // Filter out users who do not have valid location OR are outside the radar range (50m - 200m)
        if (distance == null || distance > effectiveRadiusKm) {
          continue;
        }

        final commonInterests = _commonInterests(
          currentProfile.interests,
          other.interests,
        );

        candidates.add(
          MatchCandidate(
            profile: other,
            distanceKm: distance,
            commonInterests: commonInterests,
            compatibilityScore: _compatibilityScore(
              currentProfile,
              other,
              distance,
              commonInterests.length,
            ),
          ),
        );
      }

      candidates.sort((first, second) {
        final scoreComparison = second.compatibilityScore
            .compareTo(first.compatibilityScore);
        if (scoreComparison != 0) {
          return scoreComparison;
        }
        return (first.distanceKm ?? double.infinity)
            .compareTo(second.distanceKm ?? double.infinity);
      });

      return candidates;
    });
  }

  Stream<bool> watchLikeStatus(String targetUid) {
    final currentUid = _requireCurrentUid();
    return _likes
        .doc('${currentUid}_$targetUid')
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  Stream<Set<String>> watchLikedUserIds() {
    final currentUid = _requireCurrentUid();
    return _likes
        .where('fromUid', isEqualTo: currentUid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data()['toUid'] as String? ?? '')
          .where((uid) => uid.isNotEmpty)
          .toSet();
    });
  }

  Stream<bool> watchMatchStatus(String targetUid) {
    final currentUid = _requireCurrentUid();
    return _matches
        .doc(_matchId(currentUid, targetUid))
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        return false;
      }
      return snapshot.data()?['status'] == 'active';
    });
  }

  Future<bool> likeUser(String targetUid) async {
    final currentUid = _requireCurrentUid();
    if (currentUid == targetUid) {
      throw Exception('You cannot like your own profile.');
    }

    final ownLike = _likes.doc('${currentUid}_$targetUid');
    final reverseLike = _likes.doc('${targetUid}_$currentUid');
    final matchReference =
    _matches.doc(_matchId(currentUid, targetUid));
    final chatReference =
    _chats.doc(_matchId(currentUid, targetUid));
    final sentNotification = _notificationItems(targetUid)
        .doc('${currentUid}_$targetUid');
    final receivedNotification = _notificationItems(currentUid)
        .doc('${targetUid}_$currentUid');
    final currentProfileReference = _users.doc(currentUid);
    final targetProfileReference = _users.doc(targetUid);

    return _firestore.runTransaction<bool>((transaction) async {
      final ownSnapshot = await transaction.get(ownLike);
      final reverseSnapshot = await transaction.get(reverseLike);
      final currentProfileSnapshot =
      await transaction.get(currentProfileReference);
      final targetProfileSnapshot =
      await transaction.get(targetProfileReference);

      final currentName =
          currentProfileSnapshot.data()?['name'] as String? ?? 'A user';
      final targetName =
          targetProfileSnapshot.data()?['name'] as String? ?? 'A user';

      if (!ownSnapshot.exists) {
        transaction.set(ownLike, {
          'fromUid': currentUid,
          'toUid': targetUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(sentNotification, {
        'fromUid': currentUid,
        'fromName': currentName,
        'toUid': targetUid,
        'type': reverseSnapshot.exists ? 'match' : 'like',
        'matched': reverseSnapshot.exists,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (reverseSnapshot.exists) {
        final users = [currentUid, targetUid]..sort();
        transaction.set(matchReference, {
          'users': users,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // A mutual match gets exactly one shared chat document. The sorted
        // match ID prevents duplicate chats when either user completes the
        // mutual match.
        transaction.set(chatReference, {
          'chatId': chatReference.id,
          'participants': users,
          'lastMessage': 'You matched. Start a conversation.',
          'lastMessageType': 'system',
          'lastSenderUid': '',
          'lastMessageAt': FieldValue.serverTimestamp(),
          'unreadCounts': {
            currentUid: 0,
            targetUid: 0,
          },
          'lastReadAt': {},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update the earlier notification received by the first liker.
        transaction.set(receivedNotification, {
          'fromUid': targetUid,
          'fromName': targetName,
          'toUid': currentUid,
          'type': 'match',
          'matched': true,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return true;
      }

      return false;
    });
  }

  Stream<List<LikeNotification>> watchMyLikeNotifications() {
    final currentUid = _requireCurrentUid();
    return _notificationItems(currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final notifications = snapshot.docs
          .map(LikeNotification.fromDocument)
          .where((notification) => notification.fromUid.isNotEmpty)
          .toList();

      return Future.wait(
        notifications.map((notification) async {
          final profileSnapshot =
          await _users.doc(notification.fromUid).get();
          final profileData = profileSnapshot.data();

          return notification.copyWith(
            fromName:
            profileData?['name'] as String? ?? notification.fromName,
            fromProfileImageBase64:
            profileData?['profileImageBase64'] as String? ?? '',
          );
        }),
      );
    });
  }

  Stream<int> watchUnreadNotificationCount() {
    return watchMyLikeNotifications().map(
          (notifications) =>
      notifications.where((notification) => !notification.isRead).length,
    );
  }

  Future<void> markNotificationRead(String notificationId) async {
    final currentUid = _requireCurrentUid();
    await _notificationItems(currentUid).doc(notificationId).update({
      'read': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeLike(String targetUid) async {
    final currentUid = _requireCurrentUid();
    final matched = await _matches
        .doc(_matchId(currentUid, targetUid))
        .get();

    if (matched.exists && matched.data()?['status'] == 'active') {
      throw Exception('An active match cannot be removed here.');
    }

    await _likes.doc('${currentUid}_$targetUid').delete();
  }

  Stream<MatchPairData?> watchPair(String targetUid) {
    final currentUid = _requireCurrentUid();

    return _users.snapshots().map((snapshot) {
      UserProfile? current;
      UserProfile? other;

      for (final document in snapshot.docs) {
        final profile = UserProfile.fromJson(document.data());
        if (profile.uid == currentUid) {
          current = profile;
        } else if (profile.uid == targetUid) {
          other = profile;
        }
      }

      if (current == null || other == null) {
        return null;
      }

      return MatchPairData(
        currentUser: current,
        otherUser: other,
        distanceKm: _distanceBetween(current, other),
        midpointLatitude:
        current.hasLocation && other.hasLocation
            ? (current.latitude! + other.latitude!) / 2
            : null,
        midpointLongitude:
        current.hasLocation && other.hasLocation
            ? (current.longitude! + other.longitude!) / 2
            : null,
      );
    });
  }

  Future<MatchCandidate?> getCandidateForUid(String targetUid) async {
    final currentUid = _requireCurrentUid();
    final currentDoc = await _users.doc(currentUid).get();
    final targetDoc = await _users.doc(targetUid).get();

    if (!currentDoc.exists || !targetDoc.exists || targetDoc.data() == null) {
      return null;
    }

    final currentProfile = UserProfile.fromJson(currentDoc.data()!);
    final targetProfile = UserProfile.fromJson(targetDoc.data()!);

    final distance = _distanceBetween(currentProfile, targetProfile);
    final commonInterests = _commonInterests(
      currentProfile.interests,
      targetProfile.interests,
    );

    return MatchCandidate(
      profile: targetProfile,
      distanceKm: distance,
      commonInterests: commonInterests,
      compatibilityScore: _compatibilityScore(
        currentProfile,
        targetProfile,
        distance,
        commonInterests.length,
      ),
    );
  }

  double? _distanceBetween(UserProfile first, UserProfile second) {
    if (!first.hasLocation || !second.hasLocation) {
      return null;
    }
    return Geolocator.distanceBetween(
      first.latitude!,
      first.longitude!,
      second.latitude!,
      second.longitude!,
    ) /
        1000;
  }

  List<String> _commonInterests(
      List<String> first,
      List<String> second,
      ) {
    final secondSet = second.map((item) => item.toLowerCase()).toSet();
    return first
        .where((item) => secondSet.contains(item.toLowerCase()))
        .toList();
  }

  double _compatibilityScore(
      UserProfile current,
      UserProfile other,
      double? distance,
      int commonInterestCount,
      ) {
    final maximumInterestCount =
    max(current.interests.length, other.interests.length);
    final interestScore = maximumInterestCount == 0
        ? 0.0
        : commonInterestCount / maximumInterestCount;

    final radius = current.discoveryRadius.clamp(0.05, 0.2);
    final distanceScore = distance == null
        ? 0.0
        : 1 - min(distance / radius, 1.0);

    final purposeScore = current.lookingFor == 'Both' ||
        other.lookingFor == 'Both' ||
        current.lookingFor == other.lookingFor
        ? 1.0
        : 0.0;

    return (interestScore * 0.50 +
        distanceScore * 0.30 +
        purposeScore * 0.20) *
        100;
  }
}
