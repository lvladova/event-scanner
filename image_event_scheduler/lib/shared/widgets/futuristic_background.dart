import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;

class FuturisticBackgroundPainter extends CustomPainter {
  final Color baseColor;
  final Color gridColor;

  FuturisticBackgroundPainter({
    this.baseColor = const Color(0xFF0A0A1A),
    this.gridColor = const Color(0xFF1A1A2E),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Base background
    final backgroundPaint = Paint()..color = baseColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    // Vertical grid lines
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Horizontal grid lines
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Glowing spherical effect
    final center = Offset(size.width * 0.5, size.height * 0.3);
    final spherePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00B4FF).withOpacity(0.3),
          const Color(0xFF00B4FF).withOpacity(0.1),
          Colors.transparent
        ],
        stops: const [0.1, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 200));

    canvas.drawCircle(center, 200, spherePaint);

    // Add some subtle particle effects
    final random = Random();
    final particlePaint = Paint()
      ..color = const Color(0xFF00B4FF).withOpacity(0.2)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2;

      canvas.drawCircle(Offset(x, y), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Wrapper widget to easily use the custom painter
class FuturisticBackground extends StatelessWidget {
  final Widget child;

  const FuturisticBackground({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FuturisticBackgroundPainter(),
      child: child,
    );
  }
}