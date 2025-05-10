import 'package:flutter/material.dart';
import 'dart:math';

/// A collection of futuristic-themed widgets for a unique UI experience.
class FuturisticWidgets {
  // Holographic Card
  static Widget holographicCard({
    required Widget child,
    Color baseColor = const Color(0xFF1E2D3C),
    Color glowColor = const Color(0xFF00B4FF),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: HolographicOverlayPainter(
                    glowColor: glowColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Futuristic Input Field
  static Widget futuristicTextField({
    required TextEditingController controller,
    String? hintText,
    IconData? prefixIcon,
    Color primaryColor = const Color(0xFF00B4FF),
    bool obscureText = false,
    TextInputType? keyboardType,
    FormFieldValidator<String>? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: Colors.white,
        letterSpacing: 1.2,
        fontFamily: 'SpaceMono',
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5),
          letterSpacing: 1.1,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(
                prefixIcon,
                color: primaryColor,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF1E2D3C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: primaryColor,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
      ),
    );
  }

  // Futuristic Button
  static Widget futuristicButton({
    required VoidCallback onPressed,
    required Widget child,
    Color primaryColor = const Color(0xFF00B4FF),
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 10,
        shadowColor: primaryColor.withOpacity(0.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          Positioned.fill(
            child: CustomPaint(
              painter: ButtonGlowPainter(
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Holographic Overlay Painter
class HolographicOverlayPainter extends CustomPainter {
  final Color glowColor;

  HolographicOverlayPainter({
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random();
    final paint = Paint()
      ..color = glowColor.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw random holographic lines
    for (int i = 0; i < 20; i++) {
      final start = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final end = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      canvas.drawLine(start, end, paint);
    }

    // Add some subtle glow points
    final glowPaint = Paint()
      ..color = glowColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 10; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(point, random.nextDouble() * 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Button Glow Painter
class ButtonGlowPainter extends CustomPainter {
  final Color color;

  ButtonGlowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(12),
      ));

    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}