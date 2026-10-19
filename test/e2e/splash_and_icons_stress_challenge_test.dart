import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/splash/views/splash_screen.dart';
import 'package:kids_games/hub/views/game_hub_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Empirical Challenge: Launcher Icons Binary & Dimension Verification', () {
    const expectedDimensions = {
      'mdpi': 48,
      'hdpi': 72,
      'xhdpi': 96,
      'xxhdpi': 144,
      'xxxhdpi': 192,
    };

    const pngMagic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    const ihdrChunk = [0x49, 0x48, 0x44, 0x52]; // 'IHDR'

    for (final entry in expectedDimensions.entries) {
      final density = entry.key;
      final expectedDim = entry.value;

      test('Mipmap $density icon exists, has valid PNG header, and exact ${expectedDim}x$expectedDim px', () {
        final path = 'android/app/src/main/res/mipmap-$density/ic_launcher.png';
        final file = File(path);

        expect(file.existsSync(), isTrue, reason: '$path must exist on disk');
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(24), reason: '$path is too small to be a valid PNG');

        // Verify PNG 8-byte magic header
        for (int i = 0; i < 8; i++) {
          expect(bytes[i], equals(pngMagic[i]), reason: '$path byte $i must match PNG magic');
        }

        // Verify IHDR chunk marker at offset 12..15
        for (int i = 0; i < 4; i++) {
          expect(bytes[12 + i], equals(ihdrChunk[i]), reason: '$path bytes 12..15 must be IHDR');
        }

        // Read big-endian width (bytes 16..19) and height (bytes 20..23)
        final byteData = ByteData.sublistView(bytes);
        final width = byteData.getUint32(16, Endian.big);
        final height = byteData.getUint32(20, Endian.big);

        expect(width, equals(expectedDim), reason: '$path width must be $expectedDim');
        expect(height, equals(expectedDim), reason: '$path height must be $expectedDim');
      });
    }

    test('Web icons exist, have valid PNG headers, and match required dimensions', () {
      final webTargets = {
        'web/favicon.png': 32,
        'web/icons/Icon-192.png': 192,
        'web/icons/Icon-512.png': 512,
        'web/icons/Icon-maskable-192.png': 192,
        'web/icons/Icon-maskable-512.png': 512,
      };

      for (final entry in webTargets.entries) {
        final path = entry.key;
        final expectedDim = entry.value;
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path must exist');
        final bytes = file.readAsBytesSync();
        expect(bytes.length, greaterThan(24));

        for (int i = 0; i < 8; i++) {
          expect(bytes[i], equals(pngMagic[i]), reason: '$path byte $i must match PNG magic');
        }

        final byteData = ByteData.sublistView(bytes);
        final width = byteData.getUint32(16, Endian.big);
        final height = byteData.getUint32(20, Endian.big);
        expect(width, equals(expectedDim), reason: '$path width mismatch');
        expect(height, equals(expectedDim), reason: '$path height mismatch');
      }
    });
  });

  group('Empirical Challenge: Splash Screen Stress Testing', () {
    testWidgets('Stress: Single tap during mid-animation navigates without exceptions',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(storage: storage),
      ));

      // Pump 300ms into the 1200ms animation
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SplashScreen), findsOneWidget);

      // Tap anywhere on the opaque screen
      await tester.tap(find.byType(SplashScreen));
      await tester.pumpAndSettle();

      // Navigation must have replaced SplashScreen with GameHubScreen
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(GameHubScreen), findsOneWidget);
      expect(find.text('WonderPlay Arcade!'), findsOneWidget);
    });

    testWidgets('Stress: Rapid double tap does not duplicate navigation or throw',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(storage: storage),
      ));

      await tester.pump(const Duration(milliseconds: 100));

      // Fire two taps in rapid succession without pumpAndSettle in between
      await tester.tap(find.byType(SplashScreen));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byType(SplashScreen), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Should cleanly land on GameHubScreen exactly once
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(GameHubScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stress: Burst barrage of 10 rapid taps is completely debounced/safe',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(storage: storage),
      ));

      await tester.pump(const Duration(milliseconds: 50));

      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byType(SplashScreen), warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 5));
      }
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(GameHubScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stress: Natural auto-navigation without user interaction transitions cleanly',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(storage: storage, duration: const Duration(milliseconds: 800)),
      ));

      expect(find.byType(SplashScreen), findsOneWidget);

      // Advance past duration + transition
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(GameHubScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stress: Tap right before timer expires (boundary condition)',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      const splashDuration = Duration(milliseconds: 1000);
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(storage: storage, duration: splashDuration),
      ));

      // Pump to 990ms (10ms before timer triggers)
      await tester.pump(const Duration(milliseconds: 990));

      // Tap right before timer
      await tester.tap(find.byType(SplashScreen));
      // Pump past when the timer would have fired
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(GameHubScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stress: Unmounting widget while animation and timer run causes no memory leak/exception',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(storage: storage),
      ));

      // Animation and timer running at 200ms
      await tester.pump(const Duration(milliseconds: 200));

      // Suddenly replace entire widget tree with an empty Container
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('Unmounted')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Unmounted'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stress: Extreme screen sizes (300x400 and 1200x1920) render without overflow',
        (WidgetTester tester) async {
      final storage = await GameStorage.init();

      // Test small phone
      tester.view.physicalSize = const Size(300, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(storage: storage),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Test large tablet
      tester.view.physicalSize = const Size(1200, 1920);
      await tester.pumpWidget(MaterialApp(
        home: SplashScreen(storage: storage),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
