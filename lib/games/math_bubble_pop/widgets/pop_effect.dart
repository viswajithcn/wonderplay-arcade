import 'dart:math';
import 'package:flutter/material.dart';

class PopEffectWidget extends StatefulWidget {
  final Offset position;
  final Color color;
  final double initialRadius;
  final VoidCallback onComplete;

  const PopEffectWidget({
    super.key,
    this.position = Offset.zero,
    required this.color,
    required this.initialRadius,
    required this.onComplete,
  });

  @override
  State<PopEffectWidget> createState() => _PopEffectWidgetState();
}

class _PopEffectWidgetState extends State<PopEffectWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    final rand = Random();
    final count = 10;
    for (int i = 0; i < count; i++) {
      final angle = (2 * pi / count) * i + (rand.nextDouble() - 0.5) * 0.4;
      final speed = widget.initialRadius * (1.2 + rand.nextDouble() * 0.8);
      final size = 4.0 + rand.nextDouble() * 5.0;
      _particles.add(_Particle(
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: size,
      ));
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _controller.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectSize = widget.initialRadius * 4;
    final centerOffset = Offset(effectSize / 2, effectSize / 2);

    return RepaintBoundary(
      child: SizedBox(
        width: effectSize,
        height: effectSize,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = _controller.value;
            final opacity = (1.0 - progress).clamp(0.0, 1.0);

            return CustomPaint(
              size: Size(effectSize, effectSize),
              painter: _ParticlePainter(
                particles: _particles,
                center: centerOffset,
                progress: progress,
                color: widget.color.withValues(alpha: opacity),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  final double vx;
  final double vy;
  final double size;

  _Particle({required this.vx, required this.vy, required this.size});
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Offset center;
  final double progress;
  final Color color;

  _ParticlePainter({
    required this.particles,
    required this.center,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final p in particles) {
      final x = center.dx + p.vx * progress;
      final y = center.dy + p.vy * progress;
      final currentSize = p.size * (1.0 - progress * 0.5);
      canvas.drawCircle(Offset(x, y), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
