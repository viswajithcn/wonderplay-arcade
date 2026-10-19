import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/audio/audio_controller.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/color_switch_courier/models/courier_color.dart';
import 'package:kids_games/games/color_switch_courier/views/color_switch_courier_screen.dart';
import 'package:kids_games/models/mini_game_model.dart';

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

  group('Reviewer 2 Adversarial Stress Tests: Color Switch Courier', () {
    late GameStorage storage;

    setUp(() async {
      storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);
    });

    testWidgets('Stress 1: Rapid color tapping burst (100 taps) maintains deterministic enum order',
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

      for (int i = 0; i < 100; i++) {
        state.cycleColor();
      }

      expect(state.shipColor, equals(CourierColor.green));
      expect(state.isGameOver, isFalse);
    });

    testWidgets('Stress 2: High-speed gate crossing catches collision on large dt jump',
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
        color: state.shipColor,
        speed: 400.0,
        y: threshold - 15.0,
      );

      state.updateGame(0.1);
      await tester.pump(const Duration(milliseconds: 100));

      expect(gate.y, greaterThan(threshold));
      expect(gate.isPassed, isTrue);
      expect(state.score, equals(1));
      expect(state.isGameOver, isFalse);
    });

    testWidgets('Stress 3: Extreme screen constraints (Ultra-wide 2560x1440 and Compact 320x480)',
        (WidgetTester tester) async {
      // 1. Ultra-wide tablet
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();

      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final trackBox = sizedBoxes.firstWhere(
        (box) => box.width == 420.0,
      );
      expect(trackBox.width, equals(420.0));
      expect(find.byType(ColorSwitchCourierScreen), findsOneWidget);

      // 2. Ultra-compact screen
      tester.view.physicalSize = const Size(320, 480);
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(ColorSwitchCourierScreen), findsOneWidget);
    });

    testWidgets('Stress 4: Sudden unmount during active loop and flash timer causes zero errors',
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

      state.spawnGate(color: state.shipColor, y: state.shipCenterY);
      state.checkCollisions();
      state.cycleColor();

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ColorSwitchCourierScreen), findsNothing);
    });

    testWidgets('Stress 5: Rapid pause/resume flood does not explode dt or controller state',
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

      for (int i = 0; i < 30; i++) {
        state.togglePause();
      }

      expect(state.isPaused, isFalse);

      state.updateGame(0.016);
      await tester.pump();
      expect(state.isGameOver, isFalse);
    });

    testWidgets('Stress 6: Gate despawn when offscreen and memory boundedness',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
            difficulty: GameDifficulty.hard,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Spawn a gate at y = 650 (within trackHeight 600 + 60 = 660)
      final gate1 = state.spawnGate(color: CourierColor.red, y: 650.0, speed: 200.0);
      expect(state.gates.contains(gate1), isTrue);

      // Advance physics by 0.1s -> gate moves to 650 + 200*0.1 = 670.0 (> 660.0)
      state.updateGame(0.1);
      await tester.pump();

      // Gate1 must be cleanly removed from _gates list
      expect(state.gates.contains(gate1), isFalse);

      // Simulate extended session (15 seconds)
      for (int step = 0; step < 300; step++) {
        for (final gate in state.gates) {
          if (!gate.isPassed && gate.y >= state.shipCenterY - 50.0) {
            while (state.shipColor != gate.color) {
              state.cycleColor();
            }
            break;
          }
        }
        state.updateGame(0.05);
      }
      await tester.pump();

      // Confirm all gates beyond 660.0 have been removed
      for (final gate in state.gates) {
        expect(gate.y, lessThanOrEqualTo(660.0));
      }
      // Total active gates in flight stays strictly bounded
      expect(state.gates.length, lessThanOrEqualTo(4));
      expect(state.isGameOver, isFalse);
    });
  });
}
