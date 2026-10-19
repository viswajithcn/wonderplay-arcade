import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/storage/game_storage.dart';
import '../models/blacksmith_item.dart';
import '../models/customer_order.dart';

class MergeBlacksmithController extends ChangeNotifier {
  static const int rows = 5;
  static const int cols = 4;
  static const int totalSlots = rows * cols; // 20 slots

  final AudioController _audio;
  final GameStorage? _storage;
  final Random _random;
  final Duration _spawnInterval;

  final List<BlacksmithItem?> _slots = List<BlacksmithItem?>.filled(totalSlots, null);
  CustomerOrder? _currentOrder;
  int _score = 0;
  int _ordersFulfilled = 0;
  int _mergesCount = 0;
  bool _isGameOver = false;
  String? _feedbackMessage;

  Timer? _spawnTimer;
  int _secondsUntilSpawn = 3;

  MergeBlacksmithController({
    AudioController? audio,
    GameStorage? storage,
    Random? random,
    Duration spawnInterval = const Duration(seconds: 3),
    bool autoStart = true,
  })  : _audio = audio ?? AudioController(),
        _storage = storage,
        _random = random ?? Random(),
        _spawnInterval = spawnInterval {
    if (autoStart) {
      start();
    }
  }

  // Getters
  List<BlacksmithItem?> get slots => List.unmodifiable(_slots);
  CustomerOrder? get currentOrder => _currentOrder;
  int get score => _score;
  int get ordersFulfilled => _ordersFulfilled;
  int get mergesCount => _mergesCount;
  bool get isGameOver => _isGameOver;
  String? get feedbackMessage => _feedbackMessage;
  int get secondsUntilSpawn => _secondsUntilSpawn;
  bool get isFull => _slots.every((item) => item != null);
  int get emptySlotCount => _slots.where((item) => item == null).length;

  int get stars {
    if (_score >= 250) return 3;
    if (_score >= 150) return 2;
    if (_score > 0) return 1;
    return 0;
  }

  void start() {
    _slots.fillRange(0, totalSlots, null);
    _score = 0;
    _ordersFulfilled = 0;
    _mergesCount = 0;
    _isGameOver = false;
    _feedbackMessage = null;

    // Initialize with 2 initial Lv 1 items in random empty slots
    _spawnInitialItems(2);

    // Initial customer order
    _generateNewOrder();

    _startSpawnTimer();
    notifyListeners();
  }

  void _spawnInitialItems(int count) {
    for (int i = 0; i < count; i++) {
      spawnItem(level: 1, playSound: false);
    }
  }

  void _startSpawnTimer() {
    _spawnTimer?.cancel();
    _secondsUntilSpawn = _spawnInterval.inSeconds > 0 ? _spawnInterval.inSeconds : 3;

    // 1-second countdown ticker for UI progress
    _spawnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isGameOver) {
        timer.cancel();
        return;
      }

      _secondsUntilSpawn--;
      if (_secondsUntilSpawn <= 0) {
        _secondsUntilSpawn = _spawnInterval.inSeconds > 0 ? _spawnInterval.inSeconds : 3;
        spawnItem(level: 1, playSound: true);
      } else {
        notifyListeners();
      }
    });
  }

  void _generateNewOrder() {
    _currentOrder = CustomerOrder.generateRandom(random: _random);
  }

  /// Manually or automatically spawn a new item into a random empty slot.
  bool spawnItem({int level = 1, bool playSound = true}) {
    if (_isGameOver) return false;

    final emptyIndices = <int>[];
    for (int i = 0; i < totalSlots; i++) {
      if (_slots[i] == null) {
        emptyIndices.add(i);
      }
    }

    if (emptyIndices.isEmpty) {
      _checkGridlock();
      return false;
    }

    final targetIndex = emptyIndices[_random.nextInt(emptyIndices.length)];
    _slots[targetIndex] = BlacksmithItem.create(level);

    if (playSound) {
      _audio.playPop();
    }

    _checkGridlock();
    notifyListeners();
    return true;
  }

  /// Directly set a slot's item (useful for tests or state setup).
  void setSlotItem(int index, BlacksmithItem? item) {
    if (index >= 0 && index < totalSlots) {
      _slots[index] = item;
      _checkGridlock();
      notifyListeners();
    }
  }

  /// Directly set current order (useful for testing).
  void setOrder(CustomerOrder order) {
    _currentOrder = order;
    _checkGridlock();
    notifyListeners();
  }

  /// Drag and drop merge or move from one slot to another.
  bool mergeOrMove(int fromIndex, int toIndex) {
    if (_isGameOver) return false;
    if (fromIndex < 0 || fromIndex >= totalSlots) return false;
    if (toIndex < 0 || toIndex >= totalSlots) return false;
    if (fromIndex == toIndex) return false;

    final fromItem = _slots[fromIndex];
    if (fromItem == null) return false;

    final toItem = _slots[toIndex];

    // Case 1: Target slot is empty -> Move
    if (toItem == null) {
      _slots[toIndex] = fromItem;
      _slots[fromIndex] = null;
      _audio.playPop();
      _feedbackMessage = null;
      notifyListeners();
      return true;
    }

    // Case 2: Target slot has same level item -> Merge
    if (fromItem.level == toItem.level) {
      // Both Level 5 -> Reached max level
      if (fromItem.level >= 5) {
        _feedbackMessage = 'Max Level 5 reached! Deliver to customer!';
        _audio.playWrong();
        notifyListeners();
        return false;
      }

      final nextLevel = fromItem.level + 1;
      final mergedItem = BlacksmithItem.create(nextLevel);
      _slots[toIndex] = mergedItem;
      _slots[fromIndex] = null;

      final pointsGained = nextLevel * 10;
      _score += pointsGained;
      _mergesCount++;
      _feedbackMessage = 'Forged ${mergedItem.name}! (+$pointsGained pts)';

      _audio.playCorrect();
      _checkGridlock();
      notifyListeners();
      return true;
    }

    // Case 3: Target slot has different level -> Swap
    _slots[toIndex] = fromItem;
    _slots[fromIndex] = toItem;
    _audio.playPop();
    _feedbackMessage = null;
    notifyListeners();
    return true;
  }

  /// Deliver an item from a slot to the customer order banner.
  bool fulfillOrder(int slotIndex) {
    if (_isGameOver) return false;
    if (slotIndex < 0 || slotIndex >= totalSlots) return false;

    final item = _slots[slotIndex];
    if (item == null || _currentOrder == null) return false;

    if (item.level == _currentOrder!.targetLevel) {
      final reward = _currentOrder!.rewardScore;
      final customer = _currentOrder!.customerName;

      _slots[slotIndex] = null;
      _score += reward;
      _ordersFulfilled++;
      _feedbackMessage = '$customer served! (+$reward pts)';

      _audio.playCelebrate();
      _generateNewOrder();
      _checkGridlock();
      notifyListeners();
      return true;
    } else {
      _feedbackMessage =
          'Customer wants a Lv ${_currentOrder!.targetLevel} ${CustomerOrder.getTargetItemName(_currentOrder!.targetLevel)}!';
      _audio.playWrong();
      notifyListeners();
      return false;
    }
  }

  /// Checks if any moves or deliveries are possible on the current grid.
  bool canMakeAnyMove() {
    if (emptySlotCount > 0) return true;
    if (hasValidMerge()) return true;
    if (hasMatchingOrder()) return true;
    return false;
  }

  bool hasValidMerge() {
    for (int i = 0; i < totalSlots; i++) {
      final itemA = _slots[i];
      if (itemA == null || itemA.level >= 5) continue;
      for (int j = i + 1; j < totalSlots; j++) {
        final itemB = _slots[j];
        if (itemB != null && itemA.level == itemB.level) {
          return true;
        }
      }
    }
    return false;
  }

  bool hasMatchingOrder() {
    if (_currentOrder == null) return false;
    for (final item in _slots) {
      if (item != null && item.level == _currentOrder!.targetLevel) {
        return true;
      }
    }
    return false;
  }

  void _checkGridlock() {
    if (isFull && !canMakeAnyMove()) {
      _isGameOver = true;
      _spawnTimer?.cancel();
      _feedbackMessage = 'Gridlock! No more moves possible.';
      saveResult();
    }
  }

  void triggerGameOverManually() {
    _isGameOver = true;
    _spawnTimer?.cancel();
    saveResult();
    notifyListeners();
  }

  Future<void> saveResult() async {
    if (_storage != null) {
      await _storage.saveLevelResult('merge_blacksmith', 1, _score, stars);
    }
  }

  void reset() {
    _spawnTimer?.cancel();
    start();
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    super.dispose();
  }
}
