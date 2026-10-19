import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/audio/audio_controller.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/mini_game_registry.dart';
import 'package:kids_games/hub/views/game_hub_screen.dart';
import 'package:kids_games/hub/widgets/game_card.dart';
import 'package:kids_games/models/mini_game_model.dart';
import 'package:kids_games/games/math_bubble_pop/views/math_level_select_screen.dart';
import 'package:kids_games/games/animal_memory_match/views/memory_level_select_screen.dart';
import 'package:kids_games/games/merge_blacksmith/views/merge_blacksmith_screen.dart';
import 'package:kids_games/games/gravity_glitch/views/gravity_glitch_screen.dart';
import 'package:kids_games/games/color_switch_courier/views/color_switch_courier_screen.dart';
import 'package:kids_games/games/color_switch_courier/widgets/courier_ship_widget.dart';
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

  group('Challenger M5-1: MiniGameRegistry Integrity & Completeness', () {
    test('Registry returns all 4 playable games and 2 placeholders with distinct properties', () async {
      final storage = await GameStorage.init();
      final games = MiniGameRegistry.getGames(storage);

      // Verify total count
      expect(games.length, equals(6), reason: 'Expected 4 playable games + 2 placeholders');

      // Verify unique IDs
      final ids = games.map((g) => g.id).toSet();
      expect(ids.length, equals(6), reason: 'All game IDs must be unique');

      // Verify the 4 required playable game IDs (gravity_glitch is hidden)
      const requiredPlayableIds = [
        'math_bubble_pop',
        'animal_memory_match',
        'merge_blacksmith',
        'color_switch_courier',
      ];

      for (final requiredId in requiredPlayableIds) {
        final game = games.firstWhere(
          (g) => g.id == requiredId,
          orElse: () => throw StateError('Required game $requiredId missing from registry'),
        );

        expect(game.isAvailable, isTrue, reason: '$requiredId must be marked as available');
        expect(game.builder, isNotNull, reason: '$requiredId must have non-null builder');
        expect(game.screenBuilder, isNotNull, reason: '$requiredId must have non-null screenBuilder alias');
        expect(game.title, isNotEmpty);
        expect(game.subtitle, isNotEmpty);
        expect(game.description, isNotEmpty);
        expect(game.ageRecommendation, isNotEmpty);
        expect(game.primaryColor, isNotNull);
        expect(game.accentColor, isNotNull);
        expect(game.icon, isNotNull);
      }

      // Verify the 2 placeholders
      const placeholderIds = ['shape_sorter', 'balloon_pop'];
      for (final pId in placeholderIds) {
        final game = games.firstWhere((g) => g.id == pId);
        expect(game.isAvailable, isFalse, reason: 'Placeholder $pId must not be available');
        expect(game.builder, isNull, reason: 'Placeholder $pId must have null builder');
      }
    });

    test('Registry screenBuilder and builder references are congruent', () async {
      final storage = await GameStorage.init();
      final games = MiniGameRegistry.getGames(storage);

      for (final game in games) {
        expect(game.screenBuilder, equals(game.builder));
      }
    });
  });

  group('Challenger M5-1: Direct Screen Builder Invocations & Mounting Across Difficulties', () {
    late GameStorage storage;

    setUp(() async {
      storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);
      audio.setBgmEnabled(false, storage);
    });

    testWidgets('1. Math Bubble Pop builder mounts cleanly for all difficulties',
        (WidgetTester tester) async {
      final games = MiniGameRegistry.getGames(storage);
      final meta = games.firstWhere((g) => g.id == 'math_bubble_pop');

      for (final diff in GameDifficulty.values) {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (ctx) => meta.builder!(ctx, diff),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(MathLevelSelectScreen), findsOneWidget);
        expect(find.text('Select Level'), findsOneWidget);
      }
    });

    testWidgets('2. Animal Memory Match builder mounts cleanly for all difficulties',
        (WidgetTester tester) async {
      final games = MiniGameRegistry.getGames(storage);
      final meta = games.firstWhere((g) => g.id == 'animal_memory_match');

      for (final diff in GameDifficulty.values) {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (ctx) => meta.builder!(ctx, diff),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(MemoryLevelSelectScreen), findsOneWidget);
        expect(find.text('Select Memory Level'), findsOneWidget);
      }
    });

    testWidgets('3. Merge Blacksmith builder mounts cleanly for all difficulties and renders 20 slots',
        (WidgetTester tester) async {
      final games = MiniGameRegistry.getGames(storage);
      final meta = games.firstWhere((g) => g.id == 'merge_blacksmith');

      for (final diff in GameDifficulty.values) {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (ctx) => meta.builder!(ctx, diff),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(MergeBlacksmithScreen), findsOneWidget);
        expect(find.text('Merge Blacksmith ⚒️'), findsOneWidget);
        expect(find.textContaining('Orders:'), findsOneWidget);
        // Verify 20 ForgeSlotWidget DragTargets + 1 CustomerOrderBanner DragTarget
        expect(find.byWidgetPredicate((w) => w is DragTarget), findsAtLeastNWidgets(20));
      }
    });

    testWidgets('4. Gravity Glitch is hidden from registry while direct GravityGlitchScreen still mounts cleanly',
        (WidgetTester tester) async {
      final games = MiniGameRegistry.getGames(storage);
      expect(games.any((g) => g.id == 'gravity_glitch'), isFalse);

      for (final diff in GameDifficulty.values) {
        await tester.pumpWidget(MaterialApp(
          home: GravityGlitchScreen(storage: storage, difficulty: diff),
        ));
        // FlameGame requires pump frames
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(GravityGlitchScreen), findsOneWidget);
        expect(find.byWidgetPredicate((w) => w is GameWidget), findsOneWidget);
        expect(find.byType(HeartsDisplay), findsOneWidget);
      }
    });

    testWidgets('5. Color Switch Courier builder mounts cleanly for all difficulties with running ticker',
        (WidgetTester tester) async {
      final games = MiniGameRegistry.getGames(storage);
      final meta = games.firstWhere((g) => g.id == 'color_switch_courier');

      for (final diff in GameDifficulty.values) {
        await tester.pumpWidget(MaterialApp(
          home: Builder(
            builder: (ctx) => meta.builder!(ctx, diff),
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(ColorSwitchCourierScreen), findsOneWidget);
        expect(find.byType(CourierShipWidget), findsOneWidget);
        expect(find.text('Tap to switch color!'), findsOneWidget);
      }
    });
  });

  group('Challenger M5-1: Hub Navigation Stress & Route Transitions', () {
    late GameStorage storage;

    setUp(() async {
      storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);
      audio.setSfxEnabled(false, storage);
      audio.setBgmEnabled(false, storage);
    });

    testWidgets('Tapping each playable game card pushes route and popping returns to Hub',
        (WidgetTester tester) async {
      // Set sufficient viewport dimensions so all cards in the grid are laid out
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final games = MiniGameRegistry.getGames(storage);
      final playableGames = games.where((g) => g.isAvailable).toList();

      for (final game in playableGames) {
        await tester.pumpWidget(MaterialApp(
          home: GameHubScreen(storage: storage),
        ));
        await tester.pumpAndSettle();

        final cardFinder = find.widgetWithText(GameCard, game.title);
        expect(cardFinder, findsOneWidget, reason: 'Card for ${game.title} must be visible');

        await tester.tap(cardFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify the game screen pushed
        if (game.id == 'math_bubble_pop') {
          expect(find.byType(MathLevelSelectScreen), findsOneWidget);
        } else if (game.id == 'animal_memory_match') {
          expect(find.byType(MemoryLevelSelectScreen), findsOneWidget);
        } else if (game.id == 'merge_blacksmith') {
          expect(find.byType(MergeBlacksmithScreen), findsOneWidget);
        } else if (game.id == 'color_switch_courier') {
          expect(find.byType(ColorSwitchCourierScreen), findsOneWidget);
        }

        // Pop back to Hub using the custom back button icon
        await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Hub is restored
        expect(find.byType(GameHubScreen), findsOneWidget);
      }
    });

    testWidgets('Tapping locked cards displays SnackBar and remains on Hub',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      final shapeSorterFinder = find.widgetWithText(GameCard, 'Color & Shape Sorter');
      expect(shapeSorterFinder, findsOneWidget);

      await tester.tap(shapeSorterFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Color & Shape Sorter is coming soon! Stay tuned! 🚀'), findsOneWidget);
      expect(find.byType(GameHubScreen), findsOneWidget);
    });

    testWidgets('Category filters correctly restrict visible game cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Math filter
      await tester.tap(find.text('Math & Numbers'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(GameCard, 'Math Bubble Pop'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'Merge Blacksmith'), findsNothing);

      // Puzzles filter
      await tester.tap(find.text('Puzzles & Shapes'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(GameCard, 'Merge Blacksmith'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'Color & Shape Sorter'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'Gravity Glitch'), findsNothing);

      // Fun & Action filter
      await tester.tap(find.text('Fun & Action'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(GameCard, 'Gravity Glitch'), findsNothing);
      expect(find.widgetWithText(GameCard, 'Color Switch Courier'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'Sensory Balloon Pop'), findsOneWidget);
      expect(find.widgetWithText(GameCard, 'Math Bubble Pop'), findsNothing);
    });
  });
}
