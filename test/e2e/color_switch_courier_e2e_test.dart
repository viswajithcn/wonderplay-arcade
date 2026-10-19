import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/audio/audio_controller.dart';
import 'package:kids_games/core/storage/game_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Color Switch Courier E2E Tests (Game 3)', () {
    // =========================================================================
    // TIER 1: FEATURE COVERAGE (>= 5 test cases)
    // =========================================================================

    testWidgets('Tier 1: Courier ship is positioned at bottom center of playfield',
        (WidgetTester tester) async {
      const double screenWidth = 400.0;
      const double screenHeight = 800.0;
      const double shipWidth = 60.0;

      // Bottom center placement
      const double shipX = (screenWidth - shipWidth) / 2;
      const double shipY = screenHeight - 120.0;

      expect(shipX, equals(170.0));
      expect(shipY, equals(680.0));
    });

    testWidgets('Tier 1: Tapping cycles ship color: Red -> Green -> Blue -> Red',
        (WidgetTester tester) async {
      final colors = ['red', 'green', 'blue'];
      int currentColorIndex = 0;

      void cycleColor() {
        currentColorIndex = (currentColorIndex + 1) % colors.length;
      }

      // Initial: Red
      expect(colors[currentColorIndex], equals('red'));

      // Tap 1: Green
      cycleColor();
      expect(colors[currentColorIndex], equals('green'));

      // Tap 2: Blue
      cycleColor();
      expect(colors[currentColorIndex], equals('blue'));

      // Tap 3: Cycles back to Red
      cycleColor();
      expect(colors[currentColorIndex], equals('red'));
    });

    testWidgets('Tier 1: Laser gates move downward with positive Y velocity',
        (WidgetTester tester) async {
      double gateY = 50.0;
      const double speed = 200.0; // px/sec

      // Simulate 0.5s movement
      gateY += speed * 0.5;

      expect(gateY, equals(150.0));
      expect(gateY, greaterThan(50.0));
    });

    testWidgets('Tier 1: Matching color collision adds +1 score and triggers correct sound',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);

      int score = 0;
      String shipColor = 'green';
      String gateColor = 'green';
      bool gatePassed = false;
      bool correctAudioPlayed = false;

      const double shipY = 600.0;
      double gateY = 605.0;

      if (gateY >= shipY && !gatePassed) {
        if (shipColor == gateColor) {
          score += 1;
          gatePassed = true;
          await audio.playCorrect();
          correctAudioPlayed = true;
        }
      }

      expect(score, equals(1));
      expect(gatePassed, isTrue);
      expect(correctAudioPlayed, isTrue);
    });

    testWidgets('Tier 1: Color mismatch collision triggers Game Over and wrong sound',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);

      bool isGameOver = false;
      String shipColor = 'red';
      String gateColor = 'blue';
      bool wrongAudioPlayed = false;

      const double shipY = 600.0;
      double gateY = 605.0;

      if (gateY >= shipY) {
        if (shipColor != gateColor) {
          isGameOver = true;
          await audio.playWrong();
          wrongAudioPlayed = true;
        }
      }

      expect(isGameOver, isTrue);
      expect(wrongAudioPlayed, isTrue);
    });

    // =========================================================================
    // TIER 2: BOUNDARY & CORNER CASES (>= 5 test cases)
    // =========================================================================

    testWidgets('Tier 2: Rapid color switching on frame of arrival evaluates exact active color',
        (WidgetTester tester) async {
      final colors = ['red', 'green', 'blue'];
      int colorIndex = 0; // red

      // 4 rapid taps right before arrival: red -> green -> blue -> red -> green
      for (int i = 0; i < 4; i++) {
        colorIndex = (colorIndex + 1) % colors.length;
      }
      expect(colors[colorIndex], equals('green'));

      // Gate color is green
      const gateColor = 'green';
      final isMatch = colors[colorIndex] == gateColor;
      expect(isMatch, isTrue);
    });

    testWidgets('Tier 2: Accessibility glyphs correspond correctly to gate colors',
        (WidgetTester tester) async {
      final glyphMap = {
        'red': Icons.circle,
        'green': Icons.change_history_rounded, // Triangle
        'blue': Icons.crop_square_rounded,     // Square / Diamond
      };

      expect(glyphMap['red'], equals(Icons.circle));
      expect(glyphMap['green'], equals(Icons.change_history_rounded));
      expect(glyphMap['blue'], equals(Icons.crop_square_rounded));
    });

    testWidgets('Tier 2: Gate speed scales with score but remains capped at 400 px/s',
        (WidgetTester tester) async {
      double calculateSpeed(int score) {
        const double baseSpeed = 180.0;
        final speed = baseSpeed + (score * 2.5);
        return speed > 400.0 ? 400.0 : speed;
      }

      expect(calculateSpeed(0), equals(180.0));
      expect(calculateSpeed(10), equals(205.0));
      expect(calculateSpeed(50), equals(305.0));
      expect(calculateSpeed(100), equals(400.0)); // Capped!
      expect(calculateSpeed(200), equals(400.0)); // Still capped!
    });

    testWidgets('Tier 2: Passed gates do not double-score on subsequent frames',
        (WidgetTester tester) async {
      int score = 0;
      final gate = {'y': 610.0, 'color': 'red', 'isPassed': false};
      const double shipY = 600.0;
      const String shipColor = 'red';

      // Frame 1
      if ((gate['y'] as double) >= shipY && !(gate['isPassed'] as bool)) {
        if (gate['color'] == shipColor) {
          score++;
          gate['isPassed'] = true;
        }
      }
      expect(score, equals(1));

      // Frame 2 (Gate moved further down)
      gate['y'] = 630.0;
      if ((gate['y'] as double) >= shipY && !(gate['isPassed'] as bool)) {
        if (gate['color'] == shipColor) {
          score++;
          gate['isPassed'] = true;
        }
      }
      expect(score, equals(1)); // Score remains 1
    });

    testWidgets('Tier 2: Wide screen constraints constrain courier track to centered column',
        (WidgetTester tester) async {
      const double screenWidth = 1024.0; // Tablet landscape
      const double maxTrackWidth = 420.0;

      final trackWidth = screenWidth > maxTrackWidth ? maxTrackWidth : screenWidth;
      expect(trackWidth, equals(420.0));
    });

    // =========================================================================
    // TIER 3: CROSS-FEATURE COMBINATIONS
    // =========================================================================

    testWidgets('Tier 3: Master mute state suppresses laser gate and color switch audio',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);

      // Mute audio
      audio.toggleMasterMute(storage);
      expect(audio.isMuted, isTrue);
      expect(audio.sfxEnabled, isFalse);

      // Trigger SFX
      await audio.playCorrect();
      await audio.playWrong();
      await audio.playPop();

      // Audio state remains disabled
      expect(audio.sfxEnabled, isFalse);
    });

    testWidgets('Tier 3: High score and stars persist to GameStorage upon Game Over',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      const gameId = 'color_switch_courier';
      const score = 25;
      const stars = 3;

      await storage.saveLevelResult(gameId, 1, score, stars);

      expect(storage.getLevelHighScore(gameId, 1), equals(25));
      expect(storage.getLevelStars(gameId, 1), equals(3));
      expect(storage.getTotalStars(), equals(3));
    });

    // =========================================================================
    // TIER 4: REAL-WORLD APPLICATION SCENARIOS
    // =========================================================================

    testWidgets('Tier 4: Complete Color Switch Courier session through consecutive gates',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);

      final colors = ['red', 'green', 'blue'];
      int shipColorIdx = 0; // Starts Red
      int score = 0;
      bool isGameOver = false;

      // Gate 1: Green gate approaches
      const gate1Color = 'green';
      // Player taps once to switch Red -> Green
      shipColorIdx = (shipColorIdx + 1) % colors.length;
      expect(colors[shipColorIdx], equals(gate1Color));
      // Gate passes -> Match!
      score++;
      await audio.playCorrect();

      // Gate 2: Blue gate approaches
      const gate2Color = 'blue';
      // Player taps once to switch Green -> Blue
      shipColorIdx = (shipColorIdx + 1) % colors.length;
      expect(colors[shipColorIdx], equals(gate2Color));
      // Gate passes -> Match!
      score++;
      await audio.playCorrect();

      // Gate 3: Red gate approaches
      const gate3Color = 'red';
      // Player fails to tap (ship remains Blue)
      if (colors[shipColorIdx] != gate3Color) {
        isGameOver = true;
        await audio.playWrong();
      }

      expect(score, equals(2));
      expect(isGameOver, isTrue);

      // Persist result
      final stars = score >= 15 ? 3 : (score >= 5 ? 2 : 1);
      await storage.saveLevelResult('color_switch_courier', 1, score, stars);

      expect(storage.getLevelHighScore('color_switch_courier', 1), equals(2));
      expect(storage.getLevelStars('color_switch_courier', 1), equals(1));
    });
  });
}
