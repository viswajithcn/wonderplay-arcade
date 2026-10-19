import 'package:flutter/material.dart';

class AnimalData {
  final String name;
  final String emoji;
  final String soundHint;

  const AnimalData({
    required this.name,
    required this.emoji,
    required this.soundHint,
  });
}

class MemoryPlayer {
  final int index;
  final String name;
  final String shortName;
  final String emoji;
  final Color color;
  int pairsMatched;
  int score;

  MemoryPlayer({
    required this.index,
    required this.name,
    required this.shortName,
    required this.emoji,
    required this.color,
    this.pairsMatched = 0,
    this.score = 0,
  });

  static List<MemoryPlayer> createPlayers(int count) {
    const presets = [
      (name: 'Player 1', shortName: 'P1', emoji: '🦁', color: Color(0xFF29B6F6)),
      (name: 'Player 2', shortName: 'P2', emoji: '🐼', color: Color(0xFFFF5252)),
      (name: 'Player 3', shortName: 'P3', emoji: '🦊', color: Color(0xFF66BB6A)),
      (name: 'Player 4', shortName: 'P4', emoji: '🦄', color: Color(0xFFFFA000)),
    ];
    final clampedCount = count.clamp(1, presets.length);
    return List.generate(clampedCount, (i) {
      final p = presets[i];
      return MemoryPlayer(
        index: i,
        name: p.name,
        shortName: p.shortName,
        emoji: p.emoji,
        color: p.color,
      );
    });
  }
}

class AnimalCardModel {
  final int id;
  final AnimalData animal;
  bool isFaceUp;
  bool isMatched;
  bool isShaking;
  bool hasBeenSeen;
  int? matchedByPlayer;
  Color? matchedPlayerColor;

  AnimalCardModel({
    required this.id,
    required this.animal,
    this.isFaceUp = false,
    this.isMatched = false,
    this.isShaking = false,
    this.hasBeenSeen = false,
    this.matchedByPlayer,
    this.matchedPlayerColor,
  });

  static const List<AnimalData> pool = [
    AnimalData(name: 'Lion', emoji: '🦁', soundHint: 'Roar!'),
    AnimalData(name: 'Panda', emoji: '🐼', soundHint: 'Munch!'),
    AnimalData(name: 'Elephant', emoji: '🐘', soundHint: 'Trumpet!'),
    AnimalData(name: 'Fox', emoji: '🦊', soundHint: 'Yip!'),
    AnimalData(name: 'Monkey', emoji: '🐵', soundHint: 'Ooh ooh!'),
    AnimalData(name: 'Frog', emoji: '🐸', soundHint: 'Ribbit!'),
    AnimalData(name: 'Penguin', emoji: '🐧', soundHint: 'Waddle!'),
    AnimalData(name: 'Rabbit', emoji: '🐰', soundHint: 'Hop hop!'),
    AnimalData(name: 'Giraffe', emoji: '🦒', soundHint: 'Tall!'),
    AnimalData(name: 'Tiger', emoji: '🐯', soundHint: 'Grrr!'),
    AnimalData(name: 'Unicorn', emoji: '🦄', soundHint: 'Neigh!'),
    AnimalData(name: 'Dolphin', emoji: '🐬', soundHint: 'Click click!'),
  ];
}
