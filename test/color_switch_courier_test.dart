import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/audio/audio_controller.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/color_switch_courier/models/courier_color.dart';
import 'package:kids_games/games/color_switch_courier/models/laser_gate.dart';
import 'package:kids_games/games/color_switch_courier/views/color_switch_courier_screen.dart';
import 'package:kids_games/games/color_switch_courier/widgets/courier_ship_widget.dart';
import 'package:kids_games/games/color_switch_courier/widgets/laser_gate_widget.dart';
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

  group('CourierColor Model Tests', () {
    test('Enum has red, green, blue values', () {
      expect(CourierColor.values.length, equals(3));
      expect(CourierColor.red.name, equals('red'));
      expect(CourierColor.green.name, equals('green'));
      expect(CourierColor.blue.name, equals('blue'));
    });

    test('Color values match project spec', () {
      expect(CourierColor.red.color, equals(const Color(0xFFFF5252)));
      expect(CourierColor.green.color, equals(const Color(0xFF66BB6A)));
      expect(CourierColor.blue.color, equals(const Color(0xFF29B6F6)));
    });

    test('Accessibility symbols match spec and e2e tests', () {
      expect(CourierColor.red.symbol, equals(Icons.circle));
      expect(CourierColor.green.symbol, equals(Icons.change_history_rounded));
      expect(CourierColor.blue.symbol, equals(Icons.crop_square_rounded));
    });

    test('next() cycles Red -> Green -> Blue -> Red', () {
      expect(CourierColor.red.next(), equals(CourierColor.green));
      expect(CourierColor.green.next(), equals(CourierColor.blue));
      expect(CourierColor.blue.next(), equals(CourierColor.red));
    });

    test('prev() cycles reverse order', () {
      expect(CourierColor.red.prev(), equals(CourierColor.blue));
      expect(CourierColor.blue.prev(), equals(CourierColor.green));
      expect(CourierColor.green.prev(), equals(CourierColor.red));
    });

    test('fromIndex and fromString helpers', () {
      expect(CourierColor.fromIndex(0), equals(CourierColor.red));
      expect(CourierColor.fromIndex(1), equals(CourierColor.green));
      expect(CourierColor.fromIndex(2), equals(CourierColor.blue));
      expect(CourierColor.fromIndex(3), equals(CourierColor.red));

      expect(CourierColor.fromString('RED'), equals(CourierColor.red));
      expect(CourierColor.fromString('green'), equals(CourierColor.green));
      expect(CourierColor.fromString('BLUE'), equals(CourierColor.blue));
      expect(CourierColor.fromString('unknown'), equals(CourierColor.red));
    });

    test('Accent and glow colors are defined', () {
      for (final c in CourierColor.values) {
        expect(c.accentColor, isNotNull);
        expect(c.glowColor, isNotNull);
        expect(c.displayName.isNotEmpty, isTrue);
      }
    });
  });

  group('LaserGate Model Tests', () {
    test('Constructs LaserGate with valid defaults', () {
      final gate = LaserGate(
        id: 'gate_1',
        y: 100.0,
        color: CourierColor.green,
        speed: 200.0,
      );

      expect(gate.id, equals('gate_1'));
      expect(gate.y, equals(100.0));
      expect(gate.color, equals(CourierColor.green));
      expect(gate.speed, equals(200.0));
      expect(gate.isPassed, isFalse);
      expect(gate.height, equals(24.0));
    });

    test('update() moves gate downward with speed * dt', () {
      final gate = LaserGate(
        id: 'gate_1',
        y: 50.0,
        color: CourierColor.red,
        speed: 150.0,
      );

      gate.update(0.5); // 50 + 150 * 0.5 = 125
      expect(gate.y, equals(125.0));

      gate.update(0.2); // 125 + 150 * 0.2 = 155
      expect(gate.y, equals(155.0));
    });

    test('calculateSpeed scales with score and caps at 400 px/s', () {
      expect(LaserGate.calculateSpeed(0), equals(180.0));
      expect(LaserGate.calculateSpeed(10), equals(205.0));
      expect(LaserGate.calculateSpeed(50), equals(305.0));
      expect(LaserGate.calculateSpeed(100), equals(400.0));
      expect(LaserGate.calculateSpeed(250), equals(400.0));
    });

    test('copyWith copies and overrides correctly', () {
      final original = LaserGate(
        id: 'g1',
        y: 10.0,
        color: CourierColor.blue,
        speed: 180.0,
      );

      final copy = original.copyWith(y: 45.0, isPassed: true);
      expect(copy.id, equals('g1'));
      expect(copy.y, equals(45.0));
      expect(copy.color, equals(CourierColor.blue));
      expect(copy.speed, equals(180.0));
      expect(copy.isPassed, isTrue);
    });
  });

  group('CourierShipWidget and LaserGateWidget Component Tests', () {
    testWidgets('CourierShipWidget renders active color and accessibility glyph',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CourierShipWidget(
                color: CourierColor.red,
                size: 64.0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CourierShipWidget), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsOneWidget);

      // Rebuild with Green
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CourierShipWidget(
                color: CourierColor.green,
                size: 64.0,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.change_history_rounded), findsOneWidget);
    });

    testWidgets('LaserGateWidget renders beam and accessibility icon',
        (WidgetTester tester) async {
      final gate = LaserGate(
        id: 'gate_test',
        y: 200.0,
        color: CourierColor.blue,
        speed: 200.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: LaserGateWidget(
                gate: gate,
                width: 380.0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LaserGateWidget), findsOneWidget);
      expect(find.byIcon(Icons.crop_square_rounded), findsOneWidget);
    });
  });

  group('ColorSwitchCourierScreen Widget & Game Logic Tests', () {
    late GameStorage storage;

    setUp(() async {
      storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);
    });

    testWidgets('Mounts screen and displays top HUD and ship',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
            difficulty: GameDifficulty.easy,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ColorSwitchCourierScreen), findsOneWidget);
      expect(find.byKey(const Key('courier_ship')), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.text('0'), findsWidgets); // Score 0
    });

    testWidgets('Tapping screen cycles ship color',
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

      // Initial color is Red
      expect(state.shipColor, equals(CourierColor.red));

      // Tap 1 -> Green
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(state.shipColor, equals(CourierColor.green));

      // Tap 2 -> Blue
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(state.shipColor, equals(CourierColor.blue));

      // Tap 3 -> Cycles to Red
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(state.shipColor, equals(CourierColor.red));
    });

    testWidgets('Matching color collision scores +1 and marks gate isPassed',
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

      // Set ship color to Green
      state.cycleColor();
      expect(state.shipColor, equals(CourierColor.green));

      // Spawn a green gate right at the ship threshold
      final gate = state.spawnGate(
        color: CourierColor.green,
        y: state.shipCenterY + 2.0,
      );

      // Trigger collision check
      state.checkCollisions();
      await tester.pump(const Duration(milliseconds: 250));

      expect(state.score, equals(1));
      expect(gate.isPassed, isTrue);
      expect(state.isGameOver, isFalse);

      // Consecutive collision check does not double-score
      state.checkCollisions();
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.score, equals(1));
    });

    testWidgets('Mismatch color collision triggers Game Over and persists result',
        (WidgetTester tester) async {
      int? reportedScore;

      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
            onGameOver: (score) => reportedScore = score,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Ship color is Red
      expect(state.shipColor, equals(CourierColor.red));

      // Spawn a Blue gate at the collision threshold
      state.spawnGate(
        color: CourierColor.blue,
        y: state.shipCenterY + 5.0,
      );

      // Check collision
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      expect(reportedScore, equals(0));
      expect(find.byType(GameOverDialog), findsOneWidget);
    });

    testWidgets('Pause and Resume functionality toggles pause state and overlay',
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

      expect(state.isPaused, isFalse);
      expect(find.text('PAUSED'), findsNothing);

      // Tap pause button
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      expect(state.isPaused, isTrue);
      expect(find.text('PAUSED'), findsOneWidget);

      // Tap Resume button in overlay
      await tester.tap(find.text('Resume'));
      await tester.pump();

      expect(state.isPaused, isFalse);
      expect(find.text('PAUSED'), findsNothing);
    });

    testWidgets('Restart resets state cleanly',
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

      // Score 2 points with matching gates
      state.spawnGate(color: CourierColor.red, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pump(const Duration(milliseconds: 250));
      expect(state.score, equals(1));

      // Restart game
      state.restartGame();
      await tester.pump(const Duration(milliseconds: 50));

      expect(state.score, equals(0));
      expect(state.gates.isEmpty, isTrue);
      expect(state.isGameOver, isFalse);
      expect(state.isPaused, isFalse);
    });

    testWidgets('Static builder creates screen instance',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(),
        ),
      );
      final widget = ColorSwitchCourierScreen.builder(
        tester.element(find.byType(SizedBox)),
        GameDifficulty.hard,
        storage: storage,
      );

      expect(widget, isA<ColorSwitchCourierScreen>());
      final courierScreen = widget as ColorSwitchCourierScreen;
      expect(courierScreen.difficulty, equals(GameDifficulty.hard));
    });

    testWidgets('Multi-gate progression calculates stars and persists to storage',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ColorSwitchCourierScreen(
            storage: storage,
            difficulty: GameDifficulty.medium,
          ),
        ),
      );
      await tester.pump();

      final state = tester.state<ColorSwitchCourierScreenState>(
        find.byType(ColorSwitchCourierScreen),
      );

      // Simulate matching 16 gates in succession
      for (int i = 0; i < 16; i++) {
        final gate = state.spawnGate(color: state.shipColor, y: state.shipCenterY);
        state.checkCollisions();
        expect(gate.isPassed, isTrue);
        // Cycle to next color for next gate
        state.cycleColor();
      }

      expect(state.score, equals(16));

      // Now spawn mismatch to trigger Game Over
      final mismatchGateColor = state.shipColor == CourierColor.red
          ? CourierColor.green
          : CourierColor.red;
      state.spawnGate(color: mismatchGateColor, y: state.shipCenterY);
      state.checkCollisions();
      await tester.pumpAndSettle();

      expect(state.isGameOver, isTrue);
      expect(storage.getLevelHighScore('color_switch_courier', 1), equals(16));
      expect(storage.getLevelStars('color_switch_courier', 1), equals(3));
    });
  });
}
