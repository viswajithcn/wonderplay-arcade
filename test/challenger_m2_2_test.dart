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
import 'package:kids_games/shared/widgets/game_over_dialog.dart';
import 'package:kids_games/shared/widgets/victory_dialog.dart';

/// Test spy implementing AudioController to verify SFX trigger contracts empirically
class TestSpyAudioController implements AudioController {
  int popCalls = 0;
  int correctCalls = 0;
  int wrongCalls = 0;
  int celebrateCalls = 0;
  int clickCalls = 0;
  int startBgmCalls = 0;
  int stopBgmCalls = 0;

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
    startBgmCalls++;
  }

  @override
  Future<void> stopBgm() async {
    stopBgmCalls++;
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
    popCalls++;
  }

  @override
  Future<void> playCorrect() async {
    correctCalls++;
  }

  @override
  Future<void> playWrong() async {
    wrongCalls++;
  }

  @override
  Future<void> playCelebrate() async {
    celebrateCalls++;
  }

  @override
  Future<void> playClick() async {
    clickCalls++;
  }

  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  @override
  void notifyListeners() {
    for (final l in List<VoidCallback>.from(_listeners)) {
      l();
    }
  }

  @override
  bool get hasListeners => _listeners.isNotEmpty;

  @override
  void dispose() {
    _listeners.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Challenger 2 M2: Empirical Drag & Drop Adversarial Stress Tests', () {
    testWidgets('Mid-air drag cancel outside valid target preserves item in origin slot',
        (WidgetTester tester) async {
      final controller = MergeBlacksmithController(autoStart: false);
      // Place Lv 2 item in slot 0, all others null
      for (int i = 0; i < 20; i++) {
        controller.setSlotItem(i, null);
      }
      controller.setSlotItem(0, BlacksmithItem.create(2));

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      // Locate slot 0 draggable
      final slot0Finder = find.byWidgetPredicate(
        (w) => w is ForgeSlotWidget && w.slotIndex == 0,
      );
      expect(slot0Finder, findsOneWidget);

      final draggableFinder = find.descendant(
        of: slot0Finder,
        matching: find.byType(Draggable<int>),
      );
      expect(draggableFinder, findsOneWidget);

      // Start drag gesture on slot 0
      final gesture = await tester.startGesture(tester.getCenter(draggableFinder));
      await tester.pump(const Duration(milliseconds: 50));

      // Move into dead space (top-left corner outside grid targets)
      await gesture.moveTo(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 50));

      // Release mid-air outside targets
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify slot 0 still contains Lv 2 item and no slots were duplicated or destroyed
      expect(controller.slots[0], isNotNull);
      expect(controller.slots[0]!.level, equals(2));
      expect(controller.slots.where((s) => s != null).length, equals(1));
      expect(tester.takeException(), isNull);

      controller.dispose();
    });

    testWidgets('Drag onto self is rejected and leaves board state untouched',
        (WidgetTester tester) async {
      final controller = MergeBlacksmithController(autoStart: false);
      for (int i = 0; i < 20; i++) {
        controller.setSlotItem(i, null);
      }
      controller.setSlotItem(3, BlacksmithItem.create(3));

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      final slot3Finder = find.byWidgetPredicate(
        (w) => w is ForgeSlotWidget && w.slotIndex == 3,
      );
      final draggableFinder = find.descendant(
        of: slot3Finder,
        matching: find.byType(Draggable<int>),
      );

      final gesture = await tester.startGesture(tester.getCenter(draggableFinder));
      await tester.pump(const Duration(milliseconds: 50));
      // Move slightly within same slot
      await gesture.moveTo(tester.getCenter(slot3Finder) + const Offset(2, 2));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.slots[3]!.level, equals(3));
      expect(controller.score, equals(0));
      expect(controller.mergesCount, equals(0));

      controller.dispose();
    });

    testWidgets('Real Widget drag-and-drop merge from slot 0 onto slot 1 triggers level up',
        (WidgetTester tester) async {
      final spyAudio = TestSpyAudioController();
      final controller = MergeBlacksmithController(
        audio: spyAudio,
        autoStart: false,
      );
      for (int i = 0; i < 20; i++) {
        controller.setSlotItem(i, null);
      }
      controller.setSlotItem(0, BlacksmithItem.create(1));
      controller.setSlotItem(1, BlacksmithItem.create(1));

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      final slot0 = find.byWidgetPredicate((w) => w is ForgeSlotWidget && w.slotIndex == 0);
      final slot1 = find.byWidgetPredicate((w) => w is ForgeSlotWidget && w.slotIndex == 1);

      final draggable0 = find.descendant(of: slot0, matching: find.byType(Draggable<int>));

      // Drag slot 0 onto slot 1
      final gesture = await tester.startGesture(tester.getCenter(draggable0));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(slot1));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.slots[0], isNull);
      expect(controller.slots[1]!.level, equals(2));
      expect(controller.score, equals(20));
      expect(controller.mergesCount, equals(1));
      expect(spyAudio.correctCalls, equals(1));

      controller.dispose();
    });

    testWidgets('Direct drag-and-drop delivery to CustomerOrderBanner fulfills order',
        (WidgetTester tester) async {
      final spyAudio = TestSpyAudioController();
      final controller = MergeBlacksmithController(
        audio: spyAudio,
        autoStart: false,
      );
      for (int i = 0; i < 20; i++) {
        controller.setSlotItem(i, null);
      }
      const testOrder = CustomerOrder(
        targetLevel: 3,
        rewardScore: 200,
        customerName: 'Queen Guinevere',
        avatarEmoji: '👑',
      );
      controller.setOrder(testOrder);
      controller.setSlotItem(4, BlacksmithItem.create(3)); // Matching Lv 3

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      final slot4 = find.byWidgetPredicate((w) => w is ForgeSlotWidget && w.slotIndex == 4);
      final banner = find.byType(CustomerOrderBanner);

      final draggable4 = find.descendant(of: slot4, matching: find.byType(Draggable<int>));
      expect(draggable4, findsOneWidget);
      expect(banner, findsOneWidget);

      // Drag slot 4 onto CustomerOrderBanner
      final gesture = await tester.startGesture(tester.getCenter(draggable4));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(banner));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      expect(controller.slots[4], isNull);
      expect(controller.score, equals(200));
      expect(controller.ordersFulfilled, equals(1));
      expect(spyAudio.celebrateCalls, equals(1));
      expect(find.textContaining('Queen Guinevere served! (+200 pts)'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Adversarial delivery of wrong level item to CustomerOrderBanner is rejected',
        (WidgetTester tester) async {
      final spyAudio = TestSpyAudioController();
      final controller = MergeBlacksmithController(
        audio: spyAudio,
        autoStart: false,
      );
      for (int i = 0; i < 20; i++) {
        controller.setSlotItem(i, null);
      }
      const testOrder = CustomerOrder(
        targetLevel: 4,
        rewardScore: 350,
        customerName: 'Wizard Merlin',
        avatarEmoji: '🧙‍♂️',
      );
      controller.setOrder(testOrder);
      controller.setSlotItem(2, BlacksmithItem.create(1)); // Wrong level (1 instead of 4)

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      final slot2 = find.byWidgetPredicate((w) => w is ForgeSlotWidget && w.slotIndex == 2);
      final banner = find.byType(CustomerOrderBanner);

      final draggable2 = find.descendant(of: slot2, matching: find.byType(Draggable<int>));

      // Drag wrong item to banner
      final gesture = await tester.startGesture(tester.getCenter(draggable2));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(banner));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      // Slot 2 must still have Lv 1 item
      expect(controller.slots[2], isNotNull);
      expect(controller.slots[2]!.level, equals(1));
      expect(controller.score, equals(0));
      expect(controller.ordersFulfilled, equals(0));
      expect(spyAudio.wrongCalls, equals(1));
      expect(find.textContaining('Customer wants a Lv 4'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Cross-grid swap between slot 0 and slot 19 preserves item identities',
        (WidgetTester tester) async {
      final spyAudio = TestSpyAudioController();
      final controller = MergeBlacksmithController(
        audio: spyAudio,
        autoStart: false,
      );
      for (int i = 0; i < 20; i++) {
        controller.setSlotItem(i, null);
      }
      final itemA = BlacksmithItem.create(1);
      final itemB = BlacksmithItem.create(4);
      controller.setSlotItem(0, itemA);
      controller.setSlotItem(19, itemB);

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      final slot0 = find.byWidgetPredicate((w) => w is ForgeSlotWidget && w.slotIndex == 0);
      final slot19 = find.byWidgetPredicate((w) => w is ForgeSlotWidget && w.slotIndex == 19);

      final draggable0 = find.descendant(of: slot0, matching: find.byType(Draggable<int>));

      final gesture = await tester.startGesture(tester.getCenter(draggable0));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(tester.getCenter(slot19));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      // Swapped: slot 0 now has Lv 4, slot 19 has Lv 1
      expect(controller.slots[0]!.level, equals(4));
      expect(controller.slots[19]!.level, equals(1));
      expect(spyAudio.popCalls, equals(1));

      controller.dispose();
    });

    testWidgets('Attempting to merge two Level 5 items triggers wrong audio and warning',
        (WidgetTester tester) async {
      final spyAudio = TestSpyAudioController();
      final controller = MergeBlacksmithController(
        audio: spyAudio,
        autoStart: false,
      );
      controller.setSlotItem(5, BlacksmithItem.create(5));
      controller.setSlotItem(6, BlacksmithItem.create(5));

      final merged = controller.mergeOrMove(5, 6);
      expect(merged, isFalse);
      expect(controller.slots[5]!.level, equals(5));
      expect(controller.slots[6]!.level, equals(5));
      expect(spyAudio.wrongCalls, equals(1));
      expect(controller.feedbackMessage, contains('Max Level 5 reached'));

      controller.dispose();
    });
  });

  group('Challenger 2 M2: AudioController Empirical Verification Harness', () {
    test('Verifies exact audio triggers for all controller mechanics', () {
      final spy = TestSpyAudioController();
      final controller = MergeBlacksmithController(
        audio: spy,
        autoStart: false,
      );

      expect(spy.popCalls, equals(0));
      expect(spy.correctCalls, equals(0));
      expect(spy.wrongCalls, equals(0));
      expect(spy.celebrateCalls, equals(0));

      // 1. Spawning with sound
      controller.spawnItem(level: 1, playSound: true);
      expect(spy.popCalls, equals(1));

      // 2. Move to empty slot
      controller.setSlotItem(0, BlacksmithItem.create(1));
      controller.setSlotItem(10, null);
      controller.mergeOrMove(0, 10);
      expect(spy.popCalls, equals(2));

      // 3. Swap different levels
      controller.setSlotItem(1, BlacksmithItem.create(3));
      controller.setSlotItem(2, BlacksmithItem.create(4));
      controller.mergeOrMove(1, 2);
      expect(spy.popCalls, equals(3));

      // 4. Merge same level
      controller.setSlotItem(3, BlacksmithItem.create(2));
      controller.setSlotItem(4, BlacksmithItem.create(2));
      controller.mergeOrMove(3, 4);
      expect(spy.correctCalls, equals(1));

      // 5. Lv 5 + Lv 5 merge attempt
      controller.setSlotItem(5, BlacksmithItem.create(5));
      controller.setSlotItem(6, BlacksmithItem.create(5));
      controller.mergeOrMove(5, 6);
      expect(spy.wrongCalls, equals(1));

      // 6. Fulfill correct order
      const order = CustomerOrder(
        targetLevel: 2,
        rewardScore: 100,
        customerName: 'Knight',
        avatarEmoji: '🛡️',
      );
      controller.setOrder(order);
      controller.setSlotItem(7, BlacksmithItem.create(2));
      controller.fulfillOrder(7);
      expect(spy.celebrateCalls, equals(1));

      // 7. Fulfill wrong order
      controller.setSlotItem(8, BlacksmithItem.create(1));
      controller.fulfillOrder(8);
      expect(spy.wrongCalls, equals(2));

      controller.dispose();
    });

    testWidgets('Audio toggle button updates mute state and icon on MergeBlacksmithScreen',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();
      final audio = AudioController();
      await audio.init(storage);

      final controller = MergeBlacksmithController(
        storage: storage,
        audio: audio,
        autoStart: false,
      );

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(
          storage: storage,
          controller: controller,
        ),
      ));
      await tester.pump();

      expect(audio.isMuted, isFalse);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      // Tap mute button
      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();

      expect(audio.isMuted, isTrue);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(storage.getSfxEnabled(), isFalse);
      expect(storage.getBgmEnabled(), isFalse);

      // Tap again to unmute
      await tester.tap(find.byIcon(Icons.volume_off_rounded));
      await tester.pump();

      expect(audio.isMuted, isFalse);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(storage.getSfxEnabled(), isTrue);
      expect(storage.getBgmEnabled(), isTrue);

      controller.dispose();
    });
  });

  group('Challenger 2 M2: Storage Saving & Integrity Under Stress', () {
    test('GameStorage persists high score and stars correctly across sessions', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();

      final controller1 = MergeBlacksmithController(
        storage: storage,
        autoStart: false,
      );

      // Fulfill order for 100 points -> 1 star
      controller1.setOrder(const CustomerOrder(
        targetLevel: 2,
        rewardScore: 100,
        customerName: 'Test',
        avatarEmoji: '👑',
      ));
      controller1.setSlotItem(0, BlacksmithItem.create(2));
      controller1.fulfillOrder(0);
      expect(controller1.score, equals(100));
      expect(controller1.stars, equals(1));

      await controller1.saveResult();

      expect(storage.getLevelHighScore('merge_blacksmith', 1), equals(100));
      expect(storage.getLevelStars('merge_blacksmith', 1), equals(1));
      expect(storage.getTotalStars(), equals(1));
      expect(storage.getHighestUnlockedLevel('merge_blacksmith'), equals(2));

      controller1.dispose();

      // Second session with higher score: 300 points -> 3 stars
      final controller2 = MergeBlacksmithController(
        storage: storage,
        autoStart: false,
      );

      controller2.setOrder(const CustomerOrder(
        targetLevel: 5,
        rewardScore: 500,
        customerName: 'Hero',
        avatarEmoji: '✨',
      ));
      controller2.setSlotItem(0, BlacksmithItem.create(5));
      controller2.fulfillOrder(0);
      expect(controller2.score, equals(500));
      expect(controller2.stars, equals(3));

      await controller2.saveResult();

      expect(storage.getLevelHighScore('merge_blacksmith', 1), equals(500));
      expect(storage.getLevelStars('merge_blacksmith', 1), equals(3));
      // Total stars earned was 1 + (3 - 1) = 3
      expect(storage.getTotalStars(), equals(3));

      controller2.dispose();
    });

    test('High score and star monotonicity: inferior score does not overwrite superior record',
        () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();

      // Pre-set highscore 600 with 3 stars
      await storage.saveLevelResult('merge_blacksmith', 1, 600, 3);
      expect(storage.getLevelHighScore('merge_blacksmith', 1), equals(600));
      expect(storage.getLevelStars('merge_blacksmith', 1), equals(3));

      // Run new game with only 50 points (1 star)
      final controller = MergeBlacksmithController(
        storage: storage,
        autoStart: false,
      );
      controller.setOrder(const CustomerOrder(
        targetLevel: 1,
        rewardScore: 50,
        customerName: 'Squire',
        avatarEmoji: '🛡️',
      ));
      controller.setSlotItem(0, BlacksmithItem.create(1));
      controller.fulfillOrder(0);
      expect(controller.score, equals(50));
      expect(controller.stars, equals(1));

      await controller.saveResult();

      // Prior superior score and stars must be preserved
      expect(storage.getLevelHighScore('merge_blacksmith', 1), equals(600));
      expect(storage.getLevelStars('merge_blacksmith', 1), equals(3));
      expect(storage.getTotalStars(), equals(3));

      controller.dispose();
    });
  });

  group('Challenger 2 M2: Game Over and Victory Dialog Flows', () {
    testWidgets('GameOverDialog shown when ordersFulfilled == 0 and triggers reset on Try Again',
        (WidgetTester tester) async {
      int? reportedGameOverScore;
      final controller = MergeBlacksmithController(autoStart: false);
      controller.start();

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(
          controller: controller,
          onGameOver: (score) {
            reportedGameOverScore = score;
          },
        ),
      ));
      await tester.pump();

      expect(find.byType(GameOverDialog), findsNothing);
      expect(find.byType(VictoryDialog), findsNothing);

      // Trigger game over manually with 0 orders
      controller.triggerGameOverManually();
      await tester.pumpAndSettle();

      expect(reportedGameOverScore, equals(0));
      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(find.text('Out of Hearts!'), findsOneWidget);
      expect(find.text('Try Again!'), findsOneWidget);

      // Tap Try Again! button
      await tester.tap(find.text('Try Again!'));
      await tester.pumpAndSettle();

      // Dialog is dismissed and controller reset
      expect(find.byType(GameOverDialog), findsNothing);
      expect(controller.isGameOver, isFalse);
      expect(controller.score, equals(0));

      controller.dispose();
    });

    testWidgets('VictoryDialog shown when ordersFulfilled > 0 and triggers reset on Again!',
        (WidgetTester tester) async {
      int? reportedScore;
      final controller = MergeBlacksmithController(autoStart: false);
      controller.start();

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(
          controller: controller,
          onGameOver: (score) {
            reportedScore = score;
          },
        ),
      ));
      await tester.pump();

      // Fulfill an order
      controller.setOrder(const CustomerOrder(
        targetLevel: 2,
        rewardScore: 100,
        customerName: 'Knight',
        avatarEmoji: '🛡️',
      ));
      controller.setSlotItem(0, BlacksmithItem.create(2));
      controller.fulfillOrder(0);
      await tester.pump();

      expect(controller.ordersFulfilled, equals(1));
      expect(controller.score, equals(100));

      // Trigger game over with orders fulfilled
      controller.triggerGameOverManually();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(reportedScore, equals(100));
      expect(find.byType(VictoryDialog), findsOneWidget);
      expect(find.text('Again!'), findsOneWidget);
      expect(find.descendant(of: find.byType(VictoryDialog), matching: find.text('100')), findsOneWidget);

      // Tap Again! button
      await tester.tap(find.text('Again!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(VictoryDialog), findsNothing);
      expect(controller.isGameOver, isFalse);
      expect(controller.ordersFulfilled, equals(0));

      controller.dispose();
    });

    testWidgets('Exit button in dialog invokes onExit callback',
        (WidgetTester tester) async {
      bool onExitCalled = false;
      final controller = MergeBlacksmithController(autoStart: false);
      controller.start();

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(
          controller: controller,
          onExit: () {
            onExitCalled = true;
          },
        ),
      ));
      await tester.pump();

      controller.triggerGameOverManually();
      await tester.pumpAndSettle();

      expect(find.byType(GameOverDialog), findsOneWidget);
      expect(find.text('Exit'), findsOneWidget);

      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();

      expect(onExitCalled, isTrue);

      controller.dispose();
    });
  });

  group('Challenger 2 M2: Screen Constraints, Taps & Lifecycle', () {
    testWidgets('Rapid clicking Forge button when grid fills handles full state gracefully',
        (WidgetTester tester) async {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.start();

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      // Rapidly click "Forge!" 25 times
      for (int i = 0; i < 25; i++) {
        await tester.tap(find.text('Forge!'));
        await tester.pump(const Duration(milliseconds: 10));
      }

      // Board has exactly 20 slots, cannot exceed 20
      expect(controller.slots.length, equals(20));
      expect(tester.takeException(), isNull);

      controller.dispose();
    });

    testWidgets('Renders without overflow on extreme small screen (320x480)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MergeBlacksmithController(autoStart: false);
      controller.start();

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);

      controller.dispose();
    });

    testWidgets('Renders without overflow on large tablet screen (1024x768)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = MergeBlacksmithController(autoStart: false);
      controller.start();

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);

      controller.dispose();
    });

    testWidgets('Unmounting screen with active internal timer disposes cleanly',
        (WidgetTester tester) async {
      bool mountedScreen = true;
      late StateSetter triggerRebuild;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              triggerRebuild = setState;
              return mountedScreen
                  ? const MergeBlacksmithScreen()
                  : const Scaffold(body: Text('Unmounted'));
            },
          ),
        ),
      );
      await tester.pump();

      // Advance 1 second into timer
      await tester.pump(const Duration(seconds: 1));

      // Unmount screen
      triggerRebuild(() {
        mountedScreen = false;
      });
      await tester.pump();

      expect(find.text('Unmounted'), findsOneWidget);

      // Advance clock past timer ticks
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });
  });
}
