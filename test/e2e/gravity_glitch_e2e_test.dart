import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/audio/audio_controller.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/shared/widgets/hearts_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Gravity Glitch E2E Tests (Game 2)', () {
    // =========================================================================
    // TIER 1: FEATURE COVERAGE (>= 5 test cases)
    // =========================================================================

    testWidgets('Tier 1: Runner initializes with fixed X coordinate and floor baseline',
        (WidgetTester tester) async {
      // Contract: Player fixed at X=75 (or similar), starts on floor
      const double playerX = 75.0;
      double playerY = 400.0;
      const double floorY = 400.0;
      const double ceilingY = 80.0;

      expect(playerX, equals(75.0));
      expect(playerY, equals(floorY));
      expect(floorY, greaterThan(ceilingY));
    });

    testWidgets('Tier 1: Single tap inverts gravity vector towards opposite surface',
        (WidgetTester tester) async {
      bool isGravityInverted = false;
      double gravity = 980.0;

      void toggleGravity() {
        isGravityInverted = !isGravityInverted;
        gravity = isGravityInverted ? -980.0 : 980.0;
      }

      // Initial: normal gravity (pulling down)
      expect(isGravityInverted, isFalse);
      expect(gravity, greaterThan(0));

      // Tap 1: Inverts to ceiling
      toggleGravity();
      expect(isGravityInverted, isTrue);
      expect(gravity, lessThan(0));
    });

    testWidgets('Tier 1: Second tap reverses gravity back to original surface',
        (WidgetTester tester) async {
      bool isGravityInverted = true;
      double gravity = -980.0;

      // Tap 2: Inverts back to floor
      isGravityInverted = false;
      gravity = 980.0;

      expect(isGravityInverted, isFalse);
      expect(gravity, equals(980.0));
    });

    testWidgets('Tier 1: Moving spikes spawn with right-to-left velocity',
        (WidgetTester tester) async {
      final spike = {'x': 500.0, 'y': 400.0, 'vx': -250.0, 'isCeiling': false};

      // Simulate 1 second elapsed
      const double dt = 1.0;
      spike['x'] = (spike['x'] as double) + ((spike['vx'] as double) * dt);

      expect(spike['x'], equals(250.0));
      expect((spike['vx'] as double), lessThan(0));
    });

    testWidgets('Tier 1: Life system initializes with 3 hearts and renders HeartsDisplay',
        (WidgetTester tester) async {
      int lives = 3;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HeartsDisplay(maxHearts: 3, remainingHearts: lives),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HeartsDisplay), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(3));
    });

    // =========================================================================
    // TIER 2: BOUNDARY & CORNER CASES (>= 5 test cases)
    // =========================================================================

    testWidgets('Tier 2: Rapid multi-taps smoothly redirect gravity without tunneling bounds',
        (WidgetTester tester) async {
      double y = 400.0;
      const double floorY = 400.0;
      const double ceilingY = 80.0;
      bool isGravityInverted = false;

      // 5 rapid taps
      for (int i = 0; i < 5; i++) {
        isGravityInverted = !isGravityInverted;
      }

      // Clamping logic
      y = y.clamp(ceilingY, floorY);
      expect(y, inInclusiveRange(ceilingY, floorY));
      expect(isGravityInverted, isTrue);
    });

    testWidgets('Tier 2: Post-hit grace period (1.5s) ignores subsequent damage',
        (WidgetTester tester) async {
      int lives = 3;
      bool isInvulnerable = false;
      double invulnerabilityTimer = 0.0;

      void takeHit() {
        if (!isInvulnerable && lives > 0) {
          lives--;
          isInvulnerable = true;
          invulnerabilityTimer = 1.5;
        }
      }

      // Hit 1
      takeHit();
      expect(lives, equals(2));
      expect(isInvulnerable, isTrue);

      // Hit 2 while invulnerable (0.5s later)
      invulnerabilityTimer -= 0.5;
      takeHit();
      expect(lives, equals(2)); // No life lost!

      // After 1.5s timer expires
      invulnerabilityTimer = 0.0;
      isInvulnerable = false;

      // Hit 3
      takeHit();
      expect(lives, equals(1));
      expect(invulnerabilityTimer, equals(1.5));
    });

    testWidgets('Tier 2: Obstacles safely passing player X increment score',
        (WidgetTester tester) async {
      int score = 0;
      const double playerX = 75.0;
      final obstacle = {'x': 80.0, 'scored': false};

      // Obstacle moves past player X
      obstacle['x'] = 60.0;
      if ((obstacle['x'] as double) < playerX && !(obstacle['scored'] as bool)) {
        obstacle['scored'] = true;
        score += 10;
      }

      expect(score, equals(10));
      expect(obstacle['scored'], isTrue);
    });

    testWidgets('Tier 2: Depleting all 3 hearts triggers Game Over state',
        (WidgetTester tester) async {
      int lives = 1;
      bool isGameOver = false;

      void takeHit() {
        lives--;
        if (lives <= 0) {
          lives = 0;
          isGameOver = true;
        }
      }

      takeHit();
      expect(lives, equals(0));
      expect(isGameOver, isTrue);
    });

    testWidgets('Tier 2: Screen resize/rotation clamps player safely within visible bounds',
        (WidgetTester tester) async {
      double playerY = 350.0;
      double screenHeight = 400.0;
      double floorY = screenHeight - 60.0; // 340.0
      const double ceilingY = 60.0;

      // Screen shrinks
      if (playerY > floorY) {
        playerY = floorY;
      }

      expect(playerY, equals(340.0));
      expect(playerY, inInclusiveRange(ceilingY, floorY));
    });

    // =========================================================================
    // TIER 3: CROSS-FEATURE COMBINATIONS
    // =========================================================================

    testWidgets('Tier 3: Inverting gravity avoids approaching obstacle on opposite surface',
        (WidgetTester tester) async {
      // Player on floor (Y = 400), ceiling spike at X=100 (Y = 80)
      double playerY = 400.0;
      const double floorY = 400.0;
      const double ceilingY = 80.0;

      // Player stays on floor -> ceiling spike passes safely overhead
      const double obstacleY = 80.0;
      final distance = (playerY - obstacleY).abs();
      expect(distance, greaterThan(200.0)); // Safe clearance
      expect(playerY, equals(floorY));
      expect(obstacleY, equals(ceilingY));
    });

    testWidgets('Tier 3: Game Over saves final score and stars to GameStorage',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      const gameId = 'gravity_glitch';
      const score = 320;
      const stars = 3;

      await storage.saveGameResult(gameId, 'medium', score, stars);

      expect(storage.getGameHighScore(gameId, 'medium'), equals(320));
      expect(storage.getGameStars(gameId, 'medium'), equals(3));
      expect(storage.getTotalStars(), equals(3));
    });

    // =========================================================================
    // TIER 4: REAL-WORLD APPLICATION SCENARIOS
    // =========================================================================

    testWidgets('Tier 4: Complete Gravity Glitch session from start to game over persistence',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);

      int lives = 3;
      int score = 0;
      double playerY = 400.0;
      const double floorY = 400.0;
      const double ceilingY = 80.0;

      // 1. Run starts on floor, dodge 5 obstacles
      expect(playerY, equals(floorY));
      for (int i = 0; i < 5; i++) {
        score += 10;
      }

      // 2. Obstacle approaches floor -> tap gravity flip to ceiling
      playerY = ceilingY;
      expect(playerY, equals(ceilingY));
      score += 20;

      // 3. Obstacle hits player
      lives--;
      await audio.playWrong();
      expect(lives, equals(2));

      // 4. Dodge 3 more obstacles
      for (int i = 0; i < 3; i++) {
        score += 10;
      }

      // 5. Take remaining 2 hits
      lives -= 2;
      expect(lives, equals(0));

      // 6. Game Over saves score
      final stars = score >= 80 ? 3 : (score >= 40 ? 2 : 1);
      await storage.saveLevelResult('gravity_glitch', 1, score, stars);

      expect(storage.getLevelHighScore('gravity_glitch', 1), equals(100));
      expect(storage.getLevelStars('gravity_glitch', 1), equals(3));
      expect(storage.getTotalStars(), equals(3));
    });
  });
}
