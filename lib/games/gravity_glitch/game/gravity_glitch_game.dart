import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../core/audio/audio_controller.dart';
import '../components/glitch_player.dart';
import '../components/spike_obstacle.dart';
import '../components/spike_spawner.dart';

/// The core FlameGame for Gravity Glitch.
/// Runs at 60fps with collision detection, single-tap gravity flips,
/// and procedural obstacle challenges.
class GravityGlitchGame extends FlameGame
    with HasCollisionDetection, TapCallbacks {
  double ceilingY;
  double floorY;
  int lives = 3;
  int score = 0;
  int obstaclesPassed = 0;
  bool isGameOver = false;
  bool isPaused = false;

  final void Function(int lives)? onLivesChanged;
  final void Function(int score)? onScoreChanged;
  final void Function(int score, int obstaclesPassed)? onGameOver;

  late GlitchPlayer player;
  late SpikeSpawner spawner;
  bool _hasPlayer = false;

  // Background stars for cyber aesthetic
  final List<Offset> _starOffsets = [];
  final Random _starRandom = Random(42);

  GravityGlitchGame({
    this.ceilingY = 80.0,
    this.floorY = 400.0,
    this.onLivesChanged,
    this.onScoreChanged,
    this.onGameOver,
  });

  @override
  Color backgroundColor() => const Color(0xFF0D1117);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Adjust ceiling and floor according to game size if available
    if (size.y > 200) {
      ceilingY = 80.0;
      floorY = max(ceilingY + 180.0, size.y - 80.0);
    }

    // Initialize player starting on the floor
    player = GlitchPlayer(position: Vector2(75.0, floorY));
    _hasPlayer = true;
    await add(player);

    // Initialize spawner
    spawner = SpikeSpawner();
    await add(spawner);

    // Generate static starfield background points
    _generateStars();
  }

  void _generateStars() {
    _starOffsets.clear();
    final width = size.x > 0 ? size.x : 800.0;
    final height = size.y > 0 ? size.y : 600.0;
    for (int i = 0; i < 40; i++) {
      _starOffsets.add(Offset(
        _starRandom.nextDouble() * width,
        _starRandom.nextDouble() * height,
      ));
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.y > 200) {
      ceilingY = 80.0;
      floorY = max(ceilingY + 180.0, size.y - 80.0);
    }

    // Ensure player is kept within new bounds
    if (_hasPlayer) {
      if (player.position.y > floorY) {
        player.position.y = floorY;
      } else if (player.position.y < ceilingY) {
        player.position.y = ceilingY;
      }
    }

    _generateStars();
  }

  DateTime? _lastFlipTime;

  @override
  bool containsLocalPoint(Vector2 point) => true;

  /// Flips player gravity on tap/click or key press with debounce against double-firing.
  void flipGravity() {
    if (isGameOver || isPaused || !_hasPlayer) return;

    final now = DateTime.now();
    if (_lastFlipTime != null &&
        now.difference(_lastFlipTime!).inMilliseconds < 40) {
      return;
    }
    _lastFlipTime = now;

    player.toggleGravity();
    AudioController().playPop();
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    flipGravity();
  }

  /// Called by GlitchPlayer on collision with a SpikeObstacle.
  void onPlayerHit() {
    if (player.isInvulnerable || isGameOver) return;

    lives--;
    player.takeHit();
    AudioController().playWrong();
    onLivesChanged?.call(lives);

    if (lives <= 0) {
      lives = 0;
      isGameOver = true;
      pauseEngine();
      onGameOver?.call(score, obstaclesPassed);
    }
  }

  /// Called when a SpikeObstacle successfully passes the player without hit.
  void onObstaclePassed() {
    if (isGameOver) return;

    obstaclesPassed++;
    score += 10;
    onScoreChanged?.call(score);
  }

  /// Resets the game to start a new run.
  void resetGame() {
    // Clear all existing obstacles
    for (final child in children.whereType<SpikeObstacle>().toList()) {
      child.removeFromParent();
    }

    lives = 3;
    score = 0;
    obstaclesPassed = 0;
    isGameOver = false;
    isPaused = false;

    // Reset player
    player.position = Vector2(player.fixedX, floorY);
    player.velocity = Vector2.zero();
    player.isGravityInverted = false;
    player.isInvulnerable = false;
    player.invulnerabilityTimer = 0.0;
    player.currentScaleY = 1.0;

    onLivesChanged?.call(lives);
    onScoreChanged?.call(score);

    resumeEngine();
  }

  @override
  void render(Canvas canvas) {
    // 1. Draw Starfield
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    for (final star in _starOffsets) {
      canvas.drawCircle(star, 1.5, starPaint);
    }

    // 2. Draw Ceiling Rail (Cyan Neon Line)
    final ceilingRailPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    final ceilingGlowPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.3)
      ..strokeWidth = 10.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style = PaintingStyle.stroke;

    final startX = 0.0;
    final endX = size.x > 0 ? size.x : 1000.0;

    canvas.drawLine(Offset(startX, ceilingY), Offset(endX, ceilingY), ceilingGlowPaint);
    canvas.drawLine(Offset(startX, ceilingY), Offset(endX, ceilingY), ceilingRailPaint);

    // 3. Draw Floor Rail (Magenta/Pink Neon Line)
    final floorRailPaint = Paint()
      ..color = const Color(0xFFFF007F)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    final floorGlowPaint = Paint()
      ..color = const Color(0xFFFF007F).withValues(alpha: 0.3)
      ..strokeWidth = 10.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(startX, floorY), Offset(endX, floorY), floorGlowPaint);
    canvas.drawLine(Offset(startX, floorY), Offset(endX, floorY), floorRailPaint);

    // Super renders children (Player, Spikes)
    super.render(canvas);
  }
}
