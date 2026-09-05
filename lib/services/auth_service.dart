import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users {
    return _firestore.collection('users');
  }

  Future<UserProfile?> restoreSession() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return null;
    }

    return _getUserByUid(firebaseUser.uid);
  }

  Future<UserProfile> register({
    required String email,
    required String password,
    required String name,
    required int age,
    required String gender,
    required String lookingFor,
    required List<String> interests,
    double? heightCm,
    double? weightKg,
  }) async {
    try {
      final normalizedEmail =
      email.trim().toLowerCase();

      final credential =
      await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const AuthException(
          'Unable to create account.',
        );
      }

      final user = UserProfile(
        uid: firebaseUser.uid,
        email: normalizedEmail,
        name: name.trim(),
        age: age,
        gender: gender,
        bio: 'Looking for meaningful connections',
        interests: interests,
        lookingFor: lookingFor,
        discoveryRadius: 0.2,
        profileImageBase64: '',
        heightCm: heightCm,
        weightKg: weightKg,
      );

      await _users.doc(firebaseUser.uid).set({
        'uid': firebaseUser.uid,
        'email': normalizedEmail,
        'name': name.trim(),
        'age': age,
        'gender': gender,
        'bio': 'Looking for meaningful connections',
        'interests': interests,
        'lookingFor': lookingFor,
        'discoveryRadius': 0.2,
        'profileImageBase64': '',
        if (heightCm != null) 'heightCm': heightCm,
        if (weightKg != null) 'weightKg': weightKg,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return user;
    } on FirebaseAuthException catch (error) {
      throw AuthException(
        _firebaseErrorMessage(error),
      );
    } on FirebaseException catch (error) {
      throw AuthException(
        error.message ??
            'Unable to save user profile.',
      );
    }
  }

  Future<UserProfile> login(
      String email,
      String password,
      ) async {
    try {
      final normalizedEmail =
      email.trim().toLowerCase();

      final credential =
      await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw const AuthException(
          'Unable to sign in.',
        );
      }

      final profile = await _getUserByUid(
        firebaseUser.uid,
      );

      if (profile == null) {
        throw const AuthException(
          'User profile was not found.',
        );
      }

      return profile;
    } on FirebaseAuthException catch (error) {
      throw AuthException(
        _firebaseErrorMessage(error),
      );
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<UserProfile?> getUser(
      String email,
      ) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser != null) {
      return _getUserByUid(
        firebaseUser.uid,
      );
    }

    if (email.trim().isEmpty) {
      return null;
    }

    final result = await _users
        .where(
      'email',
      isEqualTo:
      email.trim().toLowerCase(),
    )
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      return null;
    }

    return UserProfile.fromJson(
      result.docs.first.data(),
    );
  }

  Future<UserProfile?> _getUserByUid(
      String uid,
      ) async {
    final snapshot =
    await _users.doc(uid).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return UserProfile.fromJson(data);
  }

  Future<UserProfile> updateUser(
      UserProfile updatedUser,
      ) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const AuthException(
        'You are not signed in.',
      );
    }

    try {
      final updatedProfile =
      updatedUser.copyWith(
        uid: firebaseUser.uid,
        email: firebaseUser.email ??
            updatedUser.email,
      );

      await _users
          .doc(firebaseUser.uid)
          .set({
        'uid': updatedProfile.uid,
        'email': updatedProfile.email,
        'name': updatedProfile.name,
        'age': updatedProfile.age,
        'gender': updatedProfile.gender,
        'bio': updatedProfile.bio,
        'interests': updatedProfile.interests,
        'lookingFor': updatedProfile.lookingFor,
        'discoveryRadius': updatedProfile.discoveryRadius,
        'profileImageBase64': updatedProfile.profileImageBase64,
        'isOnline': updatedProfile.isOnline,
        'hideOnlineStatus': updatedProfile.hideOnlineStatus,
        'heightCm': updatedProfile.heightCm,
        'weightKg': updatedProfile.weightKg,
        'isPrivateProfile': updatedProfile.isPrivateProfile,
        'hideBio': updatedProfile.hideBio,
        'hideStats': updatedProfile.hideStats,
        'hideInterests': updatedProfile.hideInterests,
        'hideAgeGender': updatedProfile.hideAgeGender,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return updatedProfile;
    } on FirebaseException catch (error) {
      throw AuthException(
        error.message ??
            'Unable to update profile.',
      );
    }
  }

  Future<UserProfile> updateProfilePrivacy({
    required bool isPrivateProfile,
    required bool hideBio,
    required bool hideStats,
    required bool hideInterests,
    required bool hideAgeGender,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw const AuthException('You are not signed in.');
    }

    try {
      await _users.doc(firebaseUser.uid).set({
        'isPrivateProfile': isPrivateProfile,
        'hideBio': hideBio,
        'hideStats': hideStats,
        'hideInterests': hideInterests,
        'hideAgeGender': hideAgeGender,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final doc = await _users.doc(firebaseUser.uid).get();
      return UserProfile.fromJson(doc.data()!);
    } on FirebaseException catch (error) {
      throw AuthException(error.message ?? 'Unable to update profile privacy settings.');
    }
  }

  Future<UserProfile> setHideOnlineStatus(bool hide) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw const AuthException('You are not signed in.');
    }

    try {
      await _users.doc(firebaseUser.uid).set({
        'hideOnlineStatus': hide,
      }, SetOptions(merge: true));

      final doc = await _users.doc(firebaseUser.uid).get();
      return UserProfile.fromJson(doc.data()!);
    } on FirebaseException catch (error) {
      throw AuthException(error.message ?? 'Unable to update privacy status.');
    }
  }

  Future<UserProfile> setRadarMode(String modeStr) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw const AuthException('You are not signed in.');
    }

    try {
      await _users.doc(firebaseUser.uid).set({
        'radarMode': modeStr,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final doc = await _users.doc(firebaseUser.uid).get();
      return UserProfile.fromJson(doc.data()!);
    } on FirebaseException catch (error) {
      throw AuthException(error.message ?? 'Unable to update radar mode.');
    }
  }

  Future<void> updateOnlineStatusDirect(String uid, bool isOnline) async {
    try {
      await _users.doc(uid).set({
        'isOnline': isOnline,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating online status direct for $uid: $e");
    }
  }

  Future<void> changePassword(
      String newPassword,
      ) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const AuthException(
        'You are not signed in.',
      );
    }

    try {
      await firebaseUser.updatePassword(
        newPassword,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(
        _firebaseErrorMessage(error),
      );
    }
  }

  Future<void> deleteUser(
      String email,
      ) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const AuthException(
        'You are not signed in.',
      );
    }

    try {
      final uid = firebaseUser.uid;

      await _users.doc(uid).delete();

      await firebaseUser.delete();
    } on FirebaseAuthException catch (error) {
      throw AuthException(
        _firebaseErrorMessage(error),
      );
    } on FirebaseException catch (error) {
      throw AuthException(
        error.message ??
            'Unable to delete account.',
      );
    }
  }

  String _firebaseErrorMessage(
      FirebaseAuthException error,
      ) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';

      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'weak-password':
        return 'The password is too weak.';

      case 'user-not-found':
        return 'No account was found with this email.';

      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';

      case 'requires-recent-login':
        return 'For security reasons, please sign in again before changing your password or deleting your account.';

      default:
        return error.message ??
            'Authentication failed. Please try again.';
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}