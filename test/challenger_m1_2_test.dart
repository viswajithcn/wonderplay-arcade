import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/main.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/hub/views/game_hub_screen.dart';
import 'package:kids_games/splash/views/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Challenger 2 Empirical Challenge: Branding Across Platforms', () {
    test('Branding: Exact string match, case sensitivity and whitespace checks', () {
      const expectedBranding = 'WonderPlay Arcade';

      // 1. Android Manifest
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final manifest = manifestFile.readAsStringSync();
      final androidLabelMatch =
          RegExp(r'android:label="([^"]+)"').firstMatch(manifest);
      expect(androidLabelMatch, isNotNull,
          reason: 'android:label attribute must be present in AndroidManifest.xml');
      final androidLabel = androidLabelMatch!.group(1);
      expect(androidLabel, equals(expectedBranding),
          reason: 'Android app label must exactly equal "WonderPlay Arcade"');
      expect(androidLabel!.trim(), equals(androidLabel),
          reason: 'Android app label must not have leading/trailing whitespace');

      // 2. Web index.html title and meta tag
      final indexFile = File('web/index.html');
      expect(indexFile.existsSync(), isTrue);
      final indexHtml = indexFile.readAsStringSync();
      final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(indexHtml);
      expect(titleMatch, isNotNull, reason: '<title> must be present in web/index.html');
      final webTitle = titleMatch!.group(1);
      expect(webTitle, equals(expectedBranding),
          reason: 'web/index.html title must exactly equal "WonderPlay Arcade"');

      final metaMatch = RegExp(r'<meta\s+name="apple-mobile-web-app-title"\s+content="([^"]+)">')
          .firstMatch(indexHtml);
      expect(metaMatch, isNotNull,
          reason: 'apple-mobile-web-app-title must be present in web/index.html');
      final metaTitle = metaMatch!.group(1);
      expect(metaTitle, equals(expectedBranding));

      // 3. Web manifest.json
      final webManifestFile = File('web/manifest.json');
      expect(webManifestFile.existsSync(), isTrue);
      final webManifest = webManifestFile.readAsStringSync();
      final nameMatch = RegExp(r'"name":\s*"([^"]+)"').firstMatch(webManifest);
      expect(nameMatch, isNotNull);
      expect(nameMatch!.group(1), equals(expectedBranding));

      final shortNameMatch = RegExp(r'"short_name":\s*"([^"]+)"').firstMatch(webManifest);
      expect(shortNameMatch, isNotNull);
      expect(shortNameMatch!.group(1), equals('WonderPlay'));
    });

    testWidgets('Branding: MaterialApp title and UI string verification',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(KidsGamesApp(storage: storage));
      await tester.pump();

      // MaterialApp title
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, equals('WonderPlay Arcade'));

      // Splash title
      expect(find.text('WonderPlay Arcade'), findsOneWidget);
    });
  });

  group('Challenger 2 Empirical Challenge: Headless Splash Timeout & Skip Behavior', () {
    testWidgets('Splash: Auto-timeout triggers navigation without user interaction',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(KidsGamesApp(storage: storage));

      // Initially at 0ms: Splash screen is active, Hub is not
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(GameHubScreen), findsNothing);

      // Advance through animation (1200ms)
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(GameHubScreen), findsNothing);

      // Advance to 1800ms: timer fires navigation
      await tester.pump(const Duration(milliseconds: 600));

      // Finish route transition (350ms fade)
      await tester.pumpAndSettle();

      // Hub screen must now be active, Splash replaced
      expect(find.byType(GameHubScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });

    testWidgets('Splash: Tap skips immediately and cancels the auto-timeout timer',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(KidsGamesApp(storage: storage));
      await tester.pump();

      // Tap early at 100ms
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(GameHubScreen), findsNothing);

      // Tap anywhere
      await tester.tap(find.byType(SplashScreen));
      await tester.pumpAndSettle();

      // Immediately transitioned to Hub
      expect(find.byType(GameHubScreen), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      // Now advance time past the original 1800ms timer
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();

      // Verify no unexpected state changes or duplicate transitions
      expect(find.byType(GameHubScreen), findsOneWidget);
    });

    testWidgets('Splash: Rapid multi-taps do not trigger duplicate route pushes',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(KidsGamesApp(storage: storage));
      await tester.pump();

      // Rapidly tap 10 times in quick succession
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(SplashScreen));
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      // Only one GameHubScreen should be on top
      expect(find.byType(GameHubScreen), findsOneWidget);

      // Pop should exit app, not pop to another GameHubScreen
      final navigatorState = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigatorState.canPop(), isFalse,
          reason: 'Splash pushReplacement must ensure exactly one route on the stack');
    });

    testWidgets('Splash: Early widget unmount cancels timer and disposes controller cleanly',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      // Mount inside a togglable wrapper
      bool showSplash = true;
      late StateSetter triggerRebuild;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              triggerRebuild = setState;
              return showSplash
                  ? SplashScreen(storage: storage)
                  : const Scaffold(body: Text('Replaced Early'));
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Unmount before 1800ms
      triggerRebuild(() {
        showSplash = false;
      });
      await tester.pump();
      expect(find.text('Replaced Early'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);

      // Advance clock past the 1800ms mark to verify cancelled timer does not crash
      await tester.pump(const Duration(milliseconds: 3000));
      await tester.pumpAndSettle();

      expect(find.text('Replaced Early'), findsOneWidget);
    });

    testWidgets('Splash: Custom duration parameter is honored',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            storage: storage,
            duration: const Duration(milliseconds: 500),
          ),
        ),
      );
      await tester.pump();

      // At 300ms: still in splash
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(GameHubScreen), findsNothing);

      // At 550ms: timer has fired
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.byType(GameHubScreen), findsOneWidget);
    });

    testWidgets('Splash: Full screen hit test covers edges and corners',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(KidsGamesApp(storage: storage));
      await tester.pump();

      // Tap top-left corner
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(GameHubScreen), findsOneWidget);
    });
  });

  group('Challenger 2 Empirical Challenge: Screen Dimension Constraints', () {
    testWidgets('Splash: Extreme small portrait (320x480) does not overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = await GameStorage.init();
      await tester.pumpWidget(KidsGamesApp(storage: storage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull,
          reason: 'Splash screen should render on 320x480 without throwing overflow');
    });

    testWidgets('Splash: Landscape phone (640x360) check',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = await GameStorage.init();
      await tester.pumpWidget(KidsGamesApp(storage: storage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Check if any exceptions were thrown
      final exception = tester.takeException();
      if (exception != null) {
        // Record finding
        debugPrint('Landscape phone constraint exception: $exception');
      }
    });

    testWidgets('Splash: Tablet landscape (1024x768) does not overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final storage = await GameStorage.init();
      await tester.pumpWidget(KidsGamesApp(storage: storage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });
}
