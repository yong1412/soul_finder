import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<Position>? _positionSubscription;

  Future<void> start() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Please sign in before enabling location.');
    }

    final locationEnabled =
    await Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) {
      throw Exception('Please enable location services.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission was not granted.');
    }

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );

    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) async {
      // Coarse location protects privacy while remaining useful for distance.
      final latitude = _roundCoordinate(position.latitude);
      final longitude = _roundCoordinate(position.longitude);

      await _firestore.collection('users').doc(user.uid).set({
        'latitude': latitude,
        'longitude': longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  double _roundCoordinate(double value) {
    return (value * 1000).roundToDouble() / 1000;
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
