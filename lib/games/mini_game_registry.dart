import 'package:flutter/material.dart';
import '../core/storage/game_storage.dart';
import '../models/mini_game_model.dart';
import 'animal_memory_match/views/memory_level_select_screen.dart';
import 'color_switch_courier/views/color_switch_courier_screen.dart';
import 'math_bubble_pop/views/math_level_select_screen.dart';
import 'merge_blacksmith/views/merge_blacksmith_screen.dart';

class MiniGameRegistry {
  static List<MiniGameMetadata> getGames(GameStorage storage) {
    return [
      MiniGameMetadata(
        id: 'math_bubble_pop',
        title: 'Math Bubble Pop',
        subtitle: 'Pop the bubble with the right answer!',
        description: 'Multi-level math challenge! Faster bubbles, bigger equations, 3 hearts life system, and stars to collect!',
        category: GameCategory.math,
        icon: Icons.bubble_chart_rounded,
        primaryColor: const Color(0xFF29B6F6),
        accentColor: const Color(0xFF0288D1),
        ageRecommendation: 'Ages 4–10',
        isAvailable: true,
        builder: (context, _) => MathLevelSelectScreen(storage: storage),
      ),
      MiniGameMetadata(
        id: 'animal_memory_match',
        title: 'Animal Memory Match',
        subtitle: 'Pass & Play multiplayer card matching!',
        description: 'Pass & Play with 2–4 friends on the same device (or play solo)! Flip 3D cards, match cute animals, and see who finds the most pairs!',
        category: GameCategory.memory,
        icon: Icons.style_rounded,
        primaryColor: const Color(0xFFAB47BC),
        accentColor: const Color(0xFF7B1FA2),
        ageRecommendation: 'Ages 3–10',
        isAvailable: true,
        builder: (context, _) => MemoryLevelSelectScreen(storage: storage),
      ),
      MiniGameMetadata(
        id: 'merge_blacksmith',
        title: 'Merge Blacksmith',
        subtitle: 'Forge & craft legendary tools!',
        description: 'Merge items on the forge grid to fulfill customer orders! 5 item levels, auto-spawning forge, and star ratings.',
        category: GameCategory.puzzles,
        icon: Icons.hardware,
        primaryColor: const Color(0xFFE65100),
        accentColor: const Color(0xFFFFB300),
        ageRecommendation: 'Ages 5–12',
        isAvailable: true,
        builder: (context, difficulty) => MergeBlacksmithScreen(storage: storage, difficulty: difficulty),
      ),
      MiniGameMetadata(
        id: 'color_switch_courier',
        title: 'Color Switch Courier',
        subtitle: 'Match laser gate colors at high speed!',
        description: 'Fast-paced color-matching action! Tap to cycle courier drone colors and pass safely through laser gates!',
        category: GameCategory.action,
        icon: Icons.palette,
        primaryColor: const Color(0xFF00B0FF),
        accentColor: const Color(0xFFFF4081),
        ageRecommendation: 'Ages 5–12',
        isAvailable: true,
        builder: (context, difficulty) => ColorSwitchCourierScreen(storage: storage, difficulty: difficulty),
      ),
      const MiniGameMetadata(
        id: 'shape_sorter',
        title: 'Color & Shape Sorter',
        subtitle: 'Drag geometric shapes to matching baskets!',
        description: 'Learn triangles, circles, stars, and bright colors through tactile drag and drop.',
        category: GameCategory.puzzles,
        icon: Icons.category_rounded,
        primaryColor: Color(0xFFFFA000),
        accentColor: Color(0xFFFF6F00),
        ageRecommendation: 'Ages 2–5',
        isAvailable: false,
      ),
      const MiniGameMetadata(
        id: 'balloon_pop',
        title: 'Sensory Balloon Pop',
        subtitle: 'Tap vibrant floating balloons!',
        description: 'Endless tapping joy with joyful pops and flying confetti for toddlers.',
        category: GameCategory.action,
        icon: Icons.celebration_rounded,
        primaryColor: Color(0xFFFF5252),
        accentColor: Color(0xFFD32F2F),
        ageRecommendation: 'Ages 2–4',
        isAvailable: false,
      ),
    ];
  }
}
