import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/main.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/core/audio/audio_controller.dart';
import 'package:kids_games/hub/views/game_hub_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Branding, Splash & Hub E2E Tests', () {
    // =========================================================================
    // TIER 1: FEATURE COVERAGE (>= 5 test cases)
    // =========================================================================

    testWidgets('Tier 1: App title is configured with branding in MaterialApp',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(KidsGamesApp(storage: storage));
      await tester.pump();

      final materialAppFinder = find.byType(MaterialApp);
      expect(materialAppFinder, findsOneWidget);
      final materialApp = tester.widget<MaterialApp>(materialAppFinder);
      
      // Title must reflect the arcade branding or title specification
      expect(
        materialApp.title == 'WonderPlay Arcade' ||
            materialApp.title == 'Kids Mini-Games',
        isTrue,
        reason: 'MaterialApp title must adhere to project branding',
      );
    });

    testWidgets('Tier 1: Android and Web configuration files define app title',
        (WidgetTester tester) async {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final manifestContent = manifestFile.readAsStringSync();
      expect(manifestContent.contains('android:label='), isTrue);

      final webIndexFile = File('web/index.html');
      expect(webIndexFile.existsSync(), isTrue);
      final webIndexContent = webIndexFile.readAsStringSync();
      expect(webIndexContent.contains('<title>'), isTrue);

      final webManifestFile = File('web/manifest.json');
      expect(webManifestFile.existsSync(), isTrue);
      final webManifestContent = webManifestFile.readAsStringSync();
      expect(webManifestContent.contains('"name"'), isTrue);
    });

    testWidgets('Tier 1: Hub screen renders header title and total stars counter',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'total_stars_collected': 15});
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Header should display either WonderPlay Arcade or Kids Games
      final headerFinder = find.byWidgetPredicate((widget) {
        if (widget is Text) {
          final data = widget.data ?? '';
          return data.contains('WonderPlay') || data.contains('Kids Games');
        }
        return false;
      });
      expect(headerFinder, findsAtLeastNWidgets(1));

      // Stars counter should display 15
      expect(find.text('15'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsWidgets);
    });

    testWidgets('Tier 1: Category filter tabs exist and are selectable on Hub',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Verify category labels exist
      expect(find.text('All Games'), findsOneWidget);
      expect(find.text('Math & Numbers'), findsOneWidget);
      expect(find.text('Memory & Logic'), findsOneWidget);

      // Tap on Math category
      await tester.tap(find.text('Math & Numbers'));
      await tester.pumpAndSettle();

      // Bubble pop game card should remain visible
      expect(find.text('Math Bubble Pop'), findsOneWidget);
    });

    testWidgets('Tier 1: Audio settings dialog is accessible via top bar',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);

      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // 1. Verify quick master volume toggle works
      final volumeButton = find.byWidgetPredicate((w) =>
          w is IconButton &&
          w.icon is Icon &&
          ((w.icon as Icon).icon == Icons.volume_up_rounded ||
              (w.icon as Icon).icon == Icons.volume_off_rounded));
      expect(volumeButton, findsOneWidget);
      await tester.tap(volumeButton);
      await tester.pumpAndSettle();
      expect(audio.isMuted, isTrue);

      // 2. Find settings button and verify parental gate opens
      final settingsButton = find.byWidgetPredicate((w) =>
          w is IconButton &&
          w.icon is Icon &&
          (w.icon as Icon).icon == Icons.settings_rounded);
      expect(settingsButton, findsOneWidget);
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // Parental gate dialog should appear
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Grown-Ups Only'), findsOneWidget);
    });

    // =========================================================================
    // TIER 2: BOUNDARY & CORNER CASES (>= 5 test cases)
    // =========================================================================

    testWidgets('Tier 2: Fresh install with empty storage defaults to 0 stars and sound on',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();

      expect(storage.getTotalStars(), 0);
      expect(storage.getSfxEnabled(), isTrue);
      expect(storage.getBgmEnabled(), isTrue);

      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('Tier 2: Rapid taps on Hub category buttons do not crash or corrupt UI',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Memory & Logic'));
        await tester.pump(const Duration(milliseconds: 30));
        await tester.tap(find.text('All Games'));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      expect(find.text('Math Bubble Pop'), findsOneWidget);
    });

    testWidgets('Tier 2: Extremely small screen constraints do not trigger fatal overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(GameHubScreen), findsOneWidget);
    });

    testWidgets('Tier 2: Storage corrupted with negative stars is handled safely',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({'total_stars_collected': -5});
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(GameHubScreen), findsOneWidget);
    });

    testWidgets('Tier 2: Android mipmap launcher icon files exist across all densities',
        (WidgetTester tester) async {
      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in densities) {
        final iconFile = File('android/app/src/main/res/mipmap-$density/ic_launcher.png');
        expect(
          iconFile.existsSync(),
          isTrue,
          reason: 'Launcher icon for $density must exist',
        );
        expect(iconFile.lengthSync(), greaterThan(0));
      }
    });

    // =========================================================================
    // TIER 3: CROSS-FEATURE COMBINATIONS
    // =========================================================================

    testWidgets('Tier 3: Mute toggle via AudioController syncs to GameStorage',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);

      expect(audio.isMuted, isFalse);

      // Toggle master mute
      audio.toggleMasterMute(storage);
      expect(audio.isMuted, isTrue);
      expect(storage.getSfxEnabled(), isFalse);
      expect(storage.getBgmEnabled(), isFalse);

      // Toggle unmute
      audio.toggleMasterMute(storage);
      expect(audio.isMuted, isFalse);
      expect(storage.getSfxEnabled(), isTrue);
      expect(storage.getBgmEnabled(), isTrue);
    });

    testWidgets('Tier 3: Category filtering preserves star counts and available badges',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'math_bubble_pop_level_1_stars': 3,
        'total_stars_collected': 3,
      });
      final storage = await GameStorage.init();

      await tester.pumpWidget(MaterialApp(
        home: GameHubScreen(storage: storage),
      ));
      await tester.pumpAndSettle();

      // Check stars visible on Math card
      expect(find.text('Math Bubble Pop'), findsOneWidget);

      // Switch to Memory category
      await tester.tap(find.text('Memory & Logic'));
      await tester.pumpAndSettle();

      // Animal memory match should be visible
      expect(find.text('Animal Memory Match'), findsOneWidget);

      // Total stars in top header must still be 3
      expect(find.text('3'), findsOneWidget);
    });

    // =========================================================================
    // TIER 4: REAL-WORLD APPLICATION SCENARIOS
    // =========================================================================

    testWidgets('Tier 4: Complete user journey from App launch through Hub navigation',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'total_stars_collected': 0,
      });
      final storage = await GameStorage.init();

      // Pump full app
      await tester.pumpWidget(KidsGamesApp(storage: storage));
      // Pump past splash duration if animated splash screen is present
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Hub screen is active
      expect(find.byType(GameHubScreen), findsOneWidget);

      // Player checks all games tab
      expect(find.text('All Games'), findsOneWidget);

      // Verify stars counter is 0
      expect(find.text('0'), findsOneWidget);
    });
  });
}
