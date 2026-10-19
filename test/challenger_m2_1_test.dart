import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kids_games/core/storage/game_storage.dart';
import 'package:kids_games/games/merge_blacksmith/controllers/merge_blacksmith_controller.dart';
import 'package:kids_games/games/merge_blacksmith/models/blacksmith_item.dart';
import 'package:kids_games/games/merge_blacksmith/models/customer_order.dart';
import 'package:kids_games/games/merge_blacksmith/views/merge_blacksmith_screen.dart';
import 'package:kids_games/games/merge_blacksmith/widgets/customer_order_banner.dart';
import 'package:kids_games/games/merge_blacksmith/widgets/forge_slot_widget.dart';

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

  group('Challenger M2-1: Adversarial Rapid Stress & Invariant Oracle', () {
    test('Simulate 1,000 rapid random operations and verify invariants hold', () {
      final rng = Random(1337);
      final controller = MergeBlacksmithController(
        autoStart: false,
        random: rng,
      );
      controller.start();

      int expectedScore = 0;
      int expectedMerges = 0;
      int expectedOrdersFulfilled = 0;

      for (int step = 0; step < 1000; step++) {
        if (controller.isGameOver) {
          // Verify gridlock condition
          expect(controller.isFull, isTrue);
          expect(controller.canMakeAnyMove(), isFalse);
          break;
        }

        // Action selection: 0 = spawn, 1 = move/merge/swap, 2 = fulfill order
        final action = rng.nextInt(3);

        if (action == 0) {
          final wasFull = controller.isFull;
          final spawned = controller.spawnItem();
          if (wasFull) {
            expect(spawned, isFalse);
          } else {
            expect(spawned, isTrue);
          }
        } else if (action == 1) {
          final from = rng.nextInt(MergeBlacksmithController.totalSlots);
          final to = rng.nextInt(MergeBlacksmithController.totalSlots);

          final fromItem = controller.slots[from];
          final toItem = controller.slots[to];

          if (from == to || fromItem == null) {
            final res = controller.mergeOrMove(from, to);
            expect(res, isFalse);
          } else if (toItem == null) {
            // Move
            final res = controller.mergeOrMove(from, to);
            expect(res, isTrue);
            expect(controller.slots[from], isNull);
            expect(controller.slots[to]!.level, equals(fromItem.level));
          } else if (fromItem.level == toItem.level) {
            if (fromItem.level >= 5) {
              // Lv 5 merge rejected
              final res = controller.mergeOrMove(from, to);
              expect(res, isFalse);
              expect(controller.slots[from]!.level, equals(5));
              expect(controller.slots[to]!.level, equals(5));
            } else {
              // Valid merge
              final nextLevel = fromItem.level + 1;
              final res = controller.mergeOrMove(from, to);
              expect(res, isTrue);
              expectedMerges++;
              expectedScore += nextLevel * 10;
              expect(controller.slots[from], isNull);
              expect(controller.slots[to]!.level, equals(nextLevel));
            }
          } else {
            // Swap
            final fromLevel = fromItem.level;
            final toLevel = toItem.level;
            final res = controller.mergeOrMove(from, to);
            expect(res, isTrue);
            expect(controller.slots[from]!.level, equals(toLevel));
            expect(controller.slots[to]!.level, equals(fromLevel));
          }
        } else {
          // Fulfill order
          final slot = rng.nextInt(MergeBlacksmithController.totalSlots);
          final item = controller.slots[slot];
          final order = controller.currentOrder;

          if (item != null && order != null && item.level == order.targetLevel) {
            final reward = order.rewardScore;
            final res = controller.fulfillOrder(slot);
            expect(res, isTrue);
            expectedOrdersFulfilled++;
            expectedScore += reward;
            expect(controller.slots[slot], isNull);
          } else {
            final res = controller.fulfillOrder(slot);
            expect(res, isFalse);
          }
        }

        // Invariant checks after every single operation
        expect(controller.slots.length, equals(20));
        expect(controller.score, equals(expectedScore));
        expect(controller.mergesCount, equals(expectedMerges));
        expect(controller.ordersFulfilled, equals(expectedOrdersFulfilled));

        for (final item in controller.slots) {
          if (item != null) {
            expect(item.level, inInclusiveRange(1, 5));
          }
        }
        expect(controller.emptySlotCount + controller.slots.where((s) => s != null).length, equals(20));
        expect(controller.isFull, equals(controller.emptySlotCount == 0));
      }

      controller.dispose();
    });
  });

  group('Challenger M2-1: Move, Swap, and Merge Boundary Stress', () {
    test('Self-merge (from == to) is rejected and leaves item intact', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.setSlotItem(4, BlacksmithItem.create(3));

      expect(controller.mergeOrMove(4, 4), isFalse);
      expect(controller.slots[4]!.level, equals(3));
      expect(controller.mergesCount, equals(0));
      expect(controller.score, equals(0));

      controller.dispose();
    });

    test('Out of bounds source and target indices are strictly rejected', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.setSlotItem(0, BlacksmithItem.create(2));

      expect(controller.mergeOrMove(-1, 0), isFalse);
      expect(controller.mergeOrMove(0, -1), isFalse);
      expect(controller.mergeOrMove(20, 0), isFalse);
      expect(controller.mergeOrMove(0, 20), isFalse);
      expect(controller.mergeOrMove(-5, 25), isFalse);

      expect(controller.slots[0]!.level, equals(2));

      controller.dispose();
    });

    test('Moving from empty slot to another empty slot returns false', () {
      final controller = MergeBlacksmithController(autoStart: false);
      expect(controller.slots[0], isNull);
      expect(controller.slots[1], isNull);

      expect(controller.mergeOrMove(0, 1), isFalse);
      expect(controller.slots[0], isNull);
      expect(controller.slots[1], isNull);

      controller.dispose();
    });

    test('Moving from empty slot to occupied slot returns false without modifying target', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.setSlotItem(5, BlacksmithItem.create(4));

      expect(controller.mergeOrMove(0, 5), isFalse);
      expect(controller.slots[5]!.level, equals(4));
      expect(controller.slots[0], isNull);

      controller.dispose();
    });

    test('Complete merge ladder from Level 1 up to Level 5 accumulates exact scores', () {
      final controller = MergeBlacksmithController(autoStart: false);

      // Place 16 Lv 1 items (which can form one Lv 5)
      for (int i = 0; i < 16; i++) {
        controller.setSlotItem(i, BlacksmithItem.create(1));
      }

      int runningScore = 0;
      int runningMerges = 0;

      // 8 merges: 1 + 1 -> 2
      for (int i = 0; i < 8; i++) {
        final src = i * 2;
        final dst = i * 2 + 1;
        expect(controller.mergeOrMove(src, dst), isTrue);
        runningScore += 20; // Lv 2 * 10
        runningMerges++;
        expect(controller.slots[dst]!.level, equals(2));
        expect(controller.slots[src], isNull);
      }
      expect(controller.score, equals(runningScore));
      expect(controller.mergesCount, equals(runningMerges));

      // 4 merges: 2 + 2 -> 3
      final lv2Slots = [1, 3, 5, 7, 9, 11, 13, 15];
      final lv3Slots = <int>[];
      for (int i = 0; i < 4; i++) {
        final src = lv2Slots[i * 2];
        final dst = lv2Slots[i * 2 + 1];
        expect(controller.mergeOrMove(src, dst), isTrue);
        runningScore += 30; // Lv 3 * 10
        runningMerges++;
        expect(controller.slots[dst]!.level, equals(3));
        expect(controller.slots[src], isNull);
        lv3Slots.add(dst);
      }
      expect(controller.score, equals(runningScore));

      // 2 merges: 3 + 3 -> 4
      final lv4Slots = <int>[];
      for (int i = 0; i < 2; i++) {
        final src = lv3Slots[i * 2];
        final dst = lv3Slots[i * 2 + 1];
        expect(controller.mergeOrMove(src, dst), isTrue);
        runningScore += 40; // Lv 4 * 10
        runningMerges++;
        expect(controller.slots[dst]!.level, equals(4));
        expect(controller.slots[src], isNull);
        lv4Slots.add(dst);
      }
      expect(controller.score, equals(runningScore));

      // 1 merge: 4 + 4 -> 5
      expect(controller.mergeOrMove(lv4Slots[0], lv4Slots[1]), isTrue);
      runningScore += 50; // Lv 5 * 10
      runningMerges++;
      expect(controller.slots[lv4Slots[1]]!.level, equals(5));
      expect(controller.slots[lv4Slots[0]], isNull);

      expect(controller.score, equals(runningScore));
      expect(controller.mergesCount, equals(15)); // 8 + 4 + 2 + 1 = 15 merges

      controller.dispose();
    });
  });

  group('Challenger M2-1: Level 5 Rejection & Swapping', () {
    test('Lv 5 + Lv 5 merge is strictly rejected from both directions', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.setSlotItem(0, BlacksmithItem.create(5));
      controller.setSlotItem(1, BlacksmithItem.create(5));

      // 0 -> 1
      expect(controller.mergeOrMove(0, 1), isFalse);
      expect(controller.slots[0]!.level, equals(5));
      expect(controller.slots[1]!.level, equals(5));
      expect(controller.score, equals(0));
      expect(controller.mergesCount, equals(0));

      // 1 -> 0
      expect(controller.mergeOrMove(1, 0), isFalse);
      expect(controller.slots[0]!.level, equals(5));
      expect(controller.slots[1]!.level, equals(5));
      expect(controller.score, equals(0));

      controller.dispose();
    });

    test('Lv 5 items can swap with other levels (1, 2, 3, 4)', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.setSlotItem(0, BlacksmithItem.create(5));

      for (int targetLevel = 1; targetLevel <= 4; targetLevel++) {
        controller.setSlotItem(1, BlacksmithItem.create(targetLevel));

        expect(controller.mergeOrMove(0, 1), isTrue);
        expect(controller.slots[0]!.level, equals(targetLevel));
        expect(controller.slots[1]!.level, equals(5));

        // Swap back
        expect(controller.mergeOrMove(1, 0), isTrue);
        expect(controller.slots[0]!.level, equals(5));
        expect(controller.slots[1]!.level, equals(targetLevel));
      }

      controller.dispose();
    });
  });

  group('Challenger M2-1: Order Fulfillment & Rejection Matrix', () {
    test('Every level mismatch (1..5 vs order 1..5) is strictly rejected', () {
      final controller = MergeBlacksmithController(autoStart: false);

      for (int orderLevel = 1; orderLevel <= 5; orderLevel++) {
        for (int itemLevel = 1; itemLevel <= 5; itemLevel++) {
          controller.setOrder(CustomerOrder(
            targetLevel: orderLevel,
            rewardScore: CustomerOrder.calculateReward(orderLevel),
            customerName: 'Customer $orderLevel',
            avatarEmoji: '👤',
          ));
          controller.setSlotItem(0, BlacksmithItem.create(itemLevel));

          if (itemLevel == orderLevel) {
            final fulfilled = controller.fulfillOrder(0);
            expect(fulfilled, isTrue);
            expect(controller.slots[0], isNull);
          } else {
            final fulfilled = controller.fulfillOrder(0);
            expect(fulfilled, isFalse);
            expect(controller.slots[0]!.level, equals(itemLevel));
          }
        }
      }

      controller.dispose();
    });

    test('Delivering empty slot or out-of-bounds slot returns false', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.setOrder(const CustomerOrder(
        targetLevel: 2,
        rewardScore: 100,
        customerName: 'Tester',
        avatarEmoji: '🛡️',
      ));

      expect(controller.fulfillOrder(0), isFalse);
      expect(controller.fulfillOrder(-1), isFalse);
      expect(controller.fulfillOrder(20), isFalse);
      expect(controller.fulfillOrder(999), isFalse);
      expect(controller.score, equals(0));
      expect(controller.ordersFulfilled, equals(0));

      controller.dispose();
    });
  });

  group('Challenger M2-1: Heterogeneous Gridlock Detection', () {
    test('Gridlock triggered when full with 16 Lv 5s and 1 of each Lv 1..4 (no pairs, no matching order)', () {
      final controller = MergeBlacksmithController(autoStart: false);

      // Set initial order to Lv 5 so board is NOT in gridlock while setting items
      controller.setOrder(const CustomerOrder(
        targetLevel: 5,
        rewardScore: 500,
        customerName: 'King',
        avatarEmoji: '👑',
      ));

      // Board layout:
      // Slots 0..15: Lv 5 (16 items, max level, cannot merge)
      // Slot 16: Lv 1
      // Slot 17: Lv 2
      // Slot 18: Lv 3
      // Slot 19: Lv 4
      for (int i = 0; i < 16; i++) {
        controller.setSlotItem(i, BlacksmithItem.create(5));
      }
      controller.setSlotItem(16, BlacksmithItem.create(1));
      controller.setSlotItem(17, BlacksmithItem.create(2));
      controller.setSlotItem(18, BlacksmithItem.create(3));
      controller.setSlotItem(19, BlacksmithItem.create(4));

      expect(controller.isFull, isTrue);
      // Lv 5s cannot merge, Lv 1..4 have only 1 item each
      expect(controller.hasValidMerge(), isFalse);

      // Has matching order because order wants Lv 5 and board has Lv 5
      expect(controller.hasMatchingOrder(), isTrue);
      expect(controller.canMakeAnyMove(), isTrue);
      expect(controller.isGameOver, isFalse);

      // Fulfill order for slot 0 (Lv 5)
      expect(controller.fulfillOrder(0), isTrue);
      expect(controller.slots[0], isNull);
      expect(controller.isFull, isFalse);
      expect(controller.canMakeAnyMove(), isTrue);

      // Reset order to Lv 5
      controller.setOrder(const CustomerOrder(
        targetLevel: 5,
        rewardScore: 500,
        customerName: 'King',
        avatarEmoji: '👑',
      ));

      // Put Lv 5 back in slot 0
      controller.setSlotItem(0, BlacksmithItem.create(5));

      // Replace Lv 4 with Lv 5 in slot 19
      // Now board has: 17 Lv 5s, 1 Lv 1, 1 Lv 2, 1 Lv 3, and ZERO Lv 4s!
      controller.setSlotItem(19, BlacksmithItem.create(5));

      // Now set customer order to Lv 4 (which is absent from the board)
      controller.setOrder(const CustomerOrder(
        targetLevel: 4,
        rewardScore: 350,
        customerName: 'Archer',
        avatarEmoji: '🏹',
      ));

      // Board status:
      // Full (20/20)
      expect(controller.isFull, isTrue);
      // Valid merges: None (17 Lv 5s cannot merge, and single Lv 1, 2, 3 have no partners)
      expect(controller.hasValidMerge(), isFalse);
      // Matching order: False (wants Lv 4, board has 5, 1, 2, 3)
      expect(controller.hasMatchingOrder(), isFalse);
      // canMakeAnyMove: must be false
      expect(controller.canMakeAnyMove(), isFalse);
      // isGameOver: must be true
      expect(controller.isGameOver, isTrue);

      // Operations after Game Over must be blocked
      expect(controller.spawnItem(), isFalse);
      expect(controller.mergeOrMove(16, 17), isFalse);
      expect(controller.fulfillOrder(18), isFalse);

      controller.dispose();
    });

    test('Reset after Game Over restores state and clears gridlock', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.triggerGameOverManually();
      expect(controller.isGameOver, isTrue);

      controller.reset();
      expect(controller.isGameOver, isFalse);
      expect(controller.score, equals(0));
      expect(controller.mergesCount, equals(0));
      expect(controller.ordersFulfilled, equals(0));
      expect(controller.slots.where((s) => s != null).length, equals(2));

      controller.dispose();
    });
  });

  group('Challenger M2-1: Timer & Concurrency Safety', () {
    test('Dispose cancels spawn timer and prevents memory leak', () {
      final controller = MergeBlacksmithController(
        autoStart: true,
        spawnInterval: const Duration(seconds: 1),
      );

      expect(controller.secondsUntilSpawn, equals(1));
      controller.dispose();

      // Controller is disposed, no crashes occur
    });

    test('Start resets existing timer if called multiple times', () {
      final controller = MergeBlacksmithController(
        autoStart: true,
        spawnInterval: const Duration(seconds: 3),
      );

      controller.start();
      controller.start();
      expect(controller.isGameOver, isFalse);
      expect(controller.slots.where((s) => s != null).length, equals(2));

      controller.dispose();
    });
  });

  group('Challenger M2-1: UI Widget Gesture & Drag-and-Drop Tests', () {
    testWidgets('Drag and drop merge between two slots on MergeBlacksmithScreen updates UI to Lv 2',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();
      final controller = MergeBlacksmithController(
        storage: storage,
        autoStart: false,
      );
      // Explicitly set slot 0 and slot 1 to Lv 1
      controller.setSlotItem(0, BlacksmithItem.create(1));
      controller.setSlotItem(1, BlacksmithItem.create(1));

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(
          storage: storage,
          controller: controller,
        ),
      ));
      await tester.pump();

      expect(find.text('Lv 1'), findsNWidgets(2));

      // Find the Draggable at slot 0
      final slot0Finder = find.widgetWithText(ForgeSlotWidget, 'Lv 1').first;
      final slot1Finder = find.widgetWithText(ForgeSlotWidget, 'Lv 1').last;

      // Drag from slot 0 to slot 1
      await tester.drag(slot0Finder, tester.getCenter(slot1Finder) - tester.getCenter(slot0Finder));
      await tester.pumpAndSettle();

      // Now slot 0 is empty and slot 1 is Lv 2
      expect(controller.slots[0], isNull);
      expect(controller.slots[1]!.level, equals(2));
      expect(find.text('Lv 2'), findsOneWidget);
      expect(find.text('Forged Bronze Dagger! (+20 pts)'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Drag item to CustomerOrderBanner on MergeBlacksmithScreen fulfills order and awards score',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();
      final controller = MergeBlacksmithController(
        storage: storage,
        autoStart: false,
      );
      controller.setOrder(const CustomerOrder(
        targetLevel: 3,
        rewardScore: 200,
        customerName: 'Sir Galahad',
        avatarEmoji: '🛡️',
      ));
      controller.setSlotItem(2, BlacksmithItem.create(3));

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(
          storage: storage,
          controller: controller,
        ),
      ));
      await tester.pump();

      expect(find.text('Sir Galahad'), findsOneWidget);
      expect(find.text('Lv 3'), findsNWidgets(2)); // One in banner, one in slot

      final slotFinder = find.widgetWithText(ForgeSlotWidget, 'Lv 3');
      final bannerFinder = find.byType(CustomerOrderBanner);

      await tester.drag(slotFinder, tester.getCenter(bannerFinder) - tester.getCenter(slotFinder));
      await tester.pumpAndSettle();

      expect(controller.slots[2], isNull);
      expect(controller.score, equals(200));
      expect(controller.ordersFulfilled, equals(1));
      expect(find.text('Sir Galahad served! (+200 pts)'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Drag wrong item to CustomerOrderBanner displays warning banner',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();
      final controller = MergeBlacksmithController(
        storage: storage,
        autoStart: false,
      );
      controller.setOrder(const CustomerOrder(
        targetLevel: 4,
        rewardScore: 350,
        customerName: 'Queen Guinevere',
        avatarEmoji: '👑',
      ));
      controller.setSlotItem(3, BlacksmithItem.create(1)); // Lv 1 item

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(
          storage: storage,
          controller: controller,
        ),
      ));
      await tester.pump();

      final slotFinder = find.widgetWithText(ForgeSlotWidget, 'Lv 1');
      final bannerFinder = find.byType(CustomerOrderBanner);

      await tester.drag(slotFinder, tester.getCenter(bannerFinder) - tester.getCenter(slotFinder));
      await tester.pumpAndSettle();

      // Verify no RenderFlex overflow occurs when feedback banner appears
      final overflowError = tester.takeException();
      expect(overflowError, isNull, reason: 'RenderFlex overflow should not occur when feedback banner appears');

      expect(controller.slots[3]!.level, equals(1));
      expect(controller.score, equals(0));
      expect(find.textContaining('Customer wants a Lv 4 Steel Battleaxe!'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Drag Lv 5 to Lv 5 displays max level reached warning banner',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();
      final controller = MergeBlacksmithController(
        storage: storage,
        autoStart: false,
      );
      controller.setSlotItem(0, BlacksmithItem.create(5));
      controller.setSlotItem(1, BlacksmithItem.create(5));

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(
          storage: storage,
          controller: controller,
        ),
      ));
      await tester.pump();

      final slot0 = find.widgetWithText(ForgeSlotWidget, 'Lv 5').first;
      final slot1 = find.widgetWithText(ForgeSlotWidget, 'Lv 5').last;

      await tester.drag(slot0, tester.getCenter(slot1) - tester.getCenter(slot0));
      await tester.pumpAndSettle();

      expect(controller.slots[0]!.level, equals(5));
      expect(controller.slots[1]!.level, equals(5));
      expect(find.text('Max Level 5 reached! Deliver to customer!'), findsOneWidget);

      controller.dispose();
    });
  });
}
