import 'package:flutter/material.dart';

enum GameCategory {
  all('All Games', Icons.dashboard_rounded, Color(0xFF29B6F6)),
  math('Math & Numbers', Icons.calculate_rounded, Color(0xFFFF5252)),
  memory('Memory & Logic', Icons.psychology_rounded, Color(0xFFAB47BC)),
  puzzles('Puzzles & Shapes', Icons.extension_rounded, Color(0xFFFFA000)),
  action('Fun & Action', Icons.sports_esports_rounded, Color(0xFF66BB6A));

  final String label;
  final IconData icon;
  final Color color;
  const GameCategory(this.label, this.icon, this.color);
}

enum GameDifficulty {
  easy('Easy', 'Ages 4-6', Color(0xFF66BB6A)),
  medium('Medium', 'Ages 6-8', Color(0xFFFFA000)),
  hard('Hard', 'Ages 8+', Color(0xFFFF5252));

  final String title;
  final String ageRange;
  final Color color;
  const GameDifficulty(this.title, this.ageRange, this.color);
}

class MiniGameMetadata {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final GameCategory category;
  final IconData icon;
  final Color primaryColor;
  final Color accentColor;
  final String ageRecommendation;
  final bool isAvailable;
  final Widget Function(BuildContext context, GameDifficulty difficulty)? builder;
  Widget Function(BuildContext context, GameDifficulty difficulty)? get screenBuilder => builder;

  const MiniGameMetadata({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.icon,
    required this.primaryColor,
    required this.accentColor,
    required this.ageRecommendation,
    this.isAvailable = true,
    Widget Function(BuildContext context, GameDifficulty difficulty)? builder,
    Widget Function(BuildContext context, GameDifficulty difficulty)? screenBuilder,
  }) : builder = builder ?? screenBuilder;
}

class GameResult {
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  final int stars; // 1, 2, or 3
  final GameDifficulty difficulty;

  const GameResult({
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.stars,
    required this.difficulty,
  });
}
