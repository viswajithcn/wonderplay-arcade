import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/gravity_glitch/components/glitch_player.dart';
import 'package:kids_games/games/gravity_glitch/components/spike_obstacle.dart';
import 'package:kids_games/games/gravity_glitch/game/gravity_glitch_game.dart';
import 'package:kids_games/games/gravity_glitch/views/gravity_glitch_screen.dart';
import 'package:kids_games/models/mini_game_model.dart';
import 'package:kids_games/shared/widgets/game_over_dialog.dart';
import 'package:kids_games/shared/widgets/hearts_display.dart';

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

  group('Gravity Glitch: GlitchPlayer Unit Tests', () {
    late GravityGlitchGame game;

    setUp(() async {
      game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
    });

    test('Initializes with fixed X coordinate at floor baseline', () {
      final player = game.player;
      expect(player.fixedX, equals(75.0));
      expect(player.position.x, equals(75.0));
      expect(player.position.y, equals(game.floorY));
      expect(player.isGravityInverted, isFalse);
      expect(player.isInvulnerable, isFalse);
      expect(player.velocity, equals(Vector2.zero()));
    });

    test('Toggle gravity inverts direction and applies impulse', () {
      final player = game.player;

      // Normal -> Inverted (Towards Ceiling)
      player.toggleGravity();
      expect(player.isGravityInverted, isTrue);
      expect(player.velocity.y, lessThan(0)); // Upward impulse

      // Inverted -> Normal (Towards Floor)
      player.toggleGravity();
      expect(player.isGravityInverted, isFalse);
      expect(player.velocity.y, greaterThan(0)); // Downward impulse
    });

    test('Clamps player vertical movement at ceiling boundary', () {
      final player = game.player;
      player.isGravityInverted = true;
      player.position.y = 85.0;
      player.velocity.y = -1000.0;

      // Simulate a physics tick
      player.update(0.1);

      // Should be clamped to ceilingY and velocity zeroed
      expect(player.position.y, equals(game.ceilingY));
      expect(player.velocity.y, equals(0.0));
    });

    test('Clamps player vertical movement at floor boundary', () {
      final player = game.player;
      player.isGravityInverted = false;
      player.position.y = game.floorY - 5.0;
      player.velocity.y = 500.0;

      // Simulate a physics tick
      player.update(0.1);

      // Should be clamped to floorY and velocity zeroed
      expect(player.position.y, equals(game.floorY));
      expect(player.velocity.y, equals(0.0));
    });

    test('Player fixedX invariant holds after movement updates', () {
      final player = game.player;
      player.update(0.5);
      expect(player.position.x, equals(75.0));
    });

    test('Post-hit grace period (1.5s invulnerability) ignores damage while active', () {
      final player = game.player;
      expect(player.isInvulnerable, isFalse);

      player.takeHit();
      expect(player.isInvulnerable, isTrue);
      expect(player.invulnerabilityTimer, equals(1.5));

      // Advance timer by 0.5s -> still invulnerable
      player.update(0.5);
      expect(player.isInvulnerable, isTrue);
      expect(player.invulnerabilityTimer, closeTo(1.0, 0.001));

      // Second hit ignored while invulnerable
      player.takeHit();
      expect(player.invulnerabilityTimer, closeTo(1.0, 0.001));

      // Advance by remaining 1.1s -> timer expires
      player.update(1.1);
      expect(player.isInvulnerable, isFalse);
      expect(player.invulnerabilityTimer, equals(0.0));
    });
  });

  group('Gravity Glitch: SpikeObstacle Unit Tests', () {
    late GravityGlitchGame game;

    setUp(() async {
      game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
    });

    test('Floor spike positioned on floor with upward orientation', () {
      final spike = SpikeObstacle(
        isCeiling: false,
        speed: 260.0,
        position: Vector2(500.0, game.floorY),
      );
      expect(spike.isCeiling, isFalse);
      expect(spike.position.y, equals(game.floorY));
      expect(spike.speed, equals(260.0));
      expect(spike.scored, isFalse);
    });

    test('Ceiling spike positioned on ceiling with downward orientation', () {
      final spike = SpikeObstacle(
        isCeiling: true,
        speed: 260.0,
        position: Vector2(500.0, game.ceilingY),
      );
      expect(spike.isCeiling, isTrue);
      expect(spike.position.y, equals(game.ceilingY));
    });

    test('Moves leftward according to speed and delta time', () {
      final spike = SpikeObstacle(
        isCeiling: false,
        speed: 300.0,
        position: Vector2(500.0, game.floorY),
      );
      game.add(spike);

      // Simulate 0.5 seconds
      spike.update(0.5);
      expect(spike.position.x, equals(350.0));
    });

    test('Passing player X increments score exactly once', () {
      int scoreNotified = 0;
      game = GravityGlitchGame(
        ceilingY: 80.0,
        floorY: 400.0,
        onScoreChanged: (score) => scoreNotified = score,
      );
      game.onGameResize(Vector2(800, 600));

      final player = GlitchPlayer(position: Vector2(75.0, 400.0));
      game.player = player;

      final spike = SpikeObstacle(
        isCeiling: false,
        speed: 200.0,
        position: Vector2(85.0, 400.0),
      );
      game.add(spike);

      // Spike moves past player X (75.0)
      spike.position.x = 60.0;
      spike.update(0.01);

      expect(spike.scored, isTrue);
      expect(game.score, equals(10));
      expect(scoreNotified, equals(10));
      expect(game.obstaclesPassed, equals(1));

      // Subsequent update does NOT double-score
      spike.update(0.01);
      expect(game.score, equals(10));
    });
  });

  group('Gravity Glitch: SpikeSpawner Unit Tests', () {
    late GravityGlitchGame game;

    setUp(() async {
      game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
    });

    test('Direct spawn creates obstacle with valid surface coordinate', () {
      final spawner = game.spawner;
      final ceilingSpike = spawner.spawnDirect(isCeiling: true, speed: 280.0);
      expect(ceilingSpike.isCeiling, isTrue);
      expect(ceilingSpike.position.y, equals(game.ceilingY));

      final floorSpike = spawner.spawnDirect(isCeiling: false, speed: 280.0);
      expect(floorSpike.isCeiling, isFalse);
      expect(floorSpike.position.y, equals(game.floorY));
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

  group('Gravity Glitch: GravityGlitchGame Engine Tests', () {
    late GravityGlitchGame game;
    int notifiedLives = 3;
    int notifiedScore = 0;
    bool isGameOverTriggered = false;

    setUp(() async {
      notifiedLives = 3;
      notifiedScore = 0;
      isGameOverTriggered = false;

      game = GravityGlitchGame(
        ceilingY: 80.0,
        floorY: 400.0,
        onLivesChanged: (lives) => notifiedLives = lives,
        onScoreChanged: (score) => notifiedScore = score,
        onGameOver: (score, passed) => isGameOverTriggered = true,
      );
      game.onGameResize(Vector2(800, 600));
      await game.onLoad();
    });

    test('Initializes with 3 lives and 0 score', () {
      expect(game.lives, equals(3));
      expect(game.score, equals(0));
      expect(game.obstaclesPassed, equals(0));
      expect(game.isGameOver, isFalse);
      expect(game.isPaused, isFalse);
    });

    test('TapDown flips player gravity', () {
      expect(game.player.isGravityInverted, isFalse);

      final tapEvent = TapDownEvent(
        1,
        game,
        TapDownDetails(globalPosition: const Offset(100, 100)),
      );
      game.onTapDown(tapEvent);

      expect(game.player.isGravityInverted, isTrue);
    });

    test('Player hit decrements lives and notifies listener', () {
      game.onPlayerHit();
      expect(game.lives, equals(2));
      expect(notifiedLives, equals(2));
      expect(game.player.isInvulnerable, isTrue);
    });

    test('Obstacle passed increments score and notifies listener', () {
      game.onObstaclePassed();
      expect(game.score, equals(10));
      expect(notifiedScore, equals(10));
      expect(game.obstaclesPassed, equals(1));
    });

    test('Losing all 3 lives sets isGameOver and triggers onGameOver callback', () {
      // Hit 1
      game.onPlayerHit();
      expect(game.lives, equals(2));

      // Reset invulnerability to simulate next hit
      game.player.isInvulnerable = false;
      game.onPlayerHit();
      expect(game.lives, equals(1));

      // Hit 3 -> Game Over
      game.player.isInvulnerable = false;
      game.onPlayerHit();
      expect(game.lives, equals(0));
      expect(game.isGameOver, isTrue);
      expect(isGameOverTriggered, isTrue);
    });

    test('ResetGame restores hearts, score, and player state', () {
      game.lives = 1;
      game.score = 80;
      game.obstaclesPassed = 8;
      game.isGameOver = true;

      // Add a dummy spike
      game.add(SpikeObstacle(isCeiling: false, position: Vector2(100, 400)));

      game.resetGame();

      expect(game.lives, equals(3));
      expect(game.score, equals(0));
      expect(game.obstaclesPassed, equals(0));
      expect(game.isGameOver, isFalse);
      expect(game.children.whereType<SpikeObstacle>().isEmpty, isTrue);
      expect(game.player.isGravityInverted, isFalse);
      expect(game.player.isInvulnerable, isFalse);
    });

    test('Game resize clamps player and adjusts floor/ceiling', () {
      game.onGameResize(Vector2(400, 300));
      expect(game.ceilingY, equals(80.0));
      expect(game.floorY, equals(260.0)); // 80 + 180
      expect(game.player.position.y, inInclusiveRange(game.ceilingY, game.floorY));
    });
  });

  group('Gravity Glitch: GravityGlitchScreen Widget Tests', () {
    testWidgets('Renders GameWidget, HeartsDisplay, Score Pill, and Back Button',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();

      expect(find.byType(GameWidget<GravityGlitchGame>), findsOneWidget);
      expect(find.byType(HeartsDisplay), findsOneWidget);
      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('Tapping pause button opens pause overlay with resume and exit buttons',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();

      // Tap pause button
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Game Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      // Tap resume
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      expect(find.text('Game Paused'), findsNothing);
    });

    testWidgets('Game Over triggers GameOverDialog and saves score/stars to GameStorage',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(
          storage: storage,
          difficulty: GameDifficulty.hard,
        ),
      ));
      await tester.pump();

      // Find the screen state to simulate game over
      final screenState = tester.state<GravityGlitchScreenState>(
        find.byType(GravityGlitchScreen),
      );

      // Simulate game over with 120 points (3 stars) and 12 obstacles passed
      await screenState.handleGameOver(120, 12);
      await tester.pumpAndSettle();

      // Assert GameOverDialog rendered
      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);

      // Assert storage persisted 3 stars and 120 high score
      expect(storage.getLevelHighScore('gravity_glitch', 1), equals(120));
      expect(storage.getLevelStars('gravity_glitch', 1), equals(3));
      expect(storage.getGameHighScore('gravity_glitch', 'hard'), equals(120));
      expect(storage.getGameStars('gravity_glitch', 'hard'), equals(3));
    });
  });
}
