import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current GPS location and automatically sync it to Firestore for other users to detect on Radar
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await handleLocationPermission();
    if (!hasPermission) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Sync GPS location to Firestore user document immediately
      await _syncLocationToFirestore(position);

      return position;
    } catch (e) {
      debugPrint("Error getting current location: $e");
      return null;
    }
  }

  /// Get continuous GPS stream and automatically sync updates to Firestore
  Stream<Position> getLocationStream() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Sync to Firestore every 10 meters
    );

    return Geolocator.getPositionStream(locationSettings: settings).map((position) {
      _syncLocationToFirestore(position);
      return position;
    });
  }

  /// Helper to write user's current GPS coordinates to Firestore users/{uid}
  Future<void> _syncLocationToFirestore(Position position) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      await _firestore.collection('users').doc(uid).set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error syncing location to Firestore for $uid: $e");
    }
  }
}
