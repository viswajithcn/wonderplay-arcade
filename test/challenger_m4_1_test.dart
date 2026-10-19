import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/audio/audio_controller.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/color_switch_courier/models/courier_color.dart';
import 'package:kids_games/games/color_switch_courier/models/laser_gate.dart';
import 'package:kids_games/games/color_switch_courier/views/color_switch_courier_screen.dart';
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

  group('Adversarial Challenge 1: Rapid Color Cycling (50 taps & Modulo 3)', () {
    late GameStorage storage;

    setUp(() async {
      storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);
    });

    test('CourierColor next() strictly cycles Red -> Green -> Blue -> Red for 100 cycles', () {
      var color = CourierColor.red;
      const expectedOrder = [CourierColor.green, CourierColor.blue, CourierColor.red];

      for (int i = 0; i < 100; i++) {
        color = color.next();
        expect(color, equals(expectedOrder[i % 3]));
      }
    });

    test('CourierColor fromIndex satisfies invariant: fromIndex(k) == fromIndex(k + 3n)', () {
      for (int k = -50; k <= 50; k++) {
        final base = CourierColor.fromIndex(k);
        for (int n = -5; n <= 5; n++) {
          expect(CourierColor.fromIndex(k + 3 * n), equals(base));
        }
      }
    });

    testWidgets('Rapid color cycling of 50 taps on ColorSwitchCourierScreenState',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Verify starts at Red (index 0)
      expect(state.shipColor, equals(CourierColor.red));

      // Execute 50 rapid taps and assert state at each step
      for (int tap = 1; tap <= 50; tap++) {
        state.cycleColor();
        final expectedColor = CourierColor.fromIndex(tap);
        expect(
          state.shipColor,
          equals(expectedColor),
          reason: 'At tap $tap, expected $expectedColor but got ${state.shipColor}',
        );
      }

      // 50 % 3 = 2 -> CourierColor.blue
      expect(state.shipColor, equals(CourierColor.blue));
    });

    testWidgets('50 rapid gesture taps via widget tree UI',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final gestureFinder = find.byType(GestureDetector).first;
      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      for (int tap = 1; tap <= 50; tap++) {
        await tester.tap(gestureFinder);
        await tester.pump();
        expect(state.shipColor, equals(CourierColor.fromIndex(tap)));
      }

      expect(state.shipColor, equals(CourierColor.blue));
    });

    testWidgets('Tapping while paused does NOT cycle color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      expect(state.shipColor, equals(CourierColor.red));

      // Pause the game
      state.togglePause();
      expect(state.isPaused, isTrue);

      // Attempt 10 taps
      for (int i = 0; i < 10; i++) {
        state.cycleColor();
      }
      expect(state.shipColor, equals(CourierColor.red)); // Remains Red!

      // Resume game
      state.togglePause();
      expect(state.isPaused, isFalse);

      // Tap once -> Green
      state.cycleColor();
      expect(state.shipColor, equals(CourierColor.green));
    });

    testWidgets('Tapping after Game Over does NOT cycle color',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Trigger Game Over with a mismatch
      state.spawnGate(color: CourierColor.blue, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      final frozenColor = state.shipColor;

      // Attempt 15 taps
      for (int i = 0; i < 15; i++) {
        state.cycleColor();
      }
      expect(state.shipColor, equals(frozenColor));
    });
  });

  group('Adversarial Challenge 2: Collision Detection Precision & Crossing Window', () {
    late GameStorage storage;

    setUp(() async {
      storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);
    });

    testWidgets('Gate strictly above ship threshold (threshold - 0.001) does NOT collide',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      final threshold = state.shipCenterY;
      // Gate is 0.001 px above the collision threshold
      final gate = state.spawnGate(
        color: CourierColor.red,
        y: threshold - 0.001,
      );

      state.checkCollisions();

      expect(gate.isPassed, isFalse);
      expect(state.score, equals(0));
      expect(state.isGameOver, isFalse);
    });

    testWidgets('Gate exactly on ship threshold (y == threshold) triggers collision immediately',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      final threshold = state.shipCenterY;
      final gate = state.spawnGate(
        color: CourierColor.red,
        y: threshold,
      );

      state.checkCollisions();

      expect(gate.isPassed, isTrue);
      expect(state.score, equals(1));
      expect(state.isGameOver, isFalse);
    });

    testWidgets('Tunneling defense: Large dt jump past threshold is captured reliably',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Freeze automatic ticker loop by toggling pause, then manually test updateGame(dt)
      state.togglePause();
      expect(state.isPaused, isTrue);

      final threshold = state.shipCenterY;
      // Gate starts 40px above threshold
      final gate = LaserGate(
        id: 'gate_tunneling',
        y: threshold - 40.0,
        color: CourierColor.red,
        speed: 200.0,
      );

      // Advance gate by 0.5s at 200px/s -> +100px
      gate.update(0.5);
      expect(gate.y, equals(threshold + 60.0));

      // Add to gates and check collisions
      final field = state.spawnGate(
        color: CourierColor.red,
        y: threshold - 40.0,
        speed: 200.0,
      );
      field.update(0.5);
      state.checkCollisions();

      expect(field.y, equals(threshold + 60.0));
      expect(field.isPassed, isTrue);
      expect(state.score, equals(1));
    });

    testWidgets('Multiple gates crossing in the same frame processed in sequence',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      final threshold = state.shipCenterY;
      // Spawn two matching gates both past threshold
      final gate1 = state.spawnGate(color: CourierColor.red, y: threshold + 20.0);
      final gate2 = state.spawnGate(color: CourierColor.red, y: threshold + 5.0);

      state.checkCollisions();
      await tester.pump();

      expect(gate1.isPassed, isTrue);
      expect(gate2.isPassed, isTrue);
      expect(state.score, equals(2));
    });
  });

  group('Adversarial Challenge 3: Mismatch Triggers Immediate Game Over Without Subsequent Updates', () {
    late GameStorage storage;

    setUp(() async {
      storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);
    });

    testWidgets('Mismatch freezes gate updates: updateGame does nothing after game over',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      final threshold = state.shipCenterY;
      // Ship is Red; spawn Blue gate
      final mismatchGate = state.spawnGate(
        color: CourierColor.blue,
        y: threshold,
        speed: 200.0,
      );
      // Spawn another gate behind it
      final trailingGate = state.spawnGate(
        color: CourierColor.red,
        y: threshold - 100.0,
        speed: 200.0,
      );

      // Trigger collision
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      expect(find.byType(GameOverDialog), findsOneWidget);

      final mismatchYAfterGameOver = mismatchGate.y;
      final trailingYAfterGameOver = trailingGate.y;

      // Attempt 10 updateGame calls
      for (int i = 0; i < 10; i++) {
        state.updateGame(0.05);
      }

      // Assert gate positions remain perfectly frozen
      expect(mismatchGate.y, equals(mismatchYAfterGameOver));
      expect(trailingGate.y, equals(trailingYAfterGameOver));
      expect(trailingGate.isPassed, isFalse);
      expect(state.score, equals(0));
    });

    testWidgets('Trailing matching gate does NOT score if preceded by mismatch in same frame',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      final threshold = state.shipCenterY;
      // Ship is Red
      // First gate is mismatch (Green)
      final gateMismatch = state.spawnGate(color: CourierColor.green, y: threshold + 10.0);
      // Second gate is matching (Red)
      final gateMatch = state.spawnGate(color: CourierColor.red, y: threshold + 5.0);

      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      expect(gateMismatch.isPassed, isFalse);
      // The trailing gate must NOT have been scored because loop aborted immediately
      expect(gateMatch.isPassed, isFalse);
      expect(state.score, equals(0));
    });
  });

  group('Adversarial Challenge 4: Matching Color Increments Score Exactly Once Per Gate', () {
    late GameStorage storage;

    setUp(() async {
      storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);
    });

    testWidgets('Single gate evaluated 50 consecutive times scores exactly 1 point',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      final threshold = state.shipCenterY;
      final gate = state.spawnGate(color: CourierColor.red, y: threshold);

      // Check collision 50 times repeatedly
      for (int i = 0; i < 50; i++) {
        state.checkCollisions();
      }

      expect(state.score, equals(1));
      expect(gate.isPassed, isTrue);
      expect(state.highScore, equals(1));
    });

    testWidgets('Offscreen cleanup removes passed gate without score mutation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      final threshold = state.shipCenterY;
      final gate = state.spawnGate(color: CourierColor.red, y: threshold);
      state.checkCollisions();
      expect(state.score, equals(1));
      expect(state.gates.length, equals(1));

      // Move gate past track height + 60.0
      gate.y = 800.0;
      state.updateGame(0.01);
      await tester.pump();

      // Gate should be removed from active gates
      expect(state.gates.isEmpty, isTrue);
      expect(state.score, equals(1)); // Score stays 1
    });
  });

  group('Adversarial Challenge 5: Speed Calculation Invariants & Boundary Stress', () {
    test('calculateSpeed strictly respects lower bound of baseSpeed for non-negative scores', () {
      for (int s = 0; s <= 200; s++) {
        expect(LaserGate.calculateSpeed(s), greaterThanOrEqualTo(180.0));
      }
    });

    test('calculateSpeed strictly respects upper bound cap of 400.0 px/s even for massive scores', () {
      final stressScores = [88, 89, 90, 100, 250, 1000, 50000, 1000000];
      for (final s in stressScores) {
        expect(
          LaserGate.calculateSpeed(s),
          lessThanOrEqualTo(400.0),
          reason: 'Score $s exceeded 400.0 px/s cap',
        );
      }
    });

    test('calculateSpeed is monotonic non-decreasing: s1 <= s2 implies speed(s1) <= speed(s2)', () {
      double prevSpeed = LaserGate.calculateSpeed(0);
      for (int s = 1; s <= 300; s++) {
        final currentSpeed = LaserGate.calculateSpeed(s);
        expect(
          currentSpeed >= prevSpeed,
          isTrue,
          reason: 'Monotonicity violated at score $s: $currentSpeed < $prevSpeed',
        );
        prevSpeed = currentSpeed;
      }
    });

    test('calculateSpeed transition threshold: score 88 is 400.0 px/s exactly', () {
      // 180 + 88 * 2.5 = 180 + 220 = 400.0
      expect(LaserGate.calculateSpeed(87), equals(397.5));
      expect(LaserGate.calculateSpeed(88), equals(400.0));
      expect(LaserGate.calculateSpeed(89), equals(400.0));
    });

    test('Difficulty speed adjustments respect caps', () {
      // Easy: base 160
      expect(LaserGate.calculateSpeed(0, baseSpeed: 160.0), equals(160.0));
      expect(LaserGate.calculateSpeed(100, baseSpeed: 160.0), equals(400.0));

      // Hard: base 200
      expect(LaserGate.calculateSpeed(0, baseSpeed: 200.0), equals(200.0));
      expect(LaserGate.calculateSpeed(100, baseSpeed: 200.0), equals(400.0));
    });
  });

  group('Adversarial Challenge 6: Gate Color Anti-Clumping & Restart Robustness', () {
    late GameStorage storage;

    setUp(() async {
      storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);
    });

    testWidgets('Spawning 60 gates never produces 3 identical adjacent gate colors',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Spawn 60 gates
      for (int i = 0; i < 60; i++) {
        state.spawnGate();
      }

      final gateList = state.gates;
      expect(gateList.length, equals(60));

      // Verify no 3 identical adjacent colors
      for (int i = 0; i < gateList.length - 2; i++) {
        final c1 = gateList[i].color;
        final c2 = gateList[i + 1].color;
        final c3 = gateList[i + 2].color;
        final allThreeSame = (c1 == c2 && c2 == c3);
        expect(
          allThreeSame,
          isFalse,
          reason: 'Gate index $i, ${i+1}, ${i+2} are all $c1',
        );
      }
    });

    testWidgets('Restart after Game Over restores full playability without residual state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Score 3 points
      for (int i = 0; i < 3; i++) {
        state.spawnGate(color: state.shipColor, y: state.shipCenterY);
        state.checkCollisions();
      }
      expect(state.score, equals(3));

      // Trigger Game Over with mismatch
      final mismatch = state.shipColor == CourierColor.red
          ? CourierColor.blue
          : CourierColor.red;
      state.spawnGate(color: mismatch, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);

      // Restart game
      state.restartGame();
      await tester.pump();

      expect(state.isGameOver, isFalse);
      expect(state.isPaused, isFalse);
      expect(state.score, equals(0));
      expect(state.shipColor, equals(CourierColor.red));
      expect(state.gates.isEmpty, isTrue);

      // Can play another successful round
      state.spawnGate(color: CourierColor.red, y: state.shipCenterY);
      state.checkCollisions();
      expect(state.score, equals(1));
      expect(state.isGameOver, isFalse);
    });
  });
}
