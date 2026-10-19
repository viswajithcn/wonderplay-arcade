import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/audio/audio_controller.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/mini_game_registry.dart';
import 'package:kids_games/hub/views/game_hub_screen.dart';
import 'package:kids_games/hub/widgets/game_card.dart';
import 'package:kids_games/models/mini_game_model.dart';
import 'package:kids_games/shared/widgets/game_over_dialog.dart';
import 'package:kids_games/shared/widgets/victory_dialog.dart';
import 'package:kids_games/shared/widgets/star_rating_display.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Hub & Registry Cross-Feature Integration E2E Tests', () {
    // =========================================================================
    // TIER 1: FEATURE COVERAGE (>= 5 test cases)
    // =========================================================================

    testWidgets('Tier 1: MiniGameRegistry returns valid metadata with distinct IDs and categories',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final games = MiniGameRegistry.getGames(storage);

      expect(games.length, greaterThanOrEqualTo(2));
      final ids = games.map((g) => g.id).toSet();
      expect(ids.length, equals(games.length), reason: 'Game IDs must be unique');

      for (final game in games) {
        expect(game.title, isNotEmpty);
        expect(game.subtitle, isNotEmpty);
        expect(game.ageRecommendation, isNotEmpty);
      }
    });

    testWidgets('Tier 1: GameCard renders title, subtitle, and age badge accurately',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final testMetadata = MiniGameMetadata(
        id: 'test_game',
        title: 'Super Math',
        subtitle: 'Solve fast equations!',
        description: 'A fun test game for kids.',
        category: GameCategory.math,
        icon: Icons.calculate_rounded,
        primaryColor: const Color(0xFF29B6F6),
        accentColor: const Color(0xFF0288D1),
        ageRecommendation: 'Ages 5–10',
        isAvailable: true,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GameCard(
            game: testMetadata,
            storage: storage,
            onPlayGame: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Super Math'), findsOneWidget);
      expect(find.text('Solve fast equations!'), findsOneWidget);
      expect(find.text('Ages 5–10'), findsOneWidget);
    });

    testWidgets('Tier 1: Category filtering partitions games into relevant buckets',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final games = MiniGameRegistry.getGames(storage);

      final mathGames = games.where((g) => g.category == GameCategory.math).toList();
      final memoryGames = games.where((g) => g.category == GameCategory.memory).toList();
      final puzzleGames = games.where((g) => g.category == GameCategory.puzzles).toList();
      final actionGames = games.where((g) => g.category == GameCategory.action).toList();

      expect(mathGames.any((g) => g.id == 'math_bubble_pop'), isTrue);
      expect(memoryGames.any((g) => g.id == 'animal_memory_match'), isTrue);
      expect(puzzleGames.any((g) => g.id == 'merge_blacksmith'), isTrue);
      expect(actionGames.any((g) => g.id == 'color_switch_courier'), isTrue);
      expect(games.any((g) => g.id == 'gravity_glitch'), isFalse);
    });

    testWidgets('Tier 1: Active new games are registered, available, and have valid screen builders',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final games = MiniGameRegistry.getGames(storage);

      final blacksmith = games.firstWhere((g) => g.id == 'merge_blacksmith');
      expect(blacksmith.title, equals('Merge Blacksmith'));
      expect(blacksmith.subtitle, equals('Forge & craft legendary tools!'));
      expect(blacksmith.category, equals(GameCategory.puzzles));
      expect(blacksmith.isAvailable, isTrue);
      expect(blacksmith.builder, isNotNull);
      expect(blacksmith.screenBuilder, isNotNull);

      final courier = games.firstWhere((g) => g.id == 'color_switch_courier');
      expect(courier.title, equals('Color Switch Courier'));
      expect(courier.subtitle, equals('Match laser gate colors at high speed!'));
      expect(courier.category, equals(GameCategory.action));
      expect(courier.isAvailable, isTrue);
      expect(courier.builder, isNotNull);
      expect(courier.screenBuilder, isNotNull);
    });

    testWidgets('Tier 1: Game difficulty ratings are defined and provide age and color metadata',
        (WidgetTester tester) async {
      expect(GameDifficulty.values.length, equals(3));
      expect(GameDifficulty.easy.title, equals('Easy'));
      expect(GameDifficulty.medium.title, equals('Medium'));
      expect(GameDifficulty.hard.title, equals('Hard'));

      expect(GameDifficulty.easy.color, isA<Color>());
      expect(GameDifficulty.medium.color, isA<Color>());
      expect(GameDifficulty.hard.color, isA<Color>());
    });

    testWidgets('Tier 1: StarRatingDisplay renders correct number of active stars',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: StarRatingDisplay(stars: 2),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(StarRatingDisplay), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    // =========================================================================
    // TIER 2: BOUNDARY & CORNER CASES (>= 5 test cases)
    // =========================================================================

    testWidgets('Tier 2: Unavailable/Coming-soon games display lock badge and disable interaction',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final disabledMetadata = const MiniGameMetadata(
        id: 'locked_game',
        title: 'Future Quest',
        subtitle: 'Coming soon!',
        description: 'Not yet playable.',
        category: GameCategory.action,
        icon: Icons.lock_clock_rounded,
        primaryColor: Colors.grey,
        accentColor: Colors.black45,
        ageRecommendation: 'Ages 6+',
        isAvailable: false,
      );

      bool gameLaunched = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GameCard(
            game: disabledMetadata,
            storage: storage,
            onPlayGame: (_) => gameLaunched = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Soon'), findsOneWidget);
      expect(find.byIcon(Icons.lock_clock_rounded), findsAtLeastNWidgets(1));
      // Tapping unavailable card should not trigger gameplay launch
      await tester.tap(find.byType(GameCard));
      await tester.pumpAndSettle();
      expect(gameLaunched, isFalse);
    });

    testWidgets('Tier 2: GameCard renders cleanly with zero stars on fresh unplayed game',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final testMetadata = MiniGameMetadata(
        id: 'unplayed_game',
        title: 'Unplayed Adventure',
        subtitle: 'Brand new game!',
        description: 'No scores yet.',
        category: GameCategory.action,
        icon: Icons.games_rounded,
        primaryColor: Colors.green,
        accentColor: Colors.green.shade800,
        ageRecommendation: 'Ages 4+',
        isAvailable: true,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GameCard(
            game: testMetadata,
            storage: storage,
            onPlayGame: (_) {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(GameCard), findsOneWidget);
    });

    testWidgets('Tier 2: Rapid switching of categories on Hub does not drop cards or crash',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Switch between visible categories
      final visibleTabs = ['All Games', 'Math & Numbers', 'Memory & Logic'];
      for (int i = 0; i < 3; i++) {
        for (final label in visibleTabs) {
          await tester.tap(find.text(label));
          await tester.pump(const Duration(milliseconds: 40));
        }
      }
      await tester.pumpAndSettle();

      expect(find.byType(GameHubScreen), findsOneWidget);
    });

    testWidgets('Tier 2: VictoryDialog renders celebration result and responds to exit callback',
        (WidgetTester tester) async {
      bool exited = false;
      final result = const GameResult(
        score: 300,
        totalQuestions: 10,
        correctAnswers: 10,
        stars: 3,
        difficulty: GameDifficulty.medium,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                VictoryDialog.show(
                  context: context,
                  result: result,
                  onPlayAgain: () {},
                  onExit: () => exited = true,
                );
              },
              child: const Text('Show Victory'),
            ),
          ),
        ),
      ));
      await tester.pump();

      await tester.tap(find.text('Show Victory'));
      // Pump frame for dialog entrance without waiting on 3s confetti animation loop
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Super Genius! 🌟'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);

      // Tap Home (Exit) button
      final homeBtn = find.text('Home');
      expect(homeBtn, findsOneWidget);
      await tester.tap(homeBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(exited, isTrue);
    });

    testWidgets('Tier 2: GameOverDialog renders score and triggers retry and exit callbacks',
        (WidgetTester tester) async {
      bool retried = false;
      bool exited = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                GameOverDialog.show(
                  context: context,
                  score: 120,
                  questionsAnswered: 4,
                  onRetry: () => retried = true,
                  onExit: () => exited = true,
                );
              },
              child: const Text('Show GameOver'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show GameOver'));
      await tester.pumpAndSettle();

      expect(find.text('Out of Hearts!'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);

      // Tap Try Again!
      final retryBtn = find.text('Try Again!');
      expect(retryBtn, findsOneWidget);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(retried, isTrue);
      expect(exited, isFalse);
    });

    // =========================================================================
    // TIER 3: CROSS-FEATURE COMBINATIONS
    // =========================================================================

    testWidgets('Tier 3: Playing multiple games accumulates stars into global total',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();

      expect(storage.getTotalStars(), equals(0));

      // Game 1 completes with 3 stars
      await storage.saveLevelResult('game_alpha', 1, 100, 3);
      expect(storage.getTotalStars(), equals(3));

      // Game 2 completes with 2 stars
      await storage.saveLevelResult('game_beta', 1, 80, 2);
      expect(storage.getTotalStars(), equals(5));

      // Replaying Game 2 and improving from 2 stars to 3 stars
      await storage.saveLevelResult('game_beta', 1, 120, 3);
      expect(storage.getTotalStars(), equals(6));
    });

    testWidgets('Tier 3: Audio mute preference persists across game navigation',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);

      // Mute audio
      audio.toggleMasterMute(storage);
      expect(audio.isMuted, isTrue);

      // Re-initialize AudioController as if navigating or reopening
      final newAudioInstance = AudioController();
      await newAudioInstance.init(storage);
      expect(newAudioInstance.isMuted, isTrue);
      expect(storage.getSfxEnabled(), isFalse);
    });

    // =========================================================================
    // TIER 4: REAL-WORLD APPLICATION SCENARIOS
    // =========================================================================

    testWidgets('Tier 4: Full arcade lifecycle from Hub discovery to multi-game progression',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();

      // Launch Hub
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget); // 0 stars initially

      // Simulate completing a level and awarding 3 stars
      await storage.saveLevelResult('math_bubble_pop', 1, 200, 3);

      // Relaunch or refresh Hub
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Total stars in header must now reflect 3
      expect(find.text('3'), findsOneWidget);
    });
  });
}
