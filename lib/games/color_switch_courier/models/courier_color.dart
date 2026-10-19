import 'package:flutter/material.dart';

/// The 3 colors used in Color Switch Courier, paired with geometric
/// accessibility glyphs so colorblind players can distinguish gates easily.
enum CourierColor {
  red,
  green,
  blue;

  /// High-visibility vibrant neon color for the courier ship shield and laser gates.
  Color get color {
    switch (this) {
      case CourierColor.red:
        return const Color(0xFFFF5252);
      case CourierColor.green:
        return const Color(0xFF66BB6A);
      case CourierColor.blue:
        return const Color(0xFF29B6F6);
    }
  }

  /// Darker accent color for borders or secondary glow.
  Color get accentColor {
    switch (this) {
      case CourierColor.red:
        return const Color(0xFFD32F2F);
      case CourierColor.green:
        return const Color(0xFF388E3C);
      case CourierColor.blue:
        return const Color(0xFF0288D1);
    }
  }

  /// Light tint for particle effects and sparks.
  Color get glowColor {
    switch (this) {
      case CourierColor.red:
        return const Color(0xFFFF8A80);
      case CourierColor.green:
        return const Color(0xFFB9F6CA);
      case CourierColor.blue:
        return const Color(0xFF80D8FF);
    }
  }

  /// Geometric accessibility glyph (Circle for Red, Triangle for Green, Square/Diamond for Blue).
  IconData get symbol {
    switch (this) {
      case CourierColor.red:
        return Icons.circle;
      case CourierColor.green:
        return Icons.change_history_rounded;
      case CourierColor.blue:
        return Icons.crop_square_rounded;
    }
  }

  /// Friendly capitalized display label.
  String get displayName {
    switch (this) {
      case CourierColor.red:
        return 'Red';
      case CourierColor.green:
        return 'Green';
      case CourierColor.blue:
        return 'Blue';
    }
  }

  /// Cycles to the next color in the sequence: Red -> Green -> Blue -> Red.
  CourierColor next() {
    switch (this) {
      case CourierColor.red:
        return CourierColor.green;
      case CourierColor.green:
        return CourierColor.blue;
      case CourierColor.blue:
        return CourierColor.red;
    }
  }

  /// Cycles to the previous color in the sequence.
  CourierColor prev() {
    switch (this) {
      case CourierColor.red:
        return CourierColor.blue;
      case CourierColor.green:
        return CourierColor.red;
      case CourierColor.blue:
        return CourierColor.green;
    }
  }

  /// Helper to look up a color by index modulo 3.
  static CourierColor fromIndex(int index) {
    final valuesList = CourierColor.values;
    return valuesList[((index % valuesList.length) + valuesList.length) % valuesList.length];
  }

  /// Helper to look up a color by name safely.
  static CourierColor fromString(String name) {
    return CourierColor.values.firstWhere(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
      orElse: () => CourierColor.red,
    );
  }
}
