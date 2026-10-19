import 'package:flutter/material.dart';

class BlacksmithItem {
  static int _idCounter = 0;

  final int id;
  final int level;
  final String name;
  final String emoji;
  final IconData icon;
  final Color color;
  final Color secondaryColor;
  final int points;

  const BlacksmithItem({
    required this.id,
    required this.level,
    required this.name,
    required this.emoji,
    required this.icon,
    required this.color,
    required this.secondaryColor,
    required this.points,
  });

  factory BlacksmithItem.create(int level, {int? id}) {
    final itemId = id ?? ++_idCounter;
    switch (level) {
      case 1:
        return BlacksmithItem(
          id: itemId,
          level: 1,
          name: 'Iron Ingot',
          emoji: '🧱',
          icon: Icons.view_in_ar_rounded,
          color: const Color(0xFF78909C),
          secondaryColor: const Color(0xFF455A64),
          points: 10,
        );
      case 2:
        return BlacksmithItem(
          id: itemId,
          level: 2,
          name: 'Bronze Dagger',
          emoji: '🗡️',
          icon: Icons.colorize_rounded,
          color: const Color(0xFF8D6E63),
          secondaryColor: const Color(0xFF5D4037),
          points: 25,
        );
      case 3:
        return BlacksmithItem(
          id: itemId,
          level: 3,
          name: 'Iron Shortsword',
          emoji: '⚔️',
          icon: Icons.shield_rounded,
          color: const Color(0xFF29B6F6),
          secondaryColor: const Color(0xFF0288D1),
          points: 60,
        );
      case 4:
        return BlacksmithItem(
          id: itemId,
          level: 4,
          name: 'Steel Battleaxe',
          emoji: '🪓',
          icon: Icons.carpenter_rounded,
          color: const Color(0xFFAB47BC),
          secondaryColor: const Color(0xFF7B1FA2),
          points: 150,
        );
      case 5:
        return BlacksmithItem(
          id: itemId,
          level: 5,
          name: 'Enchanted Blade',
          emoji: '✨',
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFFFFB300),
          secondaryColor: const Color(0xFFFF8F00),
          points: 350,
        );
      default:
        throw ArgumentError('Invalid blacksmith item level: $level. Must be 1 to 5.');
    }
  }

  BlacksmithItem copyWith({
    int? id,
    int? level,
    String? name,
    String? emoji,
    IconData? icon,
    Color? color,
    Color? secondaryColor,
    int? points,
  }) {
    return BlacksmithItem(
      id: id ?? this.id,
      level: level ?? this.level,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      points: points ?? this.points,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlacksmithItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          level == other.level;

  @override
  int get hashCode => id.hashCode ^ level.hashCode;

  @override
  String toString() => 'BlacksmithItem(id: $id, level: $level, name: $name)';
}
