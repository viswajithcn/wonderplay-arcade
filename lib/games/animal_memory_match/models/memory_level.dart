import 'package:flutter/material.dart';

class MemoryLevel {
  final int number;
  final String title;
  final String subtitle;
  final int pairsCount;
  final int gridColumns;
  final int maxHearts;
  final Color color;

  const MemoryLevel({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.pairsCount,
    required this.gridColumns,
    required this.maxHearts,
    required this.color,
  });

  static List<MemoryLevel> allLevels = const [
    MemoryLevel(
      number: 1,
      title: 'Tiny Safari',
      subtitle: '3 pairs (6 cards) • Easy & Relaxed',
      pairsCount: 3,
      gridColumns: 3,
      maxHearts: 4,
      color: Color(0xFF66BB6A), // Mint Green
    ),
    MemoryLevel(
      number: 2,
      title: 'Friendly Forest',
      subtitle: '4 pairs (8 cards) • Getting fun!',
      pairsCount: 4,
      gridColumns: 4,
      maxHearts: 4,
      color: Color(0xFF29B6F6), // Sky Blue
    ),
    MemoryLevel(
      number: 3,
      title: 'Jungle Explorer',
      subtitle: '6 pairs (12 cards) • Concentration test',
      pairsCount: 6,
      gridColumns: 4,
      maxHearts: 5,
      color: Color(0xFFFFA000), // Amber
    ),
    MemoryLevel(
      number: 4,
      title: 'Animal Kingdom',
      subtitle: '8 pairs (16 cards) • Sharp memory challenge',
      pairsCount: 8,
      gridColumns: 4,
      maxHearts: 6,
      color: Color(0xFFAB47BC), // Purple
    ),
    MemoryLevel(
      number: 5,
      title: 'Master Memory Wizard',
      subtitle: '10 pairs (20 cards) • Memory champion!',
      pairsCount: 10,
      gridColumns: 5,
      maxHearts: 6,
      color: Color(0xFFFF5252), // Coral Red
    ),
  ];
}
