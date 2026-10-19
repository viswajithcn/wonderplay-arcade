import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../models/bubble.dart';

class BubbleWidget extends StatelessWidget {
  final Bubble bubble;
  final VoidCallback onTap;

  const BubbleWidget({
    super.key,
    required this.bubble,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (bubble.isPopped) {
      return const SizedBox.shrink();
    }

    final diameter = bubble.radius * 2;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          size: Size(diameter, diameter),
          painter: _BubblePainter(
            color: bubble.color,
            isShaking: bubble.isShaking,
          ),
          child: SizedBox(
            width: diameter,
            height: diameter,
            child: Center(
              child: Text(
                '${bubble.value}',
                style: AppTheme.titleFont.copyWith(
                  fontSize: bubble.radius * 0.85,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      offset: const Offset(1, 2),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  final Color color;
  final bool isShaking;

  _BubblePainter({required this.color, required this.isShaking});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Translucent Body with radial gradient
    final baseGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.9,
      colors: [
        color.withValues(alpha: 0.4),
        color.withValues(alpha: 0.75),
        color.withValues(alpha: 0.95),
      ],
      stops: const [0.2, 0.7, 1.0],
    );

    final bodyPaint = Paint()
      ..shader = baseGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius - 2, bodyPaint);

    // 2. Shiny outer rim
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(center, radius - 2, rimPaint);

    // 3. Curved specular highlight (top left crescent)
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    final highlightPath = Path();
    final hCenter = Offset(center.dx - radius * 0.35, center.dy - radius * 0.35);
    final hRadius = radius * 0.32;
    highlightPath.addOval(
      Rect.fromCenter(
        center: hCenter,
        width: hRadius * 1.6,
        height: hRadius * 0.9,
      ),
    );

    canvas.save();
    canvas.translate(hCenter.dx, hCenter.dy);
    canvas.rotate(-pi / 4);
    canvas.translate(-hCenter.dx, -hCenter.dy);
    canvas.drawPath(highlightPath, highlightPaint);
    canvas.restore();

    // 4. Subtle secondary reflection (bottom right)
    final secPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx + radius * 0.35, center.dy + radius * 0.35),
      radius * 0.12,
      secPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isShaking != isShaking;
  }
}
