import 'dart:math';
import 'package:flame/components.dart';
import '../game/gravity_glitch_game.dart';
import 'spike_obstacle.dart';

/// Spawns SpikeObstacles procedurally.
/// Enforces safe clearance (>= 250px gap) and prevents impossible dual-wall spawns.
class SpikeSpawner extends Component
    with HasGameReference<GravityGlitchGame> {
  static const double minimumGap = 260.0;
  static const double baseInterval = 1.6;

  final Random _random = Random();
  double _timer = 0.0;
  double _currentInterval = baseInterval;
  int _consecutiveSameSurface = 0;
  bool _lastSurfaceWasCeiling = false;

  GravityGlitchGame get gameRef => game;

  @override
  void update(double dt) {
    super.update(dt);

    if (game.isGameOver || game.isPaused) return;

    // Check rightmost spike to guarantee minimum safe gap
    double rightmostX = -double.infinity;
    for (final spike in game.children.whereType<SpikeObstacle>()) {
      if (spike.position.x > rightmostX) {
        rightmostX = spike.position.x;
      }
    }

    final spawnOriginX = game.size.x + 30.0;
    // If the last spawned obstacle has not traveled at least minimumGap from spawnOriginX, wait
    if (spawnOriginX - rightmostX < minimumGap) {
      return;
    }

    _timer += dt;
    if (_timer >= _currentInterval) {
      _timer = 0.0;
      _spawnObstacle(spawnOriginX);
      // Dynamic interval with slight randomness
      _currentInterval = 1.4 + _random.nextDouble() * 0.9;
    }
  }

  void _spawnObstacle(double spawnX) {
    // Determine surface (ceiling vs floor)
    // Prevent more than 2 consecutive spikes on the same surface for variety
    bool isCeiling;
    if (_consecutiveSameSurface >= 2) {
      isCeiling = !_lastSurfaceWasCeiling;
      _consecutiveSameSurface = 1;
    } else {
      isCeiling = _random.nextBool();
      if (isCeiling == _lastSurfaceWasCeiling) {
        _consecutiveSameSurface++;
      } else {
        _consecutiveSameSurface = 1;
      }
    }
    _lastSurfaceWasCeiling = isCeiling;

    // Progressive speed scaling based on score (240 - 360 px/s)
    final dynamicSpeed = 240.0 + min(120.0, gameRef.score * 1.2);

    final yPos = isCeiling ? gameRef.ceilingY : gameRef.floorY;

    final obstacle = SpikeObstacle(
      isCeiling: isCeiling,
      speed: dynamicSpeed,
      position: Vector2(spawnX, yPos),
    );

    gameRef.add(obstacle);
  }

  /// Direct spawn method useful for testing or scripted scenarios
  SpikeObstacle spawnDirect({
    required bool isCeiling,
    double? speed,
    double? x,
  }) {
    final yPos = isCeiling ? gameRef.ceilingY : gameRef.floorY;
    final obstacle = SpikeObstacle(
      isCeiling: isCeiling,
      speed: speed ?? 250.0,
      position: Vector2(x ?? (gameRef.size.x + 30.0), yPos),
    );
    gameRef.add(obstacle);
    return obstacle;
  }
}
