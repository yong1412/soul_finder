import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/match_service.dart';

class MatchMeetingMap extends StatelessWidget {
  const MatchMeetingMap({
    super.key,
    required this.pair,
    required this.otherUserName,
    this.height = 300,
  });

  final MatchPairData pair;
  final String otherUserName;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (!_hasMapCoordinates) {
      return Container(
        height: 180,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF080E20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 42,
              color: Colors.white38,
            ),
            SizedBox(height: 12),
            Text(
              'Map unavailable',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Both matched users must allow location before a fair '
                  'midpoint can be shown.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ],
        ),
      );
    }

    final currentPoint = LatLng(
      pair.currentUser.latitude!,
      pair.currentUser.longitude!,
    );
    final otherPoint = LatLng(
      pair.otherUser.latitude!,
      pair.otherUser.longitude!,
    );
    final midpoint = LatLng(
      pair.midpointLatitude!,
      pair.midpointLongitude!,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: height,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: midpoint,
                initialZoom: _initialZoom(pair.distanceKm),
                minZoom: 3,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                  InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.scrollWheelZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'tarc.edu.my.soulFinder',
                  maxNativeZoom: 19,
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: otherPoint,
                      radius: 500,
                      useRadiusInMeter: true,
                      color: const Color(0x33E879F9),
                      borderColor: const Color(0xFFE879F9),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [currentPoint, midpoint],
                      color: const Color(0xFF38BDF8),
                      strokeWidth: 4,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentPoint,
                      width: 78,
                      height: 62,
                      child: const _MapMarker(
                        label: 'You',
                        icon: Icons.person_pin_circle,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                    Marker(
                      point: midpoint,
                      width: 100,
                      height: 66,
                      child: const _MapMarker(
                        label: 'Fair midpoint',
                        icon: Icons.favorite,
                        color: Color(0xFFFF5C8A),
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(
              Icons.privacy_tip_outlined,
              size: 18,
              color: Color(0xFFE879F9),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$otherUserName is shown only as an approximate 500 m area.',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool get _hasMapCoordinates {
    return pair.currentUser.hasLocation &&
        pair.otherUser.hasLocation &&
        pair.midpointLatitude != null &&
        pair.midpointLongitude != null;
  }

  double _initialZoom(double? distanceKm) {
    if (distanceKm == null) return 13;
    if (distanceKm <= 1) return 15;
    if (distanceKm <= 3) return 14;
    if (distanceKm <= 8) return 13;
    if (distanceKm <= 20) return 11.5;
    return 10;
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          color: const Color(0xDD080E20),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
