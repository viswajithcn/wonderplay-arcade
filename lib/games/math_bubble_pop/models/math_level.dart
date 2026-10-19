import 'package:flutter/material.dart';

enum MathOperationType {
  easyAddition,
  mediumAddition,
  subtraction,
  mixedAddSub,
  multiplication,
  threeNumbersAndMultiplication,
}

class MathLevel {
  final int number;
  final String title;
  final String subtitle;
  final double baseSpeed;
  final int questionCount;
  final MathOperationType operationType;
  final Color color;

  const MathLevel({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.baseSpeed,
    required this.questionCount,
    required this.operationType,
    required this.color,
  });

  static List<MathLevel> allLevels = const [
    MathLevel(
      number: 1,
      title: 'Baby Bubbles',
      subtitle: 'Gentle sums up to 10 (1+2, 3+2)',
      baseSpeed: 55.0,
      questionCount: 6,
      operationType: MathOperationType.easyAddition,
      color: Color(0xFF66BB6A), // Green
    ),
    MathLevel(
      number: 2,
      title: 'Quick Sums',
      subtitle: 'Faster floating sums up to 20',
      baseSpeed: 70.0,
      questionCount: 7,
      operationType: MathOperationType.mediumAddition,
      color: Color(0xFF29B6F6), // Blue
    ),
    MathLevel(
      number: 3,
      title: 'Subtraction Splash',
      subtitle: 'Take away numbers (15-6, 9-4)',
      baseSpeed: 85.0,
      questionCount: 8,
      operationType: MathOperationType.subtraction,
      color: Color(0xFFFFA000), // Amber
    ),
    MathLevel(
      number: 4,
      title: 'Mixed Whirlpool',
      subtitle: 'Speedy mixed addition & subtraction',
      baseSpeed: 100.0,
      questionCount: 8,
      operationType: MathOperationType.mixedAddSub,
      color: Color(0xFFAB47BC), // Purple
    ),
    MathLevel(
      number: 5,
      title: 'Multiplication Magic',
      subtitle: 'Times tables (2×3, 4×5, 6×7)',
      baseSpeed: 115.0,
      questionCount: 8,
      operationType: MathOperationType.multiplication,
      color: Color(0xFFFF5252), // Coral Red
    ),
    MathLevel(
      number: 6,
      title: 'Math Wizard Champion',
      subtitle: 'Super fast! 3-number sums (3+4+2) & large times tables',
      baseSpeed: 135.0,
      questionCount: 10,
      operationType: MathOperationType.threeNumbersAndMultiplication,
      color: Color(0xFF00B0FF), // Electric Cyan
    ),
  ];
}
