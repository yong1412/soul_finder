import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class MapRadarView extends StatefulWidget {
  const MapRadarView({super.key});

  @override
  State<MapRadarView> createState() => _MapRadarViewState();
}

class _MapRadarViewState extends State<MapRadarView> with SingleTickerProviderStateMixin {
  // Keeps track of the selected mode. Default is 'friends'
  Set<String> _scanMode = {'friends'};
  
  late AnimationController _animationController;
  final List<RadarDot> _dots = [];
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Generate some initial dots
    _generateDots();
    
    // Periodically refresh dots to simulate moving people
    _dotTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _generateDots();
        });
      }
    });
  }

  void _generateDots() {
    _dots.clear();
    final random = math.Random();
    // Generate 3-7 random dots
    int count = 3 + random.nextInt(5);
    for (int i = 0; i < count; i++) {
      _dots.add(RadarDot(
        // Distance from center (0.0 to 1.0)
        distance: 0.2 + random.nextDouble() * 0.7,
        // Angle in radians
        angle: random.nextDouble() * 2 * math.pi,
        // Random size
        size: 3.0 + random.nextDouble() * 4.0,
      ));
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Top Toggle Button (Friend vs Couple)
        Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 20.0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'friends',
                label: Text('Find Friends'),
                icon: Icon(Icons.people_alt),
              ),
              ButtonSegment<String>(
                value: 'couple',
                label: Text('Find Couple'),
                icon: Icon(Icons.favorite),
              ),
            ],
            selected: _scanMode,
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _scanMode = newSelection;
                _generateDots(); // Refresh dots when mode changes
              });
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: theme.surface,
              selectedBackgroundColor: _scanMode.first == 'couple'
                  ? theme.secondary.withOpacity(0.3) // Pinkish for couples
                  : theme.primary.withOpacity(0.3),  // Blueish for friends
              foregroundColor: Colors.white70,
              selectedForegroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),

        // Radar takes up the remaining screen space and centers itself
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // The animated Radar background
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(300, 300),
                          painter: RadarPainter(
                            progress: _animationController.value,
                            color: _scanMode.first == 'couple' ? theme.secondary : theme.primary,
                            dots: _dots,
                          ),
                        );
                      },
                    ),
                    
                    // Inner core
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            _scanMode.first == 'couple' ? theme.secondary : theme.primary,
                            _scanMode.first == 'couple' ? theme.secondary.withOpacity(0.6) : theme.primary.withOpacity(0.6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_scanMode.first == 'couple' ? theme.secondary : theme.primary).withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        // Change icon in the middle based on mode
                        _scanMode.first == 'couple' ? Icons.favorite : Icons.person,
                        size: 35,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Text(
                  // Dynamically update the scanning text based on selection
                  _scanMode.first == 'couple'
                      ? "Scanning for potential matches..."
                      : "Scanning for new friends...",
                  style: const TextStyle(fontSize: 16, color: Colors.white70, letterSpacing: 1.1),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.surface,
                    foregroundColor: _scanMode.first == 'couple' ? theme.secondary : theme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    setState(() {
                      _generateDots();
                    });
                  },
                  child: const Text("Pulse Location"),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RadarDot {
  final double distance;
  final double angle;
  final double size;

  RadarDot({
    required this.distance,
    required this.angle,
    required this.size,
  });
}

class RadarPainter extends CustomPainter {
  final double progress;
  final Color color;
  final List<RadarDot> dots;

  RadarPainter({
    required this.progress,
    required this.color,
    required this.dots,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final paint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.7, paint);
    canvas.drawCircle(center, radius * 0.4, paint);

    // Draw axis lines
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), paint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), paint);

    // Draw rotating sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          color.withOpacity(0.0),
          color.withOpacity(0.5),
        ],
        stops: const [0.75, 1.0],
        transform: GradientRotation(progress * 2 * math.pi - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);
    
    // Draw the "front" line of the sweep
    final linePaint = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    final angle = progress * 2 * math.pi - math.pi / 2;
    canvas.drawLine(
      center,
      Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle)),
      linePaint,
    );

    // Draw dots
    for (var dot in dots) {
      final dotAngle = dot.angle;
      // Calculate current sweep angle (0 to 2pi)
      double currentSweepAngle = (progress * 2 * math.pi) % (2 * math.pi);
      // Normalize dot angle to 0 to 2pi
      double normalizedDotAngle = (dotAngle + math.pi / 2) % (2 * math.pi);
      
      // Calculate how close the sweep is to the dot
      double angleDiff = (currentSweepAngle - normalizedDotAngle);
      if (angleDiff < 0) angleDiff += 2 * math.pi;
      
      // Only show dots that have been "passed" by the sweep recently
      if (angleDiff < math.pi / 2) {
        final opacity = 1.0 - (angleDiff / (math.pi / 2));
        final dotPaint = Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.fill;
        
        final dotOffset = Offset(
          center.dx + radius * dot.distance * math.cos(dotAngle),
          center.dy + radius * dot.distance * math.sin(dotAngle),
        );
        
        canvas.drawCircle(dotOffset, dot.size, dotPaint);
        
        // Draw a small glow around the dot
        canvas.drawCircle(
          dotOffset, 
          dot.size * 2, 
          Paint()..color = color.withOpacity(opacity * 0.3)..style = PaintingStyle.fill
        );
      }
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.dots != dots;
  }
}

