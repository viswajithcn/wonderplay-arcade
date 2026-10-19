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

  // =========================================================================
  // GROUP 1: GameWidget Lifecycle & Unmounting Stress
  // =========================================================================
  group('Challenger M3-2: GameWidget Lifecycle & Screen Unmount', () {
    testWidgets('Unmounting GravityGlitchScreen during active FlameGame loop leaves no errors',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      // Mount screen
      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();
      expect(find.byType(GravityGlitchScreen), findsOneWidget);
      expect(find.byType(GameWidget<GravityGlitchGame>), findsOneWidget);

      // Advance multiple active frames
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Unmount immediately by replacing with an empty container
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Unmounted')),
      ));
      await tester.pump();

      expect(find.byType(GravityGlitchScreen), findsNothing);
      expect(find.text('Unmounted'), findsOneWidget);
    });

    testWidgets('Unmounting during player invulnerability period cleans up safely',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();

      final screenState = tester.state<GravityGlitchScreenState>(
        find.byType(GravityGlitchScreen),
      );
      final game = screenState.game;

      // Trigger hit -> player becomes invulnerable for 1.5s
      game.onPlayerHit();
      expect(game.player.isInvulnerable, isTrue);

      // Advance 0.2s while blinking
      await tester.pump(const Duration(milliseconds: 200));

      // Unmount while invulnerability timer is still active
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Unmounted During Invulnerability')),
      ));
      await tester.pump();

      expect(find.byType(GravityGlitchScreen), findsNothing);
    });

    testWidgets('Unmounting while paused does not leak timers or throw',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();

      // Open pause overlay
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.text('Game Paused'), findsOneWidget);

      // Unmount while paused
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Unmounted While Paused')),
      ));
      await tester.pump();

      expect(find.text('Game Paused'), findsNothing);
      expect(find.byType(GravityGlitchScreen), findsNothing);
    });

    testWidgets('Repeated mount / unmount cycles (stress test 5 iterations)',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(MaterialApp(
          home: GravityGlitchScreen(storage: storage),
        ));
        await tester.pump();

        // Advance a few frames
        await tester.pump(const Duration(milliseconds: 32));

        // Unmount
        await tester.pumpWidget(const MaterialApp(
          home: SizedBox.shrink(),
        ));
        await tester.pump();
      }
    });

    testWidgets('HUD Back button pops screen through Navigator while alive',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GravityGlitchScreen(storage: storage),
                  ),
                );
              },
              child: const Text('Open Game'),
            ),
          ),
        ),
      ));

      // Push GravityGlitchScreen
      await tester.tap(find.text('Open Game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // allow route transition
      expect(find.byType(GravityGlitchScreen), findsOneWidget);

      // Tap HUD Back Button
      final backButtonFinder = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.icon == Icons.arrow_back_rounded && widget.size == 24.0,
      );
      expect(backButtonFinder, findsOneWidget);
      await tester.tap(backButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // allow pop transition

      // Verify popped back to root
      expect(find.byType(GravityGlitchScreen), findsNothing);
      expect(find.text('Open Game'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 2: Pause and Resume Mechanics
  // =========================================================================
  group('Challenger M3-2: Pause and Resume Mechanics', () {
    testWidgets('Pause overlay toggle freezes Flame engine and resumes cleanly',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();

      final screenState = tester.state<GravityGlitchScreenState>(
        find.byType(GravityGlitchScreen),
      );
      final game = screenState.game;

      expect(game.paused, isFalse);

      // 1. Tap pause button
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      expect(game.paused, isTrue);
      expect(find.text('Game Paused'), findsOneWidget);

      // Resume button is visible inside overlay
      expect(find.text('Resume'), findsOneWidget);

      // 2. Tap Resume button in pause modal
      await tester.tap(find.text('Resume'));
      await tester.pump();

      expect(game.paused, isFalse);
      expect(find.text('Game Paused'), findsNothing);
    });

    testWidgets('Multiple rapid pause/resume cycles maintain consistent state',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();

      final screenState = tester.state<GravityGlitchScreenState>(
        find.byType(GravityGlitchScreen),
      );
      final game = screenState.game;

      for (int i = 0; i < 4; i++) {
        // Pause
        await tester.tap(find.byIcon(Icons.pause_rounded));
        await tester.pump();
        expect(game.paused, isTrue);
        expect(find.text('Game Paused'), findsOneWidget);

        // Resume
        await tester.tap(find.text('Resume'));
        await tester.pump();
        expect(game.paused, isFalse);
        expect(find.text('Game Paused'), findsNothing);
      }
    });

    testWidgets('Exit button on pause overlay pops screen cleanly',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GravityGlitchScreen(storage: storage),
                  ),
                );
              },
              child: const Text('Launch Game'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Launch Game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Open pause overlay
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.text('Game Paused'), findsOneWidget);

      // Tap Exit on pause overlay
      await tester.tap(find.text('Exit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(GravityGlitchScreen), findsNothing);
      expect(find.text('Launch Game'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 3: Score Counting and Obstacle Clearance Invariants
  // =========================================================================
  group('Challenger M3-2: Score Counting and Obstacle Clearance', () {
    testWidgets('Safe obstacle clearance updates score pill and obstaclesPassed',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();

      final screenState = tester.state<GravityGlitchScreenState>(
        find.byType(GravityGlitchScreen),
      );
      final game = screenState.game;

      expect(find.text('0'), findsOneWidget);

      // Simulate 3 obstacles passing
      game.onObstaclePassed();
      await tester.pump();
      expect(find.text('10'), findsOneWidget);
      expect(game.obstaclesPassed, equals(1));

      game.onObstaclePassed();
      await tester.pump();
      expect(find.text('20'), findsOneWidget);
      expect(game.obstaclesPassed, equals(2));

      game.onObstaclePassed();
      await tester.pump();
      expect(find.text('30'), findsOneWidget);
      expect(game.obstaclesPassed, equals(3));
    });

    test('Single obstacle does not trigger double-score across multiple updates', () {
      final game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));

      final player = GlitchPlayer(position: Vector2(75.0, 400.0));
      game.player = player;

      final spike = SpikeObstacle(
        isCeiling: false,
        speed: 100.0,
        position: Vector2(70.0, 400.0), // already past 75.0
      );
      game.add(spike);

      // First tick past player
      spike.update(0.05);
      expect(spike.scored, isTrue);
      expect(game.score, equals(10));
      expect(game.obstaclesPassed, equals(1));

      // Additional 10 ticks should NOT add any extra score
      for (int i = 0; i < 10; i++) {
        spike.update(0.05);
      }
      expect(game.score, equals(10));
      expect(game.obstaclesPassed, equals(1));
    });

    test('Challenging obstacle behavior after player collision: scored flag analysis', () {
      final game = GravityGlitchGame(ceilingY: 80.0, floorY: 400.0);
      game.onGameResize(Vector2(800, 600));

      final player = GlitchPlayer(position: Vector2(75.0, 400.0));
      game.player = player;

      final spike = SpikeObstacle(
        isCeiling: false,
        speed: 200.0,
        position: Vector2(75.0, 400.0), // directly at player position
      );
      game.add(spike);

      // Simulate collision
      game.onPlayerHit();
      expect(game.lives, equals(2));
      expect(game.player.isInvulnerable, isTrue);

      // Spike moves past player (to X = 60)
      spike.position.x = 60.0;
      spike.update(0.01);

      // In current architecture, SpikeObstacle scores upon crossing player.position.x
      // even if it caused damage on that same obstacle.
      expect(spike.scored, isTrue);
    });
  });

  // =========================================================================
  // GROUP 4: Game Over Engine Pause, Dialog Flows, and Storage Persistence
  // =========================================================================
  group('Challenger M3-2: Game Over State, Dialogs & Storage Persistence', () {
    testWidgets('Losing all 3 hearts halts engine, shows GameOverDialog, and updates hearts HUD',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();

      final screenState = tester.state<GravityGlitchScreenState>(
        find.byType(GravityGlitchScreen),
      );
      final game = screenState.game;

      // Check initial hearts: 3 filled hearts
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(3));
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);

      // Hit 1
      game.onPlayerHit();
      await tester.pump();
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(1));

      // Hit 2
      game.player.isInvulnerable = false;
      game.onPlayerHit();
      await tester.pump();
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(1));
      expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(2));

      // Hit 3 -> Game Over (pauses engine, so pumpAndSettle is safe)
      game.player.isInvulnerable = false;
      game.onPlayerHit();
      await tester.pumpAndSettle();

      // Hearts HUD should show 0 filled, 3 borders
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNWidgets(3));

      // Engine paused
      expect(game.paused, isTrue);
      expect(game.isGameOver, isTrue);

      // GameOverDialog rendered
      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(find.text('Out of Hearts!'), findsOneWidget);
      expect(find.text('Try Again!'), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);
    });

    testWidgets('GameOverDialog Try Again restarts the session cleanly',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(storage: storage),
      ));
      await tester.pump();

      final screenState = tester.state<GravityGlitchScreenState>(
        find.byType(GravityGlitchScreen),
      );
      final game = screenState.game;

      // Trigger game over via handleGameOver
      await screenState.handleGameOver(50, 5);
      await tester.pumpAndSettle();

      expect(find.byType(GameOverDialog), findsOneWidget);

      // Tap 'Try Again!'
      await tester.tap(find.text('Try Again!'));
      await tester.pump(); // dismisses dialog
      await tester.pump(const Duration(milliseconds: 250)); // let dialog dismiss animation complete

      // Dialog dismissed
      expect(find.byType(GameOverDialog), findsNothing);

      // Game state restored
      expect(game.lives, equals(3));
      expect(game.score, equals(0));
      expect(game.obstaclesPassed, equals(0));
      expect(game.isGameOver, isFalse);
      expect(game.paused, isFalse);

      // Hearts restored
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(3));
    });

    testWidgets('GameOverDialog Exit returns to previous route',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GravityGlitchScreen(storage: storage),
                  ),
                );
              },
              child: const Text('Play Glitch'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Play Glitch'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final screenState = tester.state<GravityGlitchScreenState>(
        find.byType(GravityGlitchScreen),
      );

      // Trigger game over (pauses engine)
      await screenState.handleGameOver(80, 8);
      await tester.pumpAndSettle();

      expect(find.byType(GameOverDialog), findsOneWidget);

      // Tap 'Exit' on GameOverDialog
      await tester.tap(find.text('Exit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verified returned to parent route
      expect(find.byType(GameOverDialog), findsNothing);
      expect(find.byType(GravityGlitchScreen), findsNothing);
      expect(find.text('Play Glitch'), findsOneWidget);
    });

    testWidgets('Storage persistence monotonicity across multiple runs',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GravityGlitchScreen(
          storage: storage,
          difficulty: GameDifficulty.hard,
        ),
      ));
      await tester.pump();

      final screenState = tester.state<GravityGlitchScreenState>(
        find.byType(GravityGlitchScreen),
      );

      // Run 1: Score 50 (2 stars)
      await screenState.handleGameOver(50, 5);
      await tester.pumpAndSettle();

      expect(storage.getLevelHighScore('gravity_glitch', 1), equals(50));
      expect(storage.getLevelStars('gravity_glitch', 1), equals(2));
      expect(storage.getGameHighScore('gravity_glitch', 'hard'), equals(50));
      expect(storage.getGameStars('gravity_glitch', 'hard'), equals(2));
      // Note: Calling both saveLevelResult and saveGameResult increments totalStars in both methods
      expect(storage.getTotalStars(), equals(4));

      // Dismiss dialog
      await tester.tap(find.text('Try Again!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Run 2: Score 140 (3 stars) -> Increases high score and stars
      await screenState.handleGameOver(140, 14);
      await tester.pumpAndSettle();

      expect(storage.getLevelHighScore('gravity_glitch', 1), equals(140));
      expect(storage.getLevelStars('gravity_glitch', 1), equals(3));
      expect(storage.getGameHighScore('gravity_glitch', 'hard'), equals(140));
      expect(storage.getGameStars('gravity_glitch', 'hard'), equals(3));
      // 4 + (3-2) from level + (3-2) from game = 6
      expect(storage.getTotalStars(), equals(6));

      // Dismiss dialog
      await tester.tap(find.text('Try Again!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Run 3: Score 20 (1 star) -> Does NOT downgrade high score or stars
      await screenState.handleGameOver(20, 2);
      await tester.pumpAndSettle();

      expect(storage.getLevelHighScore('gravity_glitch', 1), equals(140));
      expect(storage.getLevelStars('gravity_glitch', 1), equals(3));
      expect(storage.getGameHighScore('gravity_glitch', 'hard'), equals(140));
      expect(storage.getGameStars('gravity_glitch', 'hard'), equals(3));
      expect(storage.getTotalStars(), equals(6));
    });
  });
}
