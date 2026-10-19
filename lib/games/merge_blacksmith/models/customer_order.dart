import 'dart:math';

class CustomerOrder {
  final int targetLevel;
  final int rewardScore;
  final String customerName;
  final String avatarEmoji;

  const CustomerOrder({
    required this.targetLevel,
    required this.rewardScore,
    required this.customerName,
    required this.avatarEmoji,
  });

  static const List<Map<String, String>> _customers = [
    {'name': 'Knight Arthur', 'avatar': '🛡️'},
    {'name': 'Wizard Merlin', 'avatar': '🧙‍♂️'},
    {'name': 'Princess Fiona', 'avatar': '👑'},
    {'name': 'Viking Ragnar', 'avatar': '🪓'},
    {'name': 'Captain Drake', 'avatar': '🏴‍☠️'},
    {'name': 'Elf Ranger Sylva', 'avatar': '🧝‍♀️'},
    {'name': 'Dwarf Miner Boris', 'avatar': '⛏️'},
    {'name': 'Paladin Claire', 'avatar': '⚔️'},
  ];

  static int calculateReward(int level) {
    switch (level) {
      case 1:
        return 50;
      case 2:
        return 100;
      case 3:
        return 200;
      case 4:
        return 350;
      case 5:
        return 500;
      default:
        return level * 100;
    }
  }

  static String getTargetItemName(int level) {
    switch (level) {
      case 1:
        return 'Iron Ingot';
      case 2:
        return 'Bronze Dagger';
      case 3:
        return 'Iron Shortsword';
      case 4:
        return 'Steel Battleaxe';
      case 5:
        return 'Enchanted Blade';
      default:
        return 'Weapon';
    }
  }

  factory CustomerOrder.generateRandom({
    Random? random,
    int minLevel = 2,
    int maxLevel = 5,
  }) {
    final rng = random ?? Random();
    final clampedMin = minLevel.clamp(1, 5);
    final clampedMax = maxLevel.clamp(clampedMin, 5);
    final targetLevel = clampedMin + rng.nextInt(clampedMax - clampedMin + 1);
    final customer = _customers[rng.nextInt(_customers.length)];

    return CustomerOrder(
      targetLevel: targetLevel,
      rewardScore: calculateReward(targetLevel),
      customerName: customer['name']!,
      avatarEmoji: customer['avatar']!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomerOrder &&
          runtimeType == other.runtimeType &&
          targetLevel == other.targetLevel &&
          rewardScore == other.rewardScore &&
          customerName == other.customerName &&
          avatarEmoji == other.avatarEmoji;

  @override
  int get hashCode =>
      targetLevel.hashCode ^
      rewardScore.hashCode ^
      customerName.hashCode ^
      avatarEmoji.hashCode;

  @override
  String toString() =>
      'CustomerOrder($customerName wants Lv $targetLevel for $rewardScore pts)';
}
