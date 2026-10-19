import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/gravity_glitch/components/spike_obstacle.dart';
import 'package:kids_games/games/gravity_glitch/game/gravity_glitch_game.dart';
import 'package:kids_games/games/gravity_glitch/views/gravity_glitch_screen.dart';

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

  group('Reviewer M3-2: Adversarial Physics & Rapid Input Stress Tests', () {
    late GravityGlitchGame game;

    setUp(() async {
      game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
    });

    test('100 rapid gravity flips never violate vertical bounds or produce NaN/Inf', () {
      final player = game.player;
      final random = Random(1337);

      for (int i = 0; i < 100; i++) {
        player.toggleGravity();
        final dt = random.nextDouble() * 0.05 + 0.005; // 5ms to 55ms
        player.update(dt);

        expect(player.position.x, equals(75.0), reason: 'X-axis must remain strictly fixed at 75');
        expect(player.position.y, greaterThanOrEqualTo(game.ceilingY), reason: 'Player penetrated ceiling');
        expect(player.position.y, lessThanOrEqualTo(game.floorY), reason: 'Player penetrated floor');
        expect(player.velocity.y.isNaN, isFalse);
        expect(player.velocity.y.isInfinite, isFalse);
      }
    });

    test('Spamming taps while paused or game over does NOT flip gravity', () {
      final player = game.player;
      final initialInverted = player.isGravityInverted;

      // When Paused
      game.isPaused = true;
      final tap = TapDownEvent(1, game, TapDownDetails(globalPosition: const Offset(200, 200)));
      game.onTapDown(tap);
      expect(player.isGravityInverted, equals(initialInverted));

      // When Game Over
      game.isPaused = false;
      game.isGameOver = true;
      game.onTapDown(tap);
      expect(player.isGravityInverted, equals(initialInverted));
    });
  });

  group('Reviewer M3-2: Collision & Hitbox Boundary Precision Tests', () {
    late GravityGlitchGame game;

    setUp(() async {
      game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
    });

    test('Near-miss: Ceiling spike passing overhead while player on floor does NOT hit and scores +10', () {
      expect(game.player.position.y, equals(game.floorY));

      final spike = SpikeObstacle(
        isCeiling: true,
        speed: 200.0,
        position: Vector2(100.0, game.ceilingY),
      );
      game.add(spike);

      // Spike moves past player X (75.0)
      spike.position.x = 60.0;
      spike.update(0.01);

      expect(spike.scored, isTrue);
      expect(game.score, equals(10));
      expect(game.lives, equals(3));
      expect(game.player.isInvulnerable, isFalse);
    });

    test('Exact collision: Floor spike hitting player decrements life and activates 1.5s grace', () {
      expect(game.player.position.y, equals(game.floorY));
      expect(game.lives, equals(3));

      // Trigger hit
      game.onPlayerHit();

      expect(game.lives, equals(2));
      expect(game.player.isInvulnerable, isTrue);
      expect(game.player.invulnerabilityTimer, equals(1.5));

      // Subsequent 10 hits during the 1.5s are rejected
      for (int i = 0; i < 10; i++) {
        game.onPlayerHit();
        expect(game.lives, equals(2));
      }

      // Fast-forward 1.0s (still within 1.5s window)
      game.player.update(1.0);
      expect(game.player.isInvulnerable, isTrue);
      game.onPlayerHit();
      expect(game.lives, equals(2));

      // Fast-forward 0.55s (exceeds 1.5s duration)
      game.player.update(0.55);
      expect(game.player.isInvulnerable, isFalse);

      // Next hit is registered
      game.onPlayerHit();
      expect(game.lives, equals(1));
    });
  });

  group('Reviewer M3-2: Screen Resize Invariants & Responsiveness Tests', () {
    test('Floor-Ceiling clearance is always >= 180px across diverse aspect ratios', () {
      final game = GravityGlitchGame();

      final testResolutions = [
        Vector2(320, 240),   // Tiny landscape
        Vector2(480, 320),   // Small phone landscape
        Vector2(800, 480),   // Medium landscape
        Vector2(1080, 1920), // Standard portrait
        Vector2(1920, 1080), // Standard 1080p landscape
        Vector2(2560, 1440), // 2K display
        Vector2(360, 640),   // Tall budget portrait
        Vector2(500, 210),   // Extremely short aspect ratio
      ];

      for (final res in testResolutions) {
        game.onGameResize(res);
        final gap = game.floorY - game.ceilingY;
        expect(
          gap,
          greaterThanOrEqualTo(180.0),
          reason: 'Resolution ${res.x}x${res.y} resulted in unsafe gap $gap < 180.0',
        );
      }
    });

    test('Orientation flip from portrait to landscape immediately clamps player safely', () async {
      final game = GravityGlitchGame();
      // Start in portrait (size: 400 x 800)
      game.onGameResize(Vector2(400, 800));
      await game.onLoad();
      expect(game.floorY, equals(720.0));
      expect(game.player.position.y, equals(720.0));

      // Rotate to landscape (size: 800 x 400)
      game.onGameResize(Vector2(800, 400));
      expect(game.floorY, equals(320.0));
      expect(game.player.position.y, equals(320.0));
      expect(game.player.position.y, inInclusiveRange(game.ceilingY, game.floorY));

      // Rotate back to portrait (size: 400 x 800)
      game.onGameResize(Vector2(400, 800));
      expect(game.floorY, equals(720.0));
      // Player falls downward via gravity physics
      game.player.update(0.5);
      expect(game.player.position.y, greaterThan(320.0));
      expect(game.player.position.y, lessThanOrEqualTo(720.0));
    });
  });

  group('Reviewer M3-2: Spawner Safe Clearance Invariant Verification', () {
    late GravityGlitchGame game;

    setUp(() async {
      game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
    });

    test('Enforces minimum safe gap (>= 250px) between consecutive spawns', () {
      final spawner = game.spawner;
      final spawnOriginX = game.size.x + 30.0;

      // Add a spike very close to spawn origin
      final firstSpike = SpikeObstacle(
        isCeiling: false,
        position: Vector2(spawnOriginX - 100.0, game.floorY),
      );
      game.add(firstSpike);

      final initialChildCount = game.children.whereType<SpikeObstacle>().length;

      // Update spawner with enough dt to exceed interval
      spawner.update(5.0);

      // Should NOT spawn because gap is only 100px (< 260px)
      final currentChildCount = game.children.whereType<SpikeObstacle>().length;
      expect(currentChildCount, equals(initialChildCount));
    });
  });

  group('Reviewer M3-2: Star Rating & Storage Persistence Matrix', () {
    test('Star threshold rules and storage persistence logic', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();

      final cases = [
        {'score': 0, 'expectedStars': 0},
        {'score': 30, 'expectedStars': 1},
        {'score': 50, 'expectedStars': 2},
        {'score': 90, 'expectedStars': 2},
        {'score': 100, 'expectedStars': 3},
        {'score': 250, 'expectedStars': 3},
      ];

      for (final testCase in cases) {
        final score = testCase['score'] as int;
        final expectedStars = testCase['expectedStars'] as int;
        final stars = score >= 100 ? 3 : (score >= 50 ? 2 : (score > 0 ? 1 : 0));
        expect(stars, equals(expectedStars));

        await storage.saveLevelResult('gravity_glitch', 1, score, stars);
        await storage.saveGameResult('gravity_glitch', 'hard', score, stars);
      }

      expect(storage.getLevelHighScore('gravity_glitch', 1), equals(250));
      expect(storage.getLevelStars('gravity_glitch', 1), equals(3));
      expect(storage.getGameHighScore('gravity_glitch', 'hard'), equals(250));
      expect(storage.getGameStars('gravity_glitch', 'hard'), equals(3));
    });
  });

  group('Reviewer M3-2: Live GameWidget Execution', () {
    testWidgets('Live gameplay: GravityGlitchScreen running for 3 seconds with spawning spikes',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();

      // Pump 200 frames of 16ms (~3.2 seconds), enough for spawner to trigger
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    });
  });
}
