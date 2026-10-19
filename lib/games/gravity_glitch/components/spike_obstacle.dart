import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/gravity_glitch_game.dart';

/// Spike hazard component spawned on either the floor or ceiling.
/// Moves right-to-left towards the player.
class SpikeObstacle extends PositionComponent
    with CollisionCallbacks, HasGameReference<GravityGlitchGame> {
  final bool isCeiling;
  double speed;
  bool scored = false;

  SpikeObstacle({
    required this.isCeiling,
    this.speed = 250.0,
    super.position,
  }) : super(
          size: Vector2(36, 44),
          anchor: Anchor.center,
        );

  GravityGlitchGame get gameRef => game;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Hitbox sized fairly for forgiving kid gameplay
    add(RectangleHitbox(
      position: Vector2(4, 4),
      size: Vector2(size.x - 8, size.y - 8),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Move leftward
    position.x -= speed * dt;

    // Check if player has safely passed this obstacle
    if (!scored && position.x < game.player.position.x) {
      scored = true;
      game.onObstaclePassed();
    }

    // Despawn when off screen left
    if (position.x + size.x < -60) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    // Hazard gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: isCeiling ? Alignment.topCenter : Alignment.bottomCenter,
        end: isCeiling ? Alignment.bottomCenter : Alignment.topCenter,
        colors: const [
          Color(0xFFFF1744), // Crimson
          Color(0xFFFF9100), // Bright Orange
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    // Outer neon glow stroke
    final strokePaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Inner energy core paint
    final corePaint = Paint()
      ..color = const Color(0xFFFFEA00) // Electric Yellow
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isCeiling) {
      // Triangle pointing down from ceiling
      path.moveTo(size.x / 2, size.y);
      path.lineTo(size.x, 0);
      path.lineTo(0, 0);
      path.close();
    } else {
      // Triangle pointing up from floor
      path.moveTo(size.x / 2, 0);
      path.lineTo(size.x, size.y);
      path.lineTo(0, size.y);
      path.close();
    }

    // Draw main hazard triangle
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Draw cyber warning core in center
    final coreCenter = isCeiling
        ? Offset(size.x / 2, size.y * 0.35)
        : Offset(size.x / 2, size.y * 0.65);
    canvas.drawCircle(coreCenter, 4.0, corePaint);

    // Base mounting rail plate
    final basePaint = Paint()..color = const Color(0xFF37474F);
    if (isCeiling) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 0, size.x - 4, 6),
          const Radius.circular(2),
        ),
        basePaint,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(2, size.y - 6, size.x - 4, 6),
          const Radius.circular(2),
        ),
        basePaint,
      );
    }
  }
}
