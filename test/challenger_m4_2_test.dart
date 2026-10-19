import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/audio/audio_controller.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/color_switch_courier/models/courier_color.dart';
import 'package:kids_games/games/color_switch_courier/views/color_switch_courier_screen.dart';
import 'package:kids_games/models/mini_game_model.dart';
import 'package:kids_games/shared/widgets/game_over_dialog.dart';
import 'package:kids_games/shared/widgets/kid_button.dart';

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
  // GROUP 1: Rapid Tap Bursts During Gameplay
  // =========================================================================
  group('Challenger M4-2 Group 1: Rapid Tap Bursts During Gameplay', () {
    testWidgets('Rapid tap burst of 30 taps cycles color accurately without corruption',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );
      expect(state.shipColor, equals(CourierColor.red));

      // Execute 30 rapid taps in succession
      final tapTarget = find.byType(GestureDetector).first;
      for (int i = 0; i < 30; i++) {
        await tester.tap(tapTarget);
        // Micro-pump without advancing significant real time
        await tester.pump();
      }

      // 30 taps modulo 3 == 0 -> should return to red
      expect(state.shipColor, equals(CourierColor.red));

      // 31st tap -> green
      await tester.tap(tapTarget);
      await tester.pump();
      expect(state.shipColor, equals(CourierColor.green));

      // 32nd tap -> blue
      await tester.tap(tapTarget);
      await tester.pump();
      expect(state.shipColor, equals(CourierColor.blue));
    });

    testWidgets('Tapping while game is paused does not change ship color',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );
      expect(state.shipColor, equals(CourierColor.red));

      // Tap pause button
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(state.isPaused, isTrue);

      // Attempt tapping game surface 10 times
      for (int i = 0; i < 10; i++) {
        state.cycleColor();
      }
      expect(state.shipColor, equals(CourierColor.red));
    });

    testWidgets('Tapping after game over does not change ship color',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Force mismatch collision to trigger game over
      state.spawnGate(color: CourierColor.blue, y: state.shipCenterY + 2.0);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      final preColor = state.shipColor;

      // Burst tap attempts
      for (int i = 0; i < 15; i++) {
        state.cycleColor();
      }
      expect(state.shipColor, equals(preColor));
    });

    testWidgets('Rapid color cycling right on collision frame matches instantaneous color',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Gate color is Blue, ship starts at Red
      final gate = state.spawnGate(
        color: CourierColor.blue,
        y: state.shipCenterY,
      );

      // Rapidly switch colors Red -> Green -> Blue right before collision check
      state.cycleColor(); // Green
      state.cycleColor(); // Blue
      expect(state.shipColor, equals(CourierColor.blue));

      state.checkCollisions();
      await tester.pump(const Duration(milliseconds: 100));

      expect(gate.isPassed, isTrue);
      expect(state.score, equals(1));
      expect(state.isGameOver, isFalse);
    });
  });

  // =========================================================================
  // GROUP 2: Pause Freezes Movement & Stops Ticker Updates
  // =========================================================================
  group('Challenger M4-2 Group 2: Pause Freezes Gate Movement & Tickers', () {
    testWidgets('Pausing freezes gate Y-positions and stops gate spawning',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(
          storage: storage,
          difficulty: GameDifficulty.medium,
        ),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Spawn two gates in mid-flight
      final g1 = state.spawnGate(color: CourierColor.red, y: 150.0);
      final g2 = state.spawnGate(color: CourierColor.green, y: 280.0);
      final initialGateCount = state.gates.length;

      // Tap pause button
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      expect(state.isPaused, isTrue);
      final frozenY1 = g1.y;
      final frozenY2 = g2.y;

      // Advance 60 frames (1 full simulated second) while paused
      for (int i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Assert gate positions remain completely frozen
      expect(g1.y, equals(frozenY1));
      expect(g2.y, equals(frozenY2));
      // Assert no new gates were spawned while paused
      expect(state.gates.length, equals(initialGateCount));
    });

    testWidgets('Resuming from pause clamps dt and avoids gate teleportation jump',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(
          storage: storage,
          difficulty: GameDifficulty.easy,
        ),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      final gate = state.spawnGate(
        color: CourierColor.red,
        y: 100.0,
        speed: 180.0,
      );

      // Pause
      state.togglePause();
      expect(state.isPaused, isTrue);

      // Simulate long pause delay (e.g. 5 seconds)
      await tester.pump(const Duration(seconds: 5));
      expect(gate.y, equals(100.0));

      // Resume
      state.togglePause();
      expect(state.isPaused, isFalse);

      // Pump 1 single frame (dt clamp is 0.05s max)
      // At max dt = 0.05s and speed = 180px/s, movement is at most 9.0 px
      state.updateGame(0.016);
      await tester.pump(const Duration(milliseconds: 16));

      expect(gate.y, lessThan(120.0));
      expect(gate.y, greaterThan(100.0));
    });

    testWidgets('Rapid pause toggle stress does not break state or drop controller',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      for (int i = 0; i < 10; i++) {
        state.togglePause();
        await tester.pump(const Duration(milliseconds: 10));
      }

      // After 10 toggles (even number), game should not be paused
      expect(state.isPaused, isFalse);
      expect(state.isGameOver, isFalse);
    });
  });

  // =========================================================================
  // GROUP 3: Unmounting Mid-Flight & Resource Cleanup
  // =========================================================================
  group('Challenger M4-2 Group 3: Unmounting Mid-Flight & Resource Disposal', () {
    testWidgets('Unmounting screen during active flight disposes AnimationController cleanly',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Spawn gates and simulate active running loop
      state.spawnGate(color: CourierColor.red, y: 100.0);
      state.spawnGate(color: CourierColor.green, y: 250.0);

      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Unmount abruptly mid-flight
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Unmounted')),
      ));
      await tester.pump();

      // Verify clean disposal with no pending timer exceptions
      expect(find.text('Unmounted'), findsOneWidget);
      expect(find.byType(ColorSwitchCourierScreen), findsNothing);
    });

    testWidgets('Unmounting during active match flash timer does not throw',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Trigger match collision to start 220ms flash timer
      state.spawnGate(color: CourierColor.red, y: state.shipCenterY);
      state.checkCollisions();
      // Pump only 50ms into the 220ms flash timer
      await tester.pump(const Duration(milliseconds: 50));

      // Unmount while timer is still in flight
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Unmounted During Flash')),
      ));

      // Advance remaining flash timer time (300ms)
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Unmounted During Flash'), findsOneWidget);
    });

    testWidgets('Unmounting while paused cleanly cleans up without leaks',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      // Pause
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      // Unmount
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Unmounted From Pause')),
      ));
      await tester.pump();

      expect(find.text('Unmounted From Pause'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 4: Game Over Dialog & GameStorage Persistence
  // =========================================================================
  group('Challenger M4-2 Group 4: GameOverDialog & GameStorage Persistence', () {
    testWidgets('Game over at score 0 awards 0 stars and saves to GameStorage',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      int? reportedScore;

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(
          storage: storage,
          difficulty: GameDifficulty.easy,
          onGameOver: (s) => reportedScore = s,
        ),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Mismatch collision at score 0
      state.spawnGate(color: CourierColor.blue, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      expect(reportedScore, equals(0));
      expect(storage.getLevelStars('color_switch_courier', 1), equals(0));
      expect(storage.getLevelHighScore('color_switch_courier', 1), equals(0));
      expect(storage.getGameHighScore('color_switch_courier', 'easy'), equals(0));
      expect(find.byType(GameOverDialog), findsOneWidget);
    });

    testWidgets('Game over at score 4 awards 1 star and saves to GameStorage',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(
          storage: storage,
          difficulty: GameDifficulty.medium,
        ),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Score 4 matches
      for (int i = 0; i < 4; i++) {
        state.spawnGate(color: state.shipColor, y: state.shipCenterY);
        state.checkCollisions();
        state.cycleColor();
      }
      expect(state.score, equals(4));

      // Mismatch
      final mismatch = state.shipColor == CourierColor.red
          ? CourierColor.green
          : CourierColor.red;
      state.spawnGate(color: mismatch, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      expect(storage.getLevelStars('color_switch_courier', 1), equals(1));
      expect(storage.getLevelHighScore('color_switch_courier', 1), equals(4));
      expect(storage.getGameHighScore('color_switch_courier', 'medium'), equals(4));
    });

    testWidgets('Game over at score 10 awards 2 stars and saves to GameStorage',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(
          storage: storage,
          difficulty: GameDifficulty.hard,
        ),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Score 10 matches
      for (int i = 0; i < 10; i++) {
        state.spawnGate(color: state.shipColor, y: state.shipCenterY);
        state.checkCollisions();
        state.cycleColor();
      }
      expect(state.score, equals(10));

      // Mismatch
      final mismatch = state.shipColor == CourierColor.red
          ? CourierColor.green
          : CourierColor.red;
      state.spawnGate(color: mismatch, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      expect(storage.getLevelStars('color_switch_courier', 1), equals(2));
      expect(storage.getLevelHighScore('color_switch_courier', 1), equals(10));
      expect(storage.getGameHighScore('color_switch_courier', 'hard'), equals(10));
    });

    testWidgets('Game over at score 20 awards 3 stars and saves to GameStorage',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(
          storage: storage,
          difficulty: GameDifficulty.medium,
        ),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Score 20 matches
      for (int i = 0; i < 20; i++) {
        state.spawnGate(color: state.shipColor, y: state.shipCenterY);
        state.checkCollisions();
        state.cycleColor();
      }
      expect(state.score, equals(20));

      // Mismatch
      final mismatch = state.shipColor == CourierColor.red
          ? CourierColor.green
          : CourierColor.red;
      state.spawnGate(color: mismatch, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      expect(storage.getLevelStars('color_switch_courier', 1), equals(3));
      expect(storage.getLevelHighScore('color_switch_courier', 1), equals(20));
      expect(storage.getGameHighScore('color_switch_courier', 'medium'), equals(20));
    });

    testWidgets('GameOverDialog retry button dismisses dialog and resets state',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Trigger game over
      state.spawnGate(color: CourierColor.blue, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(find.byType(GameOverDialog), findsOneWidget);

      // Find retry / try again button inside GameOverDialog
      final retryButton = find.text('Try Again!');
      expect(retryButton, findsOneWidget);
      await tester.tap(retryButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify game restarted cleanly
      expect(find.byType(GameOverDialog), findsNothing);
      expect(state.isGameOver, isFalse);
      expect(state.score, equals(0));
      expect(state.gates.isEmpty, isTrue);
    });

    testWidgets('GameOverDialog exit button triggers onExit callback',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      bool exitCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(
          storage: storage,
          onExit: () => exitCalled = true,
        ),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Trigger game over
      state.spawnGate(color: CourierColor.blue, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(find.byType(GameOverDialog), findsOneWidget);

      // Find exit button in GameOverDialog ('Exit')
      final exitFinder = find.widgetWithText(KidButton, 'Exit');
      expect(exitFinder, findsOneWidget);
      await tester.tap(exitFinder);
      await tester.pumpAndSettle();

      expect(exitCalled, isTrue);
    });
  });

  // =========================================================================
  // GROUP 5: Layout Constraints & Track Width Stress
  // =========================================================================
  group('Challenger M4-2 Group 5: Responsive Layout Constraints', () {
    testWidgets('Constrains track width to 420px on tablet/desktop displays',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      // Wide display: 800 x 1200
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      // Find Center child SizedBox that holds the track
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final trackBox = sizedBoxes.firstWhere(
        (box) => box.width == ColorSwitchCourierScreenState.maxTrackWidth,
      );
      expect(trackBox.width, equals(420.0));
    });

    testWidgets('Expands track to full width on narrow mobile displays',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      // Narrow mobile screen: 360 x 640
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final trackBox = sizedBoxes.firstWhere(
        (box) => box.width == 360.0,
      );
      expect(trackBox.width, equals(360.0));
    });
  });

  // =========================================================================
  // GROUP 6: Edge Cases, Null Safety & Preloaded Storage
  // =========================================================================
  group('Challenger M4-2 Group 6: Edge Cases & Preloaded High Scores', () {
    testWidgets('Pre-existing high score in GameStorage loads correctly on mount',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      // Pre-save high score 42
      await storage.saveLevelResult('color_switch_courier', 1, 42, 3);

      await tester.pumpWidget(MaterialApp(
        home: ColorSwitchCourierScreen(storage: storage),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );
      expect(state.highScore, equals(42));
    });

    testWidgets('Screen functions with null storage and null callbacks without errors',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ColorSwitchCourierScreen(
          storage: null,
          onGameOver: null,
          onExit: null,
        ),
      ));
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Play match
      state.spawnGate(color: CourierColor.red, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pump(const Duration(milliseconds: 50));
      expect(state.score, equals(1));

      // Trigger Game Over with null storage & null callbacks
      state.spawnGate(color: CourierColor.blue, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      expect(find.byType(GameOverDialog), findsOneWidget);
    });

    testWidgets('Top HUD back button calls Navigator.pop and onExit',
        (WidgetTester tester) async {
      bool exitCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  settings: const RouteSettings(name: '/courier'),
                  builder: (_) => ColorSwitchCourierScreen(
                    onExit: () => exitCalled = true,
                  ),
                ));
              },
              child: const Text('Launch Game'),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Launch
      await tester.tap(find.text('Launch Game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(ColorSwitchCourierScreen), findsOneWidget);

      // Tap HUD back button
      final backButton = find.byIcon(Icons.arrow_back_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      expect(exitCalled, isTrue);
      expect(find.byType(ColorSwitchCourierScreen), findsNothing);
      expect(find.text('Launch Game'), findsOneWidget);
    });

    testWidgets('Pause overlay exit button calls Navigator.pop and onExit',
        (WidgetTester tester) async {
      bool exitCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  settings: const RouteSettings(name: '/courier'),
                  builder: (_) => ColorSwitchCourierScreen(
                    onExit: () => exitCalled = true,
                  ),
                ));
              },
              child: const Text('Launch Game'),
            ),
          ),
        ),
      ));
      await tester.pump();

      // Launch
      await tester.tap(find.text('Launch Game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Tap pause button (stops game loop controller)
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);

      // Tap Exit in pause overlay
      final exitBtn = find.widgetWithText(KidButton, 'Exit');
      expect(exitBtn, findsOneWidget);
      await tester.tap(exitBtn);
      // Ticker is inactive so pumpAndSettle can safely settle the pop animation
      await tester.pumpAndSettle();

      expect(exitCalled, isTrue);
      expect(find.byType(ColorSwitchCourierScreen), findsNothing);
      expect(find.text('Launch Game'), findsOneWidget);
    });
  });
}
