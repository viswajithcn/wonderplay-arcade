import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/animal_memory_match/views/memory_level_select_screen.dart';
import 'package:kids_games/games/color_switch_courier/views/color_switch_courier_screen.dart';
import 'package:kids_games/games/math_bubble_pop/views/math_level_select_screen.dart';
import 'package:kids_games/games/merge_blacksmith/views/merge_blacksmith_screen.dart';
import 'package:kids_games/games/mini_game_registry.dart';
import 'package:kids_games/hub/views/game_hub_screen.dart';
import 'package:kids_games/hub/widgets/game_card.dart';

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

  group('Challenger M5-2: Hub Category Filtering Stress Tests', () {
    testWidgets('Default view (GameCategory.all) contains all 6 registered games',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await GameStorage.init();
      final allGames = MiniGameRegistry.getGames(storage);
      expect(allGames.length, equals(6));

      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      for (final game in allGames) {
        expect(find.text(game.title), findsOneWidget);
      }
      expect(find.text('Gravity Glitch'), findsNothing);
    });

    testWidgets('Filtering by GameCategory.puzzles shows only puzzle games and isolates others',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Tap Puzzles & Shapes filter pill
      final puzzleChip = find.text('Puzzles & Shapes');
      expect(puzzleChip, findsOneWidget);
      await tester.tap(puzzleChip);
      await tester.pumpAndSettle();

      // Should display Puzzles games: Merge Blacksmith (available) and Color & Shape Sorter (unavailable)
      expect(find.text('Merge Blacksmith'), findsOneWidget);
      expect(find.text('Color & Shape Sorter'), findsOneWidget);

      // Must NOT display games from other categories
      expect(find.text('Math Bubble Pop'), findsNothing);
      expect(find.text('Animal Memory Match'), findsNothing);
      expect(find.text('Gravity Glitch'), findsNothing);
      expect(find.text('Color Switch Courier'), findsNothing);
      expect(find.text('Sensory Balloon Pop'), findsNothing);
    });

    testWidgets('Filtering by GameCategory.action shows only action games',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Find and tap Fun & Action chip
      final actionChip = find.text('Fun & Action');
      expect(actionChip, findsOneWidget);
      await tester.tap(actionChip);
      await tester.pumpAndSettle();

      // Action games (Gravity Glitch is hidden)
      expect(find.text('Gravity Glitch'), findsNothing);
      expect(find.text('Color Switch Courier'), findsOneWidget);
      expect(find.text('Sensory Balloon Pop'), findsOneWidget);

      // Non-action games should be filtered out
      expect(find.text('Merge Blacksmith'), findsNothing);
      expect(find.text('Math Bubble Pop'), findsNothing);
      expect(find.text('Animal Memory Match'), findsNothing);
      expect(find.text('Color & Shape Sorter'), findsNothing);
    });

    testWidgets('Filtering by GameCategory.math and GameCategory.memory isolates single games',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Math filter
      await tester.tap(find.text('Math & Numbers'));
      await tester.pumpAndSettle();
      expect(find.text('Math Bubble Pop'), findsOneWidget);
      expect(find.text('Animal Memory Match'), findsNothing);
      expect(find.text('Merge Blacksmith'), findsNothing);

      // Memory filter
      await tester.tap(find.text('Memory & Logic'));
      await tester.pumpAndSettle();
      expect(find.text('Animal Memory Match'), findsOneWidget);
      expect(find.text('Math Bubble Pop'), findsNothing);
      expect(find.text('Merge Blacksmith'), findsNothing);
    });

    testWidgets('Rapid category toggle stress test does not cause state corruption',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      final chips = ['All Games', 'Math & Numbers', 'Memory & Logic', 'Puzzles & Shapes', 'Fun & Action'];

      // Rapidly toggle between all 5 category options 5 times (25 switches)
      for (int i = 0; i < 5; i++) {
        for (final label in chips) {
          final target = find.text(label);
          if (target.evaluate().isNotEmpty) {
            await tester.tap(target);
            await tester.pump(const Duration(milliseconds: 25));
          }
        }
      }
      await tester.pumpAndSettle();

      // Return to All Games and verify healthy state
      await tester.tap(find.text('All Games'));
      await tester.pumpAndSettle();

      expect(find.byType(GameHubScreen), findsOneWidget);
      expect(find.byType(GameCard), findsWidgets);
    });
  });

  group('Challenger M5-2: Hub Card Launch and Navigation Verification', () {
    testWidgets('Tapping Merge Blacksmith card launches MergeBlacksmithScreen and pops cleanly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Tap Puzzles filter to make card prominent
      await tester.tap(find.text('Puzzles & Shapes'));
      await tester.pumpAndSettle();

      // Tap Merge Blacksmith card
      final card = find.text('Merge Blacksmith');
      expect(card, findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();

      // Verify MergeBlacksmithScreen is pushed
      expect(find.byType(MergeBlacksmithScreen), findsOneWidget);

      // Pop back using Navigator
      final nav = Navigator.of(tester.element(find.byType(MergeBlacksmithScreen)));
      nav.pop();
      await tester.pumpAndSettle();

      // Verify GameHubScreen is restored
      expect(find.byType(GameHubScreen), findsOneWidget);
      expect(find.byType(MergeBlacksmithScreen), findsNothing);
    });

    testWidgets('Gravity Glitch is hidden from Hub and Pass & Play Animal Memory Match launches in 2-player mode',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Verify Gravity Glitch is hidden
      expect(find.text('Gravity Glitch'), findsNothing);

      // Tap Animal Memory Match
      await tester.tap(find.text('Animal Memory Match'));
      await tester.pumpAndSettle();

      expect(find.byType(MemoryLevelSelectScreen), findsOneWidget);
      expect(find.text('Pass & Play Players'), findsOneWidget);
      expect(find.text('2 Players'), findsOneWidget);

      // Tap Level 1 to launch 2-player Pass & Play game
      await tester.tap(find.text('Tiny Safari'));
      await tester.pumpAndSettle();

      expect(find.text("Player 1's Turn"), findsOneWidget);
    });

    testWidgets('Tapping Color Switch Courier card launches ColorSwitchCourierScreen and pops cleanly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Tap Action category
      await tester.tap(find.text('Fun & Action'));
      await tester.pumpAndSettle();

      // Tap Color Switch Courier
      final courierCard = find.text('Color Switch Courier');
      expect(courierCard, findsOneWidget);
      await tester.tap(courierCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify screen rendered
      expect(find.byType(ColorSwitchCourierScreen), findsOneWidget);

      // Tap back button
      final backButton = find.byIcon(Icons.arrow_back_rounded);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      // Pump multiple frames for route transition to complete and dispose
      for (int i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Verify restored to hub
      expect(find.byType(GameHubScreen), findsOneWidget);
      expect(find.byType(ColorSwitchCourierScreen), findsNothing);
    });

    testWidgets('Tapping Math Bubble Pop and Animal Memory Match cards launch respective screens',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // 1. Math Bubble Pop
      await tester.tap(find.text('Math & Numbers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Math Bubble Pop'));
      await tester.pumpAndSettle();
      expect(find.byType(MathLevelSelectScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(MathLevelSelectScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(GameHubScreen), findsOneWidget);

      // 2. Animal Memory Match
      await tester.tap(find.text('Memory & Logic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Animal Memory Match'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryLevelSelectScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(MemoryLevelSelectScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(GameHubScreen), findsOneWidget);
    });

    testWidgets('Tapping unavailable games shows Coming Soon SnackBar without navigation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Shape sorter (Puzzles)
      await tester.tap(find.text('Puzzles & Shapes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Color & Shape Sorter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Color & Shape Sorter is coming soon! Stay tuned! 🚀'), findsOneWidget);
      expect(find.byType(GameHubScreen), findsOneWidget);

      // Dismiss the previous snackbar so the next one shows immediately
      ScaffoldMessenger.of(tester.element(find.byType(GameHubScreen))).clearSnackBars();
      await tester.pump();

      // Balloon pop (Action)
      await tester.tap(find.text('Fun & Action'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sensory Balloon Pop'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sensory Balloon Pop is coming soon! Stay tuned! 🚀'), findsOneWidget);
      expect(find.byType(GameHubScreen), findsOneWidget);
    });

    testWidgets('Returning from a game updates total stars in the Hub header',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Initial stars: 0
      expect(find.text('0'), findsOneWidget);

      // Launch Merge Blacksmith
      await tester.tap(find.text('Puzzles & Shapes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Merge Blacksmith'));
      await tester.pumpAndSettle();
      expect(find.byType(MergeBlacksmithScreen), findsOneWidget);

      // Award 3 stars in storage
      await storage.saveLevelResult('merge_blacksmith', 1, 500, 3);

      // Pop back to Hub
      Navigator.of(tester.element(find.byType(MergeBlacksmithScreen))).pop();
      await tester.pumpAndSettle();

      // Hub header should now reflect 3 stars
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('Challenger M5-2: APK Binary Structure Empirical Verification', () {
    test('Release APK exists, exceeds 20MB, and contains expected Android/Flutter assets',
        () async {
      final apkFile = File('build/app/outputs/flutter-apk/app-release.apk');
      expect(apkFile.existsSync(), isTrue,
          reason: 'Release APK must exist at build/app/outputs/flutter-apk/app-release.apk');

      final sizeBytes = apkFile.lengthSync();
      expect(sizeBytes, greaterThan(20 * 1024 * 1024),
          reason: 'APK size ($sizeBytes bytes) must be greater than 20MB');

      // Verify zip archive contents using platform tar
      final result = await Process.run('tar', ['-tf', apkFile.path]);
      expect(result.exitCode, equals(0),
          reason: 'tar command must successfully read the APK archive');

      final listing = result.stdout as String;

      // Dalvik bytecode
      expect(listing.contains('classes.dex'), isTrue,
          reason: 'APK must contain classes.dex bytecode');

      // Android manifest
      expect(listing.contains('AndroidManifest.xml'), isTrue,
          reason: 'APK must contain AndroidManifest.xml');

      // Resources and native code
      expect(listing.contains('resources.arsc'), isTrue,
          reason: 'APK must contain resources.arsc table');
      expect(listing.contains('lib/arm64-v8a/libapp.so'), isTrue,
          reason: 'APK must contain 64-bit ARM Flutter app binary');
      expect(listing.contains('lib/arm64-v8a/libflutter.so'), isTrue,
          reason: 'APK must contain Flutter engine shared library');

      // Bundled assets
      expect(listing.contains('assets/flutter_assets/AssetManifest.json'), isTrue,
          reason: 'APK must contain AssetManifest.json');
      expect(listing.contains('assets/flutter_assets/FontManifest.json'), isTrue,
          reason: 'APK must contain FontManifest.json');
      expect(listing.contains('assets/flutter_assets/assets/audio/pop.wav'), isTrue,
          reason: 'APK must bundle audio assets');
      expect(listing.contains('assets/flutter_assets/assets/audio/bgm.wav'), isTrue,
          reason: 'APK must bundle BGM audio');
    });
  });
}
