import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/radar/radar_models.dart';

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

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw concentric circles
    canvas.drawCircle(center, radius, ringPaint);
    canvas.drawCircle(center, radius * 0.7, ringPaint);
    canvas.drawCircle(center, radius * 0.4, ringPaint);

    // Draw axis lines
    final axisPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), axisPaint);

    // Draw rotating sweep
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.55),
        ],
        stops: const [0.70, 1.0],
        transform: GradientRotation(progress * 2 * math.pi - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);
    
    // Draw the front line of the sweep
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.85)
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
      double currentSweepAngle = (progress * 2 * math.pi) % (2 * math.pi);
      double normalizedDotAngle = (dotAngle + math.pi / 2) % (2 * math.pi);
      
      double angleDiff = (currentSweepAngle - normalizedDotAngle);
      if (angleDiff < 0) angleDiff += 2 * math.pi;
      
      if (angleDiff < math.pi / 2) {
        final opacity = (1.0 - (angleDiff / (math.pi / 2))).clamp(0.0, 1.0);
        final dotPaint = Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.fill;
        
        final dotOffset = Offset(
          center.dx + radius * dot.distance * math.cos(dotAngle),
          center.dy + radius * dot.distance * math.sin(dotAngle),
        );
        
        canvas.drawCircle(dotOffset, dot.size, dotPaint);
        canvas.drawCircle(
          dotOffset, 
          dot.size * 2, 
          Paint()..color = color.withValues(alpha: opacity * 0.35)..style = PaintingStyle.fill
        );
      }
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color || oldDelegate.dots != dots;
  }
}
