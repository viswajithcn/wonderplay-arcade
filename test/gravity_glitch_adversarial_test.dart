import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/games/gravity_glitch/components/spike_obstacle.dart';
import 'package:kids_games/games/gravity_glitch/game/gravity_glitch_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async => 1,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Gravity Glitch Adversarial Stress Tests', () {
    // -------------------------------------------------------------------------
    // 1. RAPID MULTI-TAPS & EXTREME DT PHYSICS STRESS
    // -------------------------------------------------------------------------
    test('Rapid multi-taps (50 rapid taps) do not cause bounds tunneling or NaN', () async {
      final game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      final player = game.player;
      final random = Random(12345);

      for (int i = 0; i < 50; i++) {
        // Tap gravity toggle
        player.toggleGravity();

        // Simulate micro physics ticks between 1ms and 20ms
        final dt = 0.001 + random.nextDouble() * 0.019;
        player.update(dt);

        // Assert strict invariants after EVERY single tap and tick
        expect(player.position.x, equals(75.0), reason: 'X coordinate deviated on tap $i');
        expect(player.position.y, inInclusiveRange(game.ceilingY, game.floorY),
            reason: 'Y coordinate out of bounds on tap $i: ${player.position.y}');
        expect(player.velocity.y.isNaN, isFalse, reason: 'Velocity became NaN on tap $i');
        expect(player.velocity.y.isInfinite, isFalse, reason: 'Velocity became infinite on tap $i');
        expect(player.scale.y.isNaN, isFalse, reason: 'Scale became NaN on tap $i');
      }
    });

    test('Massive delta time lag spikes (dt up to 10s) do not tunnel past floor or ceiling', () async {
      final game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      final player = game.player;

      // 1. Lag spike falling towards floor
      player.isGravityInverted = false;
      player.velocity = Vector2(0, 2000.0); // fast downward velocity
      player.update(10.0); // 10 second lag spike

      expect(player.position.y, equals(game.floorY),
          reason: 'Player tunneled through floor during lag spike');
      expect(player.velocity.y, equals(0.0),
          reason: 'Velocity not zeroed after clamping at floor');

      // 2. Lag spike moving towards ceiling
      player.toggleGravity();
      player.velocity = Vector2(0, -2000.0); // fast upward velocity
      player.update(10.0); // 10 second lag spike

      expect(player.position.y, equals(game.ceilingY),
          reason: 'Player tunneled through ceiling during lag spike');
      expect(player.velocity.y, equals(0.0),
          reason: 'Velocity not zeroed after clamping at ceiling');
    });

    // -------------------------------------------------------------------------
    // 2. MULTIPLE COLLISION FRAMES & INVULNERABILITY INTEGRITY
    // -------------------------------------------------------------------------
    test('Consecutive collision frames during 1.5s invulnerability never double-damage', () async {
      int livesNotified = 3;
      int gameOverCalls = 0;

      final game = GravityGlitchGame(
        ceilingY: 80.0,
        floorY: 400.0,
        onLivesChanged: (l) => livesNotified = l,
        onGameOver: (_, __) => gameOverCalls++,
      );
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      // Hit 1: Initial damage
      game.onPlayerHit();
      expect(game.lives, equals(2));
      expect(livesNotified, equals(2));
      expect(game.player.isInvulnerable, isTrue);
      expect(game.player.invulnerabilityTimer, equals(1.5));

      // Simulate 60 continuous collision frames during the 1.5s grace window
      for (int f = 0; f < 60; f++) {
        game.player.update(0.016); // 16ms per frame -> total ~0.96s
        // Collisions continuously attempt to hit player in every frame
        game.onPlayerHit();
        expect(game.lives, equals(2), reason: 'Damage taken during invulnerability frame $f');
      }

      // Invulnerability still active (~0.54s remaining)
      expect(game.player.isInvulnerable, isTrue);

      // Advance past remaining time (0.6s)
      game.player.update(0.6);
      expect(game.player.isInvulnerable, isFalse, reason: 'Invulnerability should expire');
      expect(game.player.invulnerabilityTimer, equals(0.0));

      // Hit 2: Next valid hit after grace period
      game.onPlayerHit();
      expect(game.lives, equals(1));
      expect(game.player.isInvulnerable, isTrue);

      // Advance past 1.6s
      game.player.update(1.6);
      expect(game.player.isInvulnerable, isFalse);

      // Hit 3: Fatal hit -> Game Over
      game.onPlayerHit();
      expect(game.lives, equals(0));
      expect(game.isGameOver, isTrue);
      expect(gameOverCalls, equals(1));

      // Extra collision frames post game-over do NOT decrement lives below 0 or re-trigger game over
      for (int i = 0; i < 10; i++) {
        game.onPlayerHit();
      }
      expect(game.lives, equals(0));
      expect(gameOverCalls, equals(1));
    });

    // -------------------------------------------------------------------------
    // 3. PROCEDURAL SPAWNER MINIMUM GAP & CONSECUTIVE INVARIANTS
    // -------------------------------------------------------------------------
    test('Procedural spawner strictly enforces >= 250px clearance across 500 simulated cycles', () async {
      final game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      final spawner = game.spawner;
      final random = Random(9999);
      int spawnCount = 0;

      // Run 500 simulation steps
      for (int step = 0; step < 500; step++) {
        final dt = 0.016 + random.nextDouble() * 0.05;

        // Count spikes before
        final beforeCount = game.children.whereType<SpikeObstacle>().length;

        // Update all existing spikes first (movement)
        for (final spike in game.children.whereType<SpikeObstacle>().toList()) {
          spike.update(dt);
        }

        // Update spawner
        spawner.update(dt);

        // Check if a new spike was spawned
        final afterSpikes = game.children.whereType<SpikeObstacle>().toList();
        if (afterSpikes.length > beforeCount) {
          spawnCount++;
          // Find the newly spawned spike (closest to spawnOriginX)
          final newest = afterSpikes.reduce((a, b) => a.position.x > b.position.x ? a : b);

          // Find the second newest spike (if any)
          final others = afterSpikes.where((s) => s != newest).toList();
          if (others.isNotEmpty) {
            final secondNewest = others.reduce((a, b) => a.position.x > b.position.x ? a : b);
            final gap = newest.position.x - secondNewest.position.x;
            expect(gap, greaterThanOrEqualTo(250.0),
                reason: 'Spawned spike with gap $gap < 250.0 at step $step (spawn #$spawnCount)');
          }
        }
      }

      expect(spawnCount, greaterThan(5), reason: 'Spawner should have generated obstacles');
    });

    // -------------------------------------------------------------------------
    // 4. SCREEN RESIZE EVENTS (PORTRAIT <-> LANDSCAPE)
    // -------------------------------------------------------------------------
    test('Viewport resizing maintains player clamping and rail geometry', () async {
      final game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(400, 800)); // Portrait
      await game.onLoad();

      expect(game.ceilingY, equals(80.0));
      expect(game.floorY, equals(720.0)); // 800 - 80

      // Put player on floor
      game.player.position.y = game.floorY;
      expect(game.player.position.y, equals(720.0));

      // Resize abruptly to landscape (width 800, height 400)
      game.onGameResize(Vector2(800, 400));
      expect(game.ceilingY, equals(80.0));
      expect(game.floorY, equals(320.0)); // 400 - 80

      // Player must be immediately clamped to new floorY
      expect(game.player.position.y, equals(320.0),
          reason: 'Player not clamped to new floor on orientation change');

      // Put player at ceiling
      game.player.position.y = game.ceilingY;
      expect(game.player.position.y, equals(80.0));

      // Resize to compact phone screen (width 360, height 300)
      game.onGameResize(Vector2(360, 300));
      expect(game.ceilingY, equals(80.0));
      expect(game.floorY, equals(260.0)); // max(80 + 180, 300 - 80) = 260
      expect(game.player.position.y, inInclusiveRange(game.ceilingY, game.floorY));
    });

    // -------------------------------------------------------------------------
    // 5. RESET GAME INTEGRITY
    // -------------------------------------------------------------------------
    test('ResetGame safely clears in-flight state and restores clean baseline', () async {
      final game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();

      // Corrupt state
      game.lives = 1;
      game.score = 250;
      game.obstaclesPassed = 25;
      game.isGameOver = true;
      game.isPaused = true;
      game.player.isGravityInverted = true;
      game.player.isInvulnerable = true;
      game.player.invulnerabilityTimer = 1.2;
      game.player.position = Vector2(75.0, 100.0);

      // Add several obstacles
      game.spawner.spawnDirect(isCeiling: true, x: 200.0);
      game.spawner.spawnDirect(isCeiling: false, x: 500.0);
      expect(game.children.whereType<SpikeObstacle>().length, equals(2));

      // Reset
      game.resetGame();

      // Assert all baseline invariants
      expect(game.lives, equals(3));
      expect(game.score, equals(0));
      expect(game.obstaclesPassed, equals(0));
      expect(game.isGameOver, isFalse);
      expect(game.isPaused, isFalse);
      expect(game.player.position.y, equals(game.floorY));
      expect(game.player.position.x, equals(75.0));
      expect(game.player.velocity, equals(Vector2.zero()));
      expect(game.player.isGravityInverted, isFalse);
      expect(game.player.isInvulnerable, isFalse);
      expect(game.player.invulnerabilityTimer, equals(0.0));
      expect(game.children.whereType<SpikeObstacle>().isEmpty, isTrue);
    });
  });
}
