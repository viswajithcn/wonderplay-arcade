import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/gravity_glitch_game.dart';
import 'spike_obstacle.dart';

/// The player character runner.
/// Fixed at X=75.0, flips between floor and ceiling via gravity inversion.
class GlitchPlayer extends PositionComponent
    with CollisionCallbacks, HasGameReference<GravityGlitchGame> {
  static const double defaultSize = 42.0;
  static const double defaultFixedX = 75.0;
  static const double invulnerabilityDuration = 1.5;

  double fixedX = defaultFixedX;
  Vector2 velocity = Vector2.zero();
  double gravityAcceleration = 2400.0;
  bool isGravityInverted = false;

  bool isInvulnerable = false;
  double invulnerabilityTimer = 0.0;
  double _blinkTimer = 0.0;
  bool _isVisible = true;

  // Visual scale for smooth flipping animation
  double currentScaleY = 1.0;

  GravityGlitchGame get gameRef => game;

  GlitchPlayer({super.position})
      : super(
          size: Vector2(defaultSize, defaultSize),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Hitbox with slight inset for fair collision detection
    add(RectangleHitbox(
      position: Vector2(3, 3),
      size: Vector2(size.x - 6, size.y - 6),
    ));
  }

  /// Toggles gravity direction between floor (normal) and ceiling (inverted).
  void toggleGravity() {
    isGravityInverted = !isGravityInverted;
    // Provide a small initial impulse to make the flip feel responsive and snappy
    velocity.y = isGravityInverted ? -500.0 : 500.0;
  }

  /// Trigger post-hit grace period (1.5s invulnerability with blinking)
  void takeHit() {
    if (isInvulnerable) return;
    isInvulnerable = true;
    invulnerabilityTimer = invulnerabilityDuration;
    _blinkTimer = 0.0;
    _isVisible = true;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is SpikeObstacle) {
      gameRef.onPlayerHit();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // 1. Invulnerability countdown & blinking effect
    if (isInvulnerable) {
      invulnerabilityTimer -= dt;
      _blinkTimer += dt;
      if (_blinkTimer >= 0.1) {
        _blinkTimer = 0.0;
        _isVisible = !_isVisible;
      }
      if (invulnerabilityTimer <= 0) {
        isInvulnerable = false;
        invulnerabilityTimer = 0.0;
        _isVisible = true;
      }
    } else {
      _isVisible = true;
    }

    // 2. Vertical Physics
    final currentGravity = isGravityInverted ? -gravityAcceleration : gravityAcceleration;
    velocity.y += currentGravity * dt;
    position.y += velocity.y * dt;

    // 3. Keep X locked
    position.x = fixedX;

    // 4. Clamping between ceiling and floor
    final ceilingY = gameRef.ceilingY;
    final floorY = gameRef.floorY;

    if (position.y <= ceilingY) {
      position.y = ceilingY;
      if (isGravityInverted && velocity.y < 0) {
        velocity.y = 0;
      }
    } else if (position.y >= floorY) {
      position.y = floorY;
      if (!isGravityInverted && velocity.y > 0) {
        velocity.y = 0;
      }
    }

    // 5. Smooth visual flip interpolation
    final targetScaleY = isGravityInverted ? -1.0 : 1.0;
    currentScaleY += (targetScaleY - currentScaleY) * min(1.0, dt * 14.0);
    scale.y = currentScaleY;
  }

  @override
  void render(Canvas canvas) {
    if (!_isVisible) return;
    super.render(canvas);

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);

    // 1. Cyber thruster trail glow (behind player)
    final thrusterPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(2, size.y / 2), 10, thrusterPaint);

    // 2. Body gradient (Cyber Neon Cyan + Electric Violet)
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF00E5FF), // Cyan
          Color(0xFF7C4DFF), // Electric Purple
        ],
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    // Rounded runner robot / ship chassis
    final bodyRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.x - 8, size.y - 8),
      const Radius.circular(10),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    // 3. Neon Outline
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(bodyRRect, outlinePaint);

    // 4. High-tech Visor
    final visorPaint = Paint()
      ..color = const Color(0xFF0A0E1A)
      ..style = PaintingStyle.fill;
    final visorRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.x * 0.42, size.y * 0.25, size.x * 0.46, size.y * 0.45),
      const Radius.circular(6),
    );
    canvas.drawRRect(visorRRect, visorPaint);

    // 5. Cute glowing eye / visor glint
    final eyePaint = Paint()
      ..color = const Color(0xFF76FF03) // Neon Lime
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.x * 0.52, size.y * 0.35, size.x * 0.28, size.y * 0.22),
        const Radius.circular(3),
      ),
      eyePaint,
    );

    // 6. Ear/Antenna node
    final antennaPaint = Paint()..color = const Color(0xFFFFD600);
    canvas.drawCircle(Offset(size.x * 0.22, size.y * 0.15), 3, antennaPaint);
  }
}
