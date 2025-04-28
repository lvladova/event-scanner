import 'package:flutter/material.dart';
import 'dart:math';

class FuturisticAnimations {
  // Holographic Scanning Animation
  static Widget holographicScanner({
    required Widget child,
    required bool isScanning,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 2),
      tween: Tween(begin: 0, end: isScanning ? 1 : 0),
      builder: (context, value, child) {
        return Stack(
          children: [
            child!,
            if (isScanning)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: HolographicScanPainter(
                      animationValue: value,
                      color: Colors.cyan.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: child,
    );
  }

  // Pulsing Sphere Widget
  static Widget pulsingSphere({
    Color color = const Color(0xFF00B4FF),
    double size = 200,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 3),
      tween: Tween(begin: 0.8, end: 1.2),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.8),
                  color.withOpacity(0.3),
                  color.withOpacity(0.1),
                ],
                stops: const [0.2, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 50,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Futuristic Loading Indicator
  static Widget futuristicLoader({
    Color color = const Color(0xFF00B4FF),
    double size = 50,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 2),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return CustomPaint(
          painter: FuturisticLoaderPainter(
            progress: value,
            color: color,
          ),
          child: SizedBox(
            width: size,
            height: size,
          ),
        );
      },
    );
  }
}

// Custom Painters for Futuristic Effects
class HolographicScanPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  HolographicScanPainter({
    required this.animationValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scanLinePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final scanLineOffset = size.height * animationValue;

    // Draw scanning line
    canvas.drawLine(
      Offset(0, scanLineOffset),
      Offset(size.width, scanLineOffset),
      scanLinePaint,
    );

    // Add some glitch-like effects
    for (int i = 0; i < 5; i++) {
      final randomX = size.width * (i / 5);
      final randomWidth = size.width * 0.1;

      // Create a new Paint object instead of trying to modify the existing one
      final glitchPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..strokeWidth = scanLinePaint.strokeWidth
        ..style = scanLinePaint.style;

      canvas.drawLine(
        Offset(randomX, scanLineOffset),
        Offset(randomX + randomWidth, scanLineOffset),
        glitchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FuturisticLoaderPainter extends CustomPainter {
  final double progress;
  final Color color;

  FuturisticLoaderPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from top (using pi constant)
      2 * pi * progress, // Sweep angle based on progress
      false,
      progressPaint,
    );

    // Glowing dot at the end of the arc
    if (progress > 0) {
      final angle = -pi / 2 + 2 * pi * progress;
      final dotPosition = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      canvas.drawCircle(dotPosition, 8, dotPaint);

      // Subtle glow effect
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(dotPosition, 12, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}