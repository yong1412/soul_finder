import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/meeting_venue.dart';
import '../services/match_service.dart';

class MatchMeetingMap extends StatefulWidget {
  const MatchMeetingMap({
    super.key,
    required this.pair,
    required this.otherUserName,
    this.suggestedVenues = const [],
    this.onVenueSelected,
    this.height = 300,
  });

  final MatchPairData pair;
  final String otherUserName;
  final List<MeetingVenue> suggestedVenues;
  final Function(MeetingVenue)? onVenueSelected;
  final double height;

  @override
  State<MatchMeetingMap> createState() => _MatchMeetingMapState();
}

class _MatchMeetingMapState extends State<MatchMeetingMap>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasMapCoordinates) {
      return _buildMapUnavailable();
    }

    final currentPoint = LatLng(
      widget.pair.currentUser.latitude!,
      widget.pair.currentUser.longitude!,
    );
    final otherPoint = LatLng(
      widget.pair.otherUser.latitude!,
      widget.pair.otherUser.longitude!,
    );
    final midpoint = LatLng(
      widget.pair.midpointLatitude!,
      widget.pair.midpointLongitude!,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: midpoint,
                    initialZoom: _initialZoom(widget.pair.distanceKm),
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
                    // Pulsing Area for the other user
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: otherPoint,
                          radius: 500,
                          useRadiusInMeter: true,
                          color: const Color(0x22F43F5E),
                          borderColor: const Color(0xFFF43F5E).withValues(alpha: 0.4),
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                    // Connection line to midpoint
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [currentPoint, midpoint],
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                          strokeWidth: 3,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // Suggested Venues (Real discovery markers)
                        ...widget.suggestedVenues.map((venue) => Marker(
                              point: LatLng(venue.latitude, venue.longitude),
                              width: 44,
                              height: 44,
                              child: GestureDetector(
                                onTap: () => widget.onVenueSelected?.call(venue),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF22C55E),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                      )
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.restaurant,
                                    color: Color(0xFF22C55E),
                                    size: 20,
                                  ),
                                ),
                              ),
                            )),

                        // Radar Sweep at Midpoint
                        Marker(
                          point: midpoint,
                          width: 200,
                          height: 200,
                          alignment: Alignment.center,
                          child: AnimatedBuilder(
                            animation: _radarController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _MeetingRadarPainter(
                                  progress: _radarController.value,
                                  color: const Color(0xFF3B82F6),
                                ),
                              );
                            },
                          ),
                        ),
                        // User Marker
                        Marker(
                          point: currentPoint,
                          width: 60,
                          height: 60,
                          child: const _MapMarker(
                            label: 'You',
                            icon: Icons.person_pin_circle,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                        // Midpoint Target
                        Marker(
                          point: midpoint,
                          width: 80,
                          height: 80,
                          child: const _MapMarker(
                            label: 'Best Spot',
                            icon: Icons.favorite,
                            color: Color(0xFFF43F5E),
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
                // Overlay Gradient to make map fit the dark theme better
                IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF0F172A).withValues(alpha: 0.3),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildPrivacyNote(),
      ],
    );
  }

  Widget _buildMapUnavailable() {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined, size: 42, color: Colors.white38),
          SizedBox(height: 12),
          Text(
            'Radar Sync Unavailable',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Both users must enable location to calculate the fair meeting radar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNote() {
    return Row(
      children: [
        const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFF43F5E)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${widget.otherUserName}\'s exact location is hidden. Radar scans the 500m fuzzy area.',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ),
      ],
    );
  }

  bool get _hasMapCoordinates {
    return widget.pair.currentUser.hasLocation &&
        widget.pair.otherUser.hasLocation &&
        widget.pair.midpointLatitude != null &&
        widget.pair.midpointLongitude != null;
  }

  double _initialZoom(double? distanceKm) {
    if (distanceKm == null) return 13;
    if (distanceKm <= 1) return 15;
    if (distanceKm <= 3) return 14;
    if (distanceKm <= 8) return 12.5;
    if (distanceKm <= 20) return 11;
    return 10;
  }
}

class _MeetingRadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _MeetingRadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Conic rings
    canvas.drawCircle(center, radius * 0.4, ringPaint);
    canvas.drawCircle(center, radius * 0.7, ringPaint);
    canvas.drawCircle(center, radius, ringPaint);

    // Rotating Sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.4),
        ],
        stops: const [0.7, 1.0],
        transform: GradientRotation(progress * 2 * math.pi - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    // Leading line
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    final angle = progress * 2 * math.pi - math.pi / 2;
    canvas.drawLine(
      center,
      Offset(center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle)),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(_MeetingRadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
