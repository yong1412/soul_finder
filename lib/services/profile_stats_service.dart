import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class ProfileViewerEntry {
  const ProfileViewerEntry({
    required this.profile,
    this.viewedAt,
  });

  final UserProfile profile;
  final DateTime? viewedAt;
}

class ProfileStatsService {
  ProfileStatsService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String _requireCurrentUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User is not signed in.');
    }
    return uid;
  }

  Stream<int> watchMatchCount() {
    final currentUid = _requireCurrentUid();

    return _firestore
        .collection('matches')
        .where('users', arrayContains: currentUid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .where((document) => document.data()['status'] == 'active')
          .length,
    );
  }

  Stream<int> watchProfileViewCount() {
    final currentUid = _requireCurrentUid();

    return _firestore
        .collection('profileViews')
        .doc(currentUid)
        .collection('viewers')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<ProfileViewerEntry>> watchProfileViewers() {
    final currentUid = _requireCurrentUid();

    return _firestore
        .collection('profileViews')
        .doc(currentUid)
        .collection('viewers')
        .orderBy('viewedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final viewers = <ProfileViewerEntry>[];

      for (final viewDocument in snapshot.docs) {
        final viewData = viewDocument.data();
        final viewerUid =
            viewData['viewerUid'] as String? ?? viewDocument.id;

        if (viewerUid.isEmpty || viewerUid == currentUid) {
          continue;
        }

        final userSnapshot = await _firestore
            .collection('users')
            .doc(viewerUid)
            .get();
        final userData = userSnapshot.data();

        if (!userSnapshot.exists || userData == null) {
          continue;
        }

        final safeUserData = Map<String, dynamic>.from(userData);
        final storedUid = safeUserData['uid'];
        safeUserData['uid'] = storedUid is String && storedUid.isNotEmpty
            ? storedUid
            : viewerUid;

        final viewedAt = viewData['viewedAt'] as Timestamp?;

        viewers.add(
          ProfileViewerEntry(
            profile: UserProfile.fromJson(safeUserData),
            viewedAt: viewedAt?.toDate(),
          ),
        );
      }

      return viewers;
    });
  }

  Future<void> recordProfileView(String profileUid) async {
    final currentUid = _requireCurrentUid();

    if (profileUid.isEmpty || profileUid == currentUid) {
      return;
    }

    // One deterministic document per viewer gives a unique-view count.
    // Opening the same profile again updates the time but does not increase
    // the displayed number.
    await _firestore
        .collection('profileViews')
        .doc(profileUid)
        .collection('viewers')
        .doc(currentUid)
        .set(
      {
        'viewerUid': currentUid,
        'profileUid': profileUid,
        'viewedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
