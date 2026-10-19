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
import 'package:flutter/services.dart';
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

  group('BlacksmithItem Model Tests', () {
    test('Creates valid items for levels 1 through 5', () {
      final item1 = BlacksmithItem.create(1);
      expect(item1.level, equals(1));
      expect(item1.name, equals('Iron Ingot'));
      expect(item1.points, equals(10));
      expect(item1.emoji, equals('🧱'));

      final item2 = BlacksmithItem.create(2);
      expect(item2.level, equals(2));
      expect(item2.name, equals('Bronze Dagger'));
      expect(item2.points, equals(25));
      expect(item2.emoji, equals('🗡️'));

      final item3 = BlacksmithItem.create(3);
      expect(item3.level, equals(3));
      expect(item3.name, equals('Iron Shortsword'));
      expect(item3.points, equals(60));
      expect(item3.emoji, equals('⚔️'));

      final item4 = BlacksmithItem.create(4);
      expect(item4.level, equals(4));
      expect(item4.name, equals('Steel Battleaxe'));
      expect(item4.points, equals(150));
      expect(item4.emoji, equals('🪓'));

      final item5 = BlacksmithItem.create(5);
      expect(item5.level, equals(5));
      expect(item5.name, equals('Enchanted Blade'));
      expect(item5.points, equals(350));
    });

    test('Throws ArgumentError for invalid levels', () {
      expect(() => BlacksmithItem.create(0), throwsArgumentError);
      expect(() => BlacksmithItem.create(6), throwsArgumentError);
      expect(() => BlacksmithItem.create(-1), throwsArgumentError);
    });

    test('copyWith creates modified copy correctly', () {
      final original = BlacksmithItem.create(1, id: 100);
      final modified = original.copyWith(name: 'Custom Ingot', points: 20);

      expect(modified.id, equals(100));
      expect(modified.level, equals(1));
      expect(modified.name, equals('Custom Ingot'));
      expect(modified.points, equals(20));
      expect(original.name, equals('Iron Ingot'));
    });

    test('Equality and toString work as expected', () {
      final itemA = BlacksmithItem.create(2, id: 42);
      final itemB = BlacksmithItem.create(2, id: 42);
      final itemC = BlacksmithItem.create(3, id: 43);

      expect(itemA, equals(itemB));
      expect(itemA.hashCode, equals(itemB.hashCode));
      expect(itemA == itemC, isFalse);
      expect(itemA.toString(), contains('Bronze Dagger'));
    });
  });

  group('CustomerOrder Model Tests', () {
    test('Calculates reward points according to item level', () {
      expect(CustomerOrder.calculateReward(1), equals(50));
      expect(CustomerOrder.calculateReward(2), equals(100));
      expect(CustomerOrder.calculateReward(3), equals(200));
      expect(CustomerOrder.calculateReward(4), equals(350));
      expect(CustomerOrder.calculateReward(5), equals(500));
    });

    test('Returns correct item names for customer orders', () {
      expect(CustomerOrder.getTargetItemName(1), equals('Iron Ingot'));
      expect(CustomerOrder.getTargetItemName(2), equals('Bronze Dagger'));
      expect(CustomerOrder.getTargetItemName(3), equals('Iron Shortsword'));
      expect(CustomerOrder.getTargetItemName(4), equals('Steel Battleaxe'));
      expect(CustomerOrder.getTargetItemName(5), equals('Enchanted Blade'));
    });

    test('Generates random orders within requested level range', () {
      final rng = Random(42);
      for (int i = 0; i < 20; i++) {
        final order = CustomerOrder.generateRandom(random: rng, minLevel: 2, maxLevel: 5);
        expect(order.targetLevel, inInclusiveRange(2, 5));
        expect(order.rewardScore, equals(CustomerOrder.calculateReward(order.targetLevel)));
        expect(order.customerName, isNotEmpty);
        expect(order.avatarEmoji, isNotEmpty);
      }
    });

    test('Equality and toString work as expected', () {
      const order1 = CustomerOrder(
        targetLevel: 3,
        rewardScore: 200,
        customerName: 'Knight Arthur',
        avatarEmoji: '🛡️',
      );
      const order2 = CustomerOrder(
        targetLevel: 3,
        rewardScore: 200,
        customerName: 'Knight Arthur',
        avatarEmoji: '🛡️',
      );

      expect(order1, equals(order2));
      expect(order1.hashCode, equals(order2.hashCode));
      expect(order1.toString(), contains('Knight Arthur'));
    });
  });

  group('MergeBlacksmithController Logic Tests', () {
    test('Initializes with 20 slots and exactly 2 initial Lv 1 items', () {
      final controller = MergeBlacksmithController(
        autoStart: true,
        spawnInterval: const Duration(seconds: 3),
      );

      expect(controller.slots.length, equals(20));
      final occupiedSlots = controller.slots.where((item) => item != null).toList();
      expect(occupiedSlots.length, equals(2));
      expect(occupiedSlots.every((item) => item!.level == 1), isTrue);
      expect(controller.score, equals(0));
      expect(controller.ordersFulfilled, equals(0));
      expect(controller.mergesCount, equals(0));
      expect(controller.currentOrder, isNotNull);
      expect(controller.isGameOver, isFalse);

      controller.dispose();
    });

    test('Spawning populates random empty slot with Lv 1 item', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.start();

      final initialCount = controller.slots.where((s) => s != null).length;
      expect(initialCount, equals(2));

      final success = controller.spawnItem(level: 1);
      expect(success, isTrue);

      final newCount = controller.slots.where((s) => s != null).length;
      expect(newCount, equals(3));

      controller.dispose();
    });

    test('Spawning when grid is completely full returns false without crashing', () {
      final controller = MergeBlacksmithController(autoStart: false);
      // Fill all 20 slots
      for (int i = 0; i < 20; i++) {
        controller.setSlotItem(i, BlacksmithItem.create(1));
      }

      expect(controller.isFull, isTrue);
      final success = controller.spawnItem();
      expect(success, isFalse);

      controller.dispose();
    });

    test('Merging identical levels combines them into next level and increments score', () {
      final controller = MergeBlacksmithController(autoStart: false);

      // Place two Lv 1 items at slots 0 and 1
      controller.setSlotItem(0, BlacksmithItem.create(1));
      controller.setSlotItem(1, BlacksmithItem.create(1));

      final merged = controller.mergeOrMove(0, 1);
      expect(merged, isTrue);
      expect(controller.slots[0], isNull);
      expect(controller.slots[1]!.level, equals(2));
      expect(controller.score, equals(20)); // Level 2 * 10 = 20
      expect(controller.mergesCount, equals(1));

      // Merge Lv 2 + Lv 2 -> Lv 3
      controller.setSlotItem(2, BlacksmithItem.create(2));
      final merged2 = controller.mergeOrMove(2, 1);
      expect(merged2, isTrue);
      expect(controller.slots[2], isNull);
      expect(controller.slots[1]!.level, equals(3));
      expect(controller.score, equals(50)); // 20 + (3 * 10) = 50

      // Merge Lv 3 + Lv 3 -> Lv 4
      controller.setSlotItem(3, BlacksmithItem.create(3));
      final merged3 = controller.mergeOrMove(3, 1);
      expect(merged3, isTrue);
      expect(controller.slots[1]!.level, equals(4));
      expect(controller.score, equals(90)); // 50 + 40 = 90

      // Merge Lv 4 + Lv 4 -> Lv 5
      controller.setSlotItem(4, BlacksmithItem.create(4));
      final merged4 = controller.mergeOrMove(4, 1);
      expect(merged4, isTrue);
      expect(controller.slots[1]!.level, equals(5));
      expect(controller.score, equals(140)); // 90 + 50 = 140

      controller.dispose();
    });

    test('Merging two Level 5 items is rejected and keeps both items', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.setSlotItem(0, BlacksmithItem.create(5));
      controller.setSlotItem(1, BlacksmithItem.create(5));

      final merged = controller.mergeOrMove(0, 1);
      expect(merged, isFalse);
      expect(controller.slots[0]!.level, equals(5));
      expect(controller.slots[1]!.level, equals(5));
      expect(controller.feedbackMessage, contains('Max Level 5 reached'));

      controller.dispose();
    });

    test('Moving an item to an empty slot clears source and fills target', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.setSlotItem(2, BlacksmithItem.create(3));
      controller.setSlotItem(7, null);

      final moved = controller.mergeOrMove(2, 7);
      expect(moved, isTrue);
      expect(controller.slots[2], isNull);
      expect(controller.slots[7]!.level, equals(3));

      controller.dispose();
    });

    test('Dragging an item onto a different level item swaps their slots', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.setSlotItem(3, BlacksmithItem.create(1));
      controller.setSlotItem(8, BlacksmithItem.create(4));

      final swapped = controller.mergeOrMove(3, 8);
      expect(swapped, isTrue);
      expect(controller.slots[3]!.level, equals(4));
      expect(controller.slots[8]!.level, equals(1));

      controller.dispose();
    });

    test('Invalid moves return false safely without mutating state', () {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.setSlotItem(0, BlacksmithItem.create(1));

      // Same index
      expect(controller.mergeOrMove(0, 0), isFalse);

      // Out of bounds
      expect(controller.mergeOrMove(-1, 5), isFalse);
      expect(controller.mergeOrMove(0, 25), isFalse);

      // Empty source
      expect(controller.mergeOrMove(5, 6), isFalse);

      controller.dispose();
    });

    test('Fulfilling customer order awards score, clears slot, and rotates order', () {
      final controller = MergeBlacksmithController(autoStart: false);
      const targetOrder = CustomerOrder(
        targetLevel: 3,
        rewardScore: 200,
        customerName: 'Sir Gallant',
        avatarEmoji: '🛡️',
      );
      controller.setOrder(targetOrder);
      controller.setSlotItem(4, BlacksmithItem.create(3));

      final fulfilled = controller.fulfillOrder(4);
      expect(fulfilled, isTrue);
      expect(controller.slots[4], isNull);
      expect(controller.score, equals(200));
      expect(controller.ordersFulfilled, equals(1));
      // Current order was rotated
      expect(controller.currentOrder, isNotNull);

      controller.dispose();
    });

    test('Delivering wrong item level to customer order is rejected', () {
      final controller = MergeBlacksmithController(autoStart: false);
      const targetOrder = CustomerOrder(
        targetLevel: 4,
        rewardScore: 350,
        customerName: 'Merlin',
        avatarEmoji: '🧙‍♂️',
      );
      controller.setOrder(targetOrder);
      controller.setSlotItem(5, BlacksmithItem.create(2)); // Lv 2 instead of Lv 4

      final fulfilled = controller.fulfillOrder(5);
      expect(fulfilled, isFalse);
      expect(controller.slots[5]!.level, equals(2));
      expect(controller.score, equals(0));
      expect(controller.ordersFulfilled, equals(0));
      expect(controller.feedbackMessage, contains('Customer wants a Lv 4'));

      controller.dispose();
    });

    test('Calculates star ratings accurately based on score thresholds', () {
      final controller = MergeBlacksmithController(autoStart: false);
      expect(controller.stars, equals(0)); // score 0

      controller.setOrder(const CustomerOrder(
        targetLevel: 2,
        rewardScore: 100,
        customerName: 'Test',
        avatarEmoji: '🛡️',
      ));
      controller.setSlotItem(0, BlacksmithItem.create(2));
      controller.fulfillOrder(0); // score 100
      expect(controller.score, equals(100));
      expect(controller.stars, equals(1)); // > 0 but < 150

      controller.setOrder(const CustomerOrder(
        targetLevel: 2,
        rewardScore: 100,
        customerName: 'Test',
        avatarEmoji: '🛡️',
      ));
      controller.setSlotItem(1, BlacksmithItem.create(2));
      controller.fulfillOrder(1); // score 200
      expect(controller.score, equals(200));
      expect(controller.stars, equals(2)); // >= 150 but < 250

      controller.setOrder(const CustomerOrder(
        targetLevel: 2,
        rewardScore: 100,
        customerName: 'Test',
        avatarEmoji: '🛡️',
      ));
      controller.setSlotItem(2, BlacksmithItem.create(2));
      controller.fulfillOrder(2); // score 300
      expect(controller.score, equals(300));
      expect(controller.stars, equals(3)); // >= 250

      controller.dispose();
    });

    test('Gridlock triggers Game Over when full with no valid merges or orders', () {
      final controller = MergeBlacksmithController(autoStart: false);

      // Set order requiring Lv 1
      controller.setOrder(const CustomerOrder(
        targetLevel: 1,
        rewardScore: 50,
        customerName: 'Wizard',
        avatarEmoji: '🧙‍♂️',
      ));

      // Fill board with all Lv 5 items (which cannot merge and don't match Lv 1 order)
      for (int i = 0; i < 20; i++) {
        controller.setSlotItem(i, BlacksmithItem.create(5));
      }

      expect(controller.isFull, isTrue);
      expect(controller.canMakeAnyMove(), isFalse);
      expect(controller.isGameOver, isTrue);

      controller.dispose();
    });

    test('GameStorage integration writes high score and stars', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await GameStorage.init();
      final controller = MergeBlacksmithController(
        storage: storage,
        autoStart: false,
      );

      controller.setOrder(const CustomerOrder(
        targetLevel: 4,
        rewardScore: 350,
        customerName: 'Hero',
        avatarEmoji: '👑',
      ));
      controller.setSlotItem(0, BlacksmithItem.create(4));
      controller.fulfillOrder(0);

      await controller.saveResult();

      expect(storage.getLevelHighScore('merge_blacksmith', 1), equals(350));
      expect(storage.getLevelStars('merge_blacksmith', 1), equals(3));
      expect(storage.getTotalStars(), equals(3));

      controller.dispose();
    });
  });

  group('Merge Blacksmith Widgets & UI Tests', () {
    testWidgets('ForgeSlotWidget renders empty slot and handles draggable item',
        (WidgetTester tester) async {
      int? mergedFrom;
      int? mergedTo;

      // 1. Render empty slot
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              height: 80,
              child: ForgeSlotWidget(
                slotIndex: 0,
                item: null,
                onMoveOrMerge: (from, to) {
                  mergedFrom = from;
                  mergedTo = to;
                },
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // 2. Render slot with Lv 2 item
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              height: 80,
              child: ForgeSlotWidget(
                slotIndex: 1,
                item: BlacksmithItem.create(2),
                onMoveOrMerge: (from, to) {
                  mergedFrom = from;
                  mergedTo = to;
                },
              ),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('🗡️'), findsOneWidget);
      expect(find.text('Lv 2'), findsOneWidget);
      expect(find.byType(Draggable<int>), findsOneWidget);
      expect(mergedFrom, isNull);
      expect(mergedTo, isNull);
    });

    testWidgets('CustomerOrderBanner displays customer info, requested item, and reward',
        (WidgetTester tester) async {
      int? deliveredSlot;
      const testOrder = CustomerOrder(
        targetLevel: 3,
        rewardScore: 200,
        customerName: 'Princess Fiona',
        avatarEmoji: '👑',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CustomerOrderBanner(
            order: testOrder,
            onFulfill: (slotIndex) {
              deliveredSlot = slotIndex;
            },
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Princess Fiona'), findsOneWidget);
      expect(find.text('👑'), findsOneWidget);
      expect(find.text('⚔️ Iron Shortsword'), findsOneWidget);
      expect(find.text('+200'), findsOneWidget);
      expect(find.text('Lv 3'), findsOneWidget);
      expect(find.byType(DragTarget<int>), findsOneWidget);
      expect(deliveredSlot, isNull);
    });

    testWidgets('MergeBlacksmithScreen renders full UI with 20 slots and header controls',
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
      controller.start();

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(
          storage: storage,
          controller: controller,
        ),
      ));
      await tester.pump();

      // Header components
      expect(find.text('Merge Blacksmith ⚒️'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stars_rounded), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

      // Customer Order Banner
      expect(find.byType(CustomerOrderBanner), findsOneWidget);

      // Exactly 20 ForgeSlotWidgets
      expect(find.byType(ForgeSlotWidget), findsNWidgets(20));

      // Forge button
      expect(find.text('Forge!'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Tapping Forge button on MergeBlacksmithScreen spawns item',
        (WidgetTester tester) async {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.start();

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      final initialOccupied = controller.slots.where((s) => s != null).length;
      expect(initialOccupied, equals(2));

      // Tap the Forge! button
      await tester.tap(find.text('Forge!'));
      await tester.pump();

      final newOccupied = controller.slots.where((s) => s != null).length;
      expect(newOccupied, equals(3));

      controller.dispose();
    });

    testWidgets('Recipe book bottom sheet opens when book icon is tapped',
        (WidgetTester tester) async {
      final controller = MergeBlacksmithController(autoStart: false);
      controller.start();

      await tester.pumpWidget(MaterialApp(
        home: MergeBlacksmithScreen(controller: controller),
      ));
      await tester.pump();

      // Tap recipe icon
      await tester.tap(find.byIcon(Icons.menu_book_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Forge Recipe Book 📖'), findsOneWidget);
      expect(find.text('Got It!'), findsOneWidget);

      // Close sheet
      await tester.tap(find.text('Got It!'));
      await tester.pumpAndSettle();

      expect(find.text('Forge Recipe Book 📖'), findsNothing);

      controller.dispose();
    });
  });
}
