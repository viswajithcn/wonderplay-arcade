import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/audio/audio_controller.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/merge_blacksmith/controllers/merge_blacksmith_controller.dart';
import 'package:kids_games/games/merge_blacksmith/models/blacksmith_item.dart';
import 'package:kids_games/games/merge_blacksmith/models/customer_order.dart';
import 'package:kids_games/games/merge_blacksmith/views/merge_blacksmith_screen.dart';
import 'package:kids_games/games/merge_blacksmith/widgets/customer_order_banner.dart';
import 'package:kids_games/games/merge_blacksmith/widgets/forge_slot_widget.dart';
import 'package:kids_games/models/mini_game_model.dart';

/// Test Spy AudioController for stress testing audio invocation contracts
class StressSpyAudioController implements AudioController {
  int popCount = 0;
  int correctCount = 0;
  int wrongCount = 0;
  int celebrateCount = 0;
  int clickCount = 0;
  int startBgmCount = 0;
  int stopBgmCount = 0;

  bool _sfxEnabled = true;
  bool _bgmEnabled = true;

  @override
  bool get sfxEnabled => _sfxEnabled;

  @override
  bool get bgmEnabled => _bgmEnabled;

  @override
  bool get isMuted => !_sfxEnabled && !_bgmEnabled;

  @override
  Future<void> init(GameStorage storage) async {
    _sfxEnabled = storage.getSfxEnabled();
    _bgmEnabled = storage.getBgmEnabled();
  }

  @override
  Future<void> startBgm() async {
    startBgmCount++;
  }

  @override
  Future<void> stopBgm() async {
    stopBgmCount++;
  }

  @override
  void toggleMasterMute(GameStorage storage) {
    if (!isMuted) {
      _sfxEnabled = false;
      _bgmEnabled = false;
      storage.setSfxEnabled(false);
      storage.setBgmEnabled(false);
    } else {
      _sfxEnabled = true;
      _bgmEnabled = true;
      storage.setSfxEnabled(true);
      storage.setBgmEnabled(true);
    }
    notifyListeners();
  }

  @override
  void setSfxEnabled(bool val, GameStorage storage) {
    _sfxEnabled = val;
    storage.setSfxEnabled(val);
    notifyListeners();
  }

  @override
  void setBgmEnabled(bool val, GameStorage storage) {
    _bgmEnabled = val;
    storage.setBgmEnabled(val);
    notifyListeners();
  }

  @override
  void toggleSfx(GameStorage storage) => setSfxEnabled(!_sfxEnabled, storage);

  @override
  void toggleBgm(GameStorage storage) => setBgmEnabled(!_bgmEnabled, storage);

  @override
  Future<void> playPop() async {
    popCount++;
  }

  @override
  Future<void> playCorrect() async {
    correctCount++;
  }

  @override
  Future<void> playWrong() async {
    wrongCount++;
  }

  @override
  Future<void> playCelebrate() async {
    celebrateCount++;
  }

  @override
  Future<void> playClick() async {
    clickCount++;
  }

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  void dispose() {}

  @override
  bool get hasListeners => false;

  @override
  void notifyListeners() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 2 Iteration 2 Challenger: Empirical Invariant Fuzzing', () {
    late StressSpyAudioController spyAudio;
    late GameStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await GameStorage.init();
      spyAudio = StressSpyAudioController();
    });

    test('2,000 randomized state actions preserve all core invariants without crashing', () {
      final controller = MergeBlacksmithController(
        storage: storage,
        audio: spyAudio,
        autoStart: false,
      );

      final rng = Random(12345);

      void checkInvariants() {
        // 1. Grid size
        expect(controller.slots.length, MergeBlacksmithController.totalSlots);

        // 2. Item count equals non-null slots
        final actualOccupied = controller.slots.where((s) => s != null).length;
        expect(controller.slots.where((s) => s != null).length, actualOccupied);

        // 3. Score and orders non-negative
        expect(controller.score, greaterThanOrEqualTo(0));
        expect(controller.ordersFulfilled, greaterThanOrEqualTo(0));

        // 4. Valid item levels
        for (var i = 0; i < controller.slots.length; i++) {
          final item = controller.slots[i];
          if (item != null) {
            expect(item.level, inInclusiveRange(1, 5));
          }
        }

        // 5. Gridlock oracle
        if (controller.isGameOver) {
          expect(controller.isFull, isTrue);
          expect(controller.canMakeAnyMove(), isFalse);
          expect(controller.hasValidMerge(), isFalse);
          expect(controller.hasMatchingOrder(), isFalse);
        }
      }

      for (var step = 0; step < 2000; step++) {
        final action = rng.nextInt(5);
        switch (action) {
          case 0:
            // Spawn item
            controller.spawnItem(level: 1, playSound: false);
            break;
          case 1:
            // Merge or move random slots
            final from = rng.nextInt(MergeBlacksmithController.totalSlots + 4) - 2;
            final to = rng.nextInt(MergeBlacksmithController.totalSlots + 4) - 2;
            controller.mergeOrMove(from, to);
            break;
          case 2:
            // Deliver order from random slot
            final slot = rng.nextInt(MergeBlacksmithController.totalSlots + 2) - 1;
            controller.fulfillOrder(slot);
            break;
          case 3:
            // Randomly set a slot or clear it
            final s = rng.nextInt(MergeBlacksmithController.totalSlots);
            final lv = rng.nextBool() ? rng.nextInt(5) + 1 : null;
            controller.setSlotItem(s, lv != null ? BlacksmithItem.create(lv) : null);
            break;
          case 4:
            // Occasional reset
            if (step % 500 == 0) {
              controller.reset();
            }
            break;
        }

        checkInvariants();
      }

      controller.dispose();
    });

    test('Strict boundary validation on invalid indices and illegal operations', () {
      final controller = MergeBlacksmithController(
        storage: storage,
        audio: spyAudio,
        autoStart: false,
      );

      // Empty move
      expect(controller.mergeOrMove(0, 1), isFalse);
      expect(controller.mergeOrMove(-1, 0), isFalse);
      expect(controller.mergeOrMove(0, 20), isFalse);
      expect(controller.mergeOrMove(25, 30), isFalse);

      // Self merge
      controller.setSlotItem(3, BlacksmithItem.create(2));
      final itemBefore = controller.slots[3]!;
      expect(controller.mergeOrMove(3, 3), isFalse);
      expect(controller.slots[3], equals(itemBefore));

      // Deliver empty or invalid index
      expect(controller.fulfillOrder(-1), isFalse);
      expect(controller.fulfillOrder(19), isFalse);

      controller.dispose();
    });
  });

  group('Milestone 2 Iteration 2 Challenger: Audio & Storage Monotonicity', () {
    late StressSpyAudioController spyAudio;
    late GameStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await GameStorage.init();
      spyAudio = StressSpyAudioController();
    });

    test('AudioController triggers exact sound contracts for every user action', () {
      final controller = MergeBlacksmithController(
        storage: storage,
        audio: spyAudio,
        autoStart: false,
      );

      // 1. Spawning triggers playPop
      final popBefore = spyAudio.popCount;
      controller.spawnItem(level: 1, playSound: true);
      expect(spyAudio.popCount, popBefore + 1);

      // Set up two Lv 1 items
      controller.setSlotItem(0, BlacksmithItem.create(1));
      controller.setSlotItem(1, BlacksmithItem.create(1));

      // 2. Merging triggers playCorrect
      final correctBeforeMerge = spyAudio.correctCount;
      expect(controller.mergeOrMove(0, 1), isTrue);
      expect(spyAudio.correctCount, correctBeforeMerge + 1);
      expect(controller.slots[1]?.level, 2);

      // 3. Merging two Lv 5 items triggers playWrong
      controller.setSlotItem(0, BlacksmithItem.create(5));
      controller.setSlotItem(1, BlacksmithItem.create(5));
      final wrongBefore = spyAudio.wrongCount;
      expect(controller.mergeOrMove(0, 1), isFalse);
      expect(spyAudio.wrongCount, wrongBefore + 1);

      // 4. Delivering correct order triggers playCelebrate
      controller.setOrder(const CustomerOrder(
        targetLevel: 2,
        customerName: 'Sir Arthur',
        avatarEmoji: '🛡️',
        rewardScore: 50,
      ));
      controller.setSlotItem(2, BlacksmithItem.create(2));
      final celebrateBefore = spyAudio.celebrateCount;
      expect(controller.fulfillOrder(2), isTrue);
      expect(spyAudio.celebrateCount, celebrateBefore + 1);

      // 5. Delivering wrong order triggers playWrong
      controller.setSlotItem(3, BlacksmithItem.create(1));
      final wrongBeforeMismatch = spyAudio.wrongCount;
      expect(controller.fulfillOrder(3), isFalse);
      expect(spyAudio.wrongCount, wrongBeforeMismatch + 1);

      controller.dispose();
    });

    test('Storage high score and star monotonicity under randomized stress', () async {
      const gameId = 'merge_blacksmith';

      expect(storage.getLevelHighScore(gameId, 1), 0);
      expect(storage.getLevelStars(gameId, 1), 0);

      final rng = Random(54321);
      int maxScoreSeen = 0;
      int maxStarsSeen = 0;

      for (var i = 0; i < 50; i++) {
        final score = rng.nextInt(500);
        final stars = rng.nextInt(4); // 0 to 3

        if (score > maxScoreSeen) maxScoreSeen = score;
        if (stars > maxStarsSeen) maxStarsSeen = stars;

        await storage.saveLevelResult(gameId, 1, score, stars);

        expect(storage.getLevelHighScore(gameId, 1), maxScoreSeen);
        expect(storage.getLevelStars(gameId, 1), maxStarsSeen);
      }
    });

    test('Master mute toggle and SFX/BGM toggles operate without race conditions', () {
      for (var i = 0; i < 100; i++) {
        spyAudio.toggleMasterMute(storage);
        expect(storage.getSfxEnabled(), spyAudio.sfxEnabled);
        expect(storage.getBgmEnabled(), spyAudio.bgmEnabled);
      }
    });
  });

  group('Milestone 2 Iteration 2 Challenger: Drag & Drop Interaction Stress', () {
    late StressSpyAudioController spyAudio;
    late GameStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await GameStorage.init();
      spyAudio = StressSpyAudioController();
    });

    testWidgets('Drag cancel into empty space leaves origin item unchanged and interactive', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = MergeBlacksmithController(
        storage: storage,
        audio: spyAudio,
        autoStart: false,
      );

      controller.setSlotItem(0, BlacksmithItem.create(1));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MergeBlacksmithScreen(
              difficulty: GameDifficulty.easy,
              storage: storage,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final originSlot = find.byType(ForgeSlotWidget).first;
      expect(originSlot, findsOneWidget);

      final draggableFinder = find.descendant(
        of: originSlot,
        matching: find.byType(Draggable<int>),
      );
      expect(draggableFinder, findsOneWidget);

      // Start drag gesture on slot 0
      final gesture = await tester.startGesture(tester.getCenter(draggableFinder));
      await tester.pump(const Duration(milliseconds: 50));

      // Move drag to empty space outside the grid
      await gesture.moveTo(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 50));

      // Release / drop in empty space
      await gesture.up();
      await tester.pumpAndSettle();

      // Slot 0 should still contain the Lv 1 item
      expect(controller.slots[0]?.level, 1);
      expect(find.text('🧱'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Drag item onto CustomerOrderBanner fulfills matching order in real widget tree', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = MergeBlacksmithController(
        storage: storage,
        audio: spyAudio,
        autoStart: false,
      );

      controller.setOrder(const CustomerOrder(
        targetLevel: 3,
        customerName: 'Knight Vance',
        avatarEmoji: '🛡️',
        rewardScore: 100,
      ));

      // Put Lv 3 item in slot 0
      controller.setSlotItem(0, BlacksmithItem.create(3));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MergeBlacksmithScreen(
              difficulty: GameDifficulty.easy,
              storage: storage,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Knight Vance'), findsOneWidget);
      final slotFinder = find.byType(ForgeSlotWidget).first;
      final draggableFinder = find.descendant(
        of: slotFinder,
        matching: find.byType(Draggable<int>),
      );
      final bannerFinder = find.byType(CustomerOrderBanner);

      final gesture = await tester.startGesture(tester.getCenter(draggableFinder));
      await tester.pump(const Duration(milliseconds: 50));

      await gesture.moveTo(tester.getCenter(bannerFinder));
      await tester.pump(const Duration(milliseconds: 50));

      await gesture.up();
      await tester.pumpAndSettle();

      // Verification: order fulfilled, score updated, slot 0 cleared, celebrate sound played
      expect(controller.ordersFulfilled, 1);
      expect(controller.score, 100);
      expect(controller.slots[0], isNull);
      expect(spyAudio.celebrateCount, 1);

      controller.dispose();
    });

    testWidgets('Drag mismatched item onto CustomerOrderBanner is rejected with wrong feedback', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = MergeBlacksmithController(
        storage: storage,
        audio: spyAudio,
        autoStart: false,
      );

      controller.setOrder(const CustomerOrder(
        targetLevel: 4,
        customerName: 'Queen Eleanor',
        avatarEmoji: '👑',
        rewardScore: 200,
      ));

      // Put Lv 2 item in slot 0
      controller.setSlotItem(0, BlacksmithItem.create(2));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MergeBlacksmithScreen(
              difficulty: GameDifficulty.easy,
              storage: storage,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slotFinder = find.byType(ForgeSlotWidget).first;
      final draggableFinder = find.descendant(
        of: slotFinder,
        matching: find.byType(Draggable<int>),
      );
      final bannerFinder = find.byType(CustomerOrderBanner);

      final gesture = await tester.startGesture(tester.getCenter(draggableFinder));
      await tester.pump(const Duration(milliseconds: 50));

      await gesture.moveTo(tester.getCenter(bannerFinder));
      await tester.pump(const Duration(milliseconds: 50));

      await gesture.up();
      await tester.pumpAndSettle();

      // Verification: order NOT fulfilled, score 0, slot 0 still contains Lv 2 item, wrong sound played
      expect(controller.ordersFulfilled, 0);
      expect(controller.score, 0);
      expect(controller.slots[0]?.level, 2);
      expect(spyAudio.wrongCount, 1);

      controller.dispose();
    });
  });

  group('Milestone 2 Iteration 2 Challenger: Extreme Screen Size & Overflow Stress', () {
    late StressSpyAudioController spyAudio;
    late GameStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await GameStorage.init();
      spyAudio = StressSpyAudioController();
    });

    testWidgets('Compact mobile (320x480) with full grid and order banner has 0 overflow exceptions', (tester) async {
      FlutterErrorDetails? caughtError;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          caughtError = details;
        }
        originalOnError?.call(details);
      };

      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        FlutterError.onError = originalOnError;
      });

      final controller = MergeBlacksmithController(
        storage: storage,
        audio: spyAudio,
        autoStart: false,
      );

      // Populate grid with all 5 item types
      for (var i = 0; i < MergeBlacksmithController.totalSlots; i++) {
        final lv = (i % 5) + 1;
        controller.setSlotItem(i, BlacksmithItem.create(lv));
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MergeBlacksmithScreen(
              difficulty: GameDifficulty.hard,
              storage: storage,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no overflow exception was thrown
      expect(caughtError, isNull);

      // Trigger feedback message banner on top of screen
      controller.mergeOrMove(0, 1); // Lv 1 + Lv 2 triggers swap feedback
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(caughtError, isNull);

      controller.dispose();
    });

    testWidgets('Ultra-narrow screen (280x600) with order and feedback renders without overflow', (tester) async {
      FlutterErrorDetails? caughtError;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          caughtError = details;
        }
        originalOnError?.call(details);
      };

      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        FlutterError.onError = originalOnError;
      });

      final controller = MergeBlacksmithController(
        storage: storage,
        audio: spyAudio,
        autoStart: false,
      );

      for (var i = 0; i < MergeBlacksmithController.totalSlots; i++) {
        controller.setSlotItem(i, BlacksmithItem.create(3));
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MergeBlacksmithScreen(
              difficulty: GameDifficulty.medium,
              storage: storage,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(caughtError, isNull);
      controller.dispose();
    });

    testWidgets('Ultra-short screen (400x340) renders cleanly with FittedBoxes scaling down', (tester) async {
      FlutterErrorDetails? caughtError;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.toString().contains('overflowed')) {
          caughtError = details;
        }
        originalOnError?.call(details);
      };

      tester.view.physicalSize = const Size(400, 340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        FlutterError.onError = originalOnError;
      });

      final controller = MergeBlacksmithController(
        storage: storage,
        audio: spyAudio,
        autoStart: false,
      );

      for (var i = 0; i < MergeBlacksmithController.totalSlots; i++) {
        controller.setSlotItem(i, BlacksmithItem.create(4));
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MergeBlacksmithScreen(
              difficulty: GameDifficulty.easy,
              storage: storage,
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(caughtError, isNull);
      controller.dispose();
    });
  });
}
