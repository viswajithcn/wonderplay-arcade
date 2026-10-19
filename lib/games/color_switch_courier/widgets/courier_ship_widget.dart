import 'package:flutter/material.dart';
import '../models/courier_color.dart';

/// Animated courier spaceship widget positioned at the bottom of the lane.
/// Features a dynamic glowing energy shield that reflects the current active color,
/// an accessibility glyph in the core, and twin thruster energy flames.
class CourierShipWidget extends StatefulWidget {
  final CourierColor color;
  final double size;
  final bool isPulsing;

  const CourierShipWidget({
    super.key,
    required this.color,
    this.size = 64.0,
    this.isPulsing = false,
  });

  @override
  State<CourierShipWidget> createState() => _CourierShipWidgetState();
}

class _CourierShipWidgetState extends State<CourierShipWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 50,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(covariant CourierShipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.color != widget.color) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color.color;
    final glowColor = widget.color.glowColor;

    return AnimatedBuilder(
      animation: _pulseScale,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseScale.value,
          child: child,
        );
      },
      child: SizedBox(
        width: widget.size + 24.0,
        height: widget.size + 24.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glowing shield halo
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: widget.size + 16.0,
              height: widget.size + 16.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.55),
                    blurRadius: 18.0,
                    spreadRadius: 3.0,
                  ),
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.35),
                    blurRadius: 28.0,
                    spreadRadius: 6.0,
                  ),
                ],
                border: Border.all(
                  color: activeColor.withValues(alpha: 0.9),
                  width: 2.5,
                ),
                gradient: RadialGradient(
                  colors: [
                    activeColor.withValues(alpha: 0.25),
                    activeColor.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),

            // Thruster flame particles
            Positioned(
              bottom: 2.0,
              child: _ThrusterFlame(color: activeColor),
            ),

            // Futuristic spaceship hull
            CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _SpaceshipPainter(activeColor: activeColor),
            ),

            // Center cockpit energy orb with accessibility glyph
            Container(
              width: 32.0,
              height: 32.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.8),
                    blurRadius: 6.0,
                  ),
                ],
                border: Border.all(
                  color: Colors.white,
                  width: 2.0,
                ),
              ),
              child: Center(
                child: Icon(
                  widget.color.symbol,
                  color: Colors.white,
                  size: 18.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceshipPainter extends CustomPainter {
  final Color activeColor;

  _SpaceshipPainter({required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ship Hull Path
    final hullPath = Path()
      ..moveTo(w * 0.5, h * 0.08) // Nose tip
      ..lineTo(w * 0.72, h * 0.42) // Right shoulder
      ..lineTo(w * 0.92, h * 0.78) // Right wing tip
      ..lineTo(w * 0.68, h * 0.74) // Right inner wing
      ..lineTo(w * 0.58, h * 0.88) // Right engine mount
      ..lineTo(w * 0.42, h * 0.88) // Left engine mount
      ..lineTo(w * 0.32, h * 0.74) // Left inner wing
      ..lineTo(w * 0.08, h * 0.78) // Left wing tip
      ..lineTo(w * 0.28, h * 0.42) // Left shoulder
      ..close();

    // Metallic body gradient
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFE2E8F0),
          Color(0xFF94A3B8),
          Color(0xFF334155),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // Hull border paint
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Wing accent stripes paint
    final accentPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(hullPath, bodyPaint);
    canvas.drawPath(hullPath, borderPaint);

    // Left Wing Accent
    final leftWingAccent = Path()
      ..moveTo(w * 0.15, h * 0.74)
      ..lineTo(w * 0.30, h * 0.52)
      ..lineTo(w * 0.34, h * 0.65)
      ..close();
    canvas.drawPath(leftWingAccent, accentPaint);

    // Right Wing Accent
    final rightWingAccent = Path()
      ..moveTo(w * 0.85, h * 0.74)
      ..lineTo(w * 0.70, h * 0.52)
      ..lineTo(w * 0.66, h * 0.65)
      ..close();
    canvas.drawPath(rightWingAccent, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _SpaceshipPainter oldDelegate) {
    return oldDelegate.activeColor != activeColor;
  }
}

class _ThrusterFlame extends StatelessWidget {
  final Color color;

  const _ThrusterFlame({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14.0,
      height: 12.0,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8.0)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            color,
            color.withValues(alpha: 0.0),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.8),
            blurRadius: 6.0,
            spreadRadius: 1.0,
          ),
        ],
      ),
    );
  }
}
