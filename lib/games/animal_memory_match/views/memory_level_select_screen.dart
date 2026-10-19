import 'package:flutter/material.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/storage/game_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/star_rating_display.dart';
import '../models/animal_card_model.dart';
import '../models/memory_level.dart';
import 'animal_memory_match_screen.dart';

class MemoryLevelSelectScreen extends StatefulWidget {
  final GameStorage storage;

  const MemoryLevelSelectScreen({super.key, required this.storage});

  @override
  State<MemoryLevelSelectScreen> createState() => _MemoryLevelSelectScreenState();
}

class _MemoryLevelSelectScreenState extends State<MemoryLevelSelectScreen> {
  int _playerCount = 2; // Default to 2-Player Pass & Play

  @override
  Widget build(BuildContext context) {
    final highestUnlocked = widget.storage.getHighestUnlockedLevel('animal_memory_match');
    final isMultiplayer = _playerCount > 1;
    final activePlayers = MemoryPlayer.createPlayers(_playerCount);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF3E5F5), // Light lavender purple
              Color(0xFFE1BEE7),
              Color(0xFFCE93D8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Row(
                  children: [
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.bubblePurple,
                      ),
                      onPressed: () {
                        AudioController().playClick();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Memory Level', style: AppTheme.titleFont.copyWith(fontSize: 24)),
                          Text(
                            isMultiplayer
                                ? 'Pass & Play Multiplayer • Same Device!'
                                : 'Flip cards & match cute animal pairs!',
                            style: AppTheme.bodyFont.copyWith(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Pass & Play Player Count Selector Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.bubblePurple.withValues(alpha: 0.4), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.bubblePurple.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_alt_rounded, color: AppTheme.bubblePurple, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Pass & Play Players',
                            style: AppTheme.headingFont.copyWith(
                              fontSize: 15,
                              color: AppTheme.bubblePurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final count in [2, 3, 4, 1])
                            GestureDetector(
                              onTap: () {
                                AudioController().playClick();
                                setState(() => _playerCount = count);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: _playerCount == count
                                      ? AppTheme.bubblePurple
                                      : const Color(0xFFF3E5F5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _playerCount == count
                                        ? AppTheme.bubblePurple
                                        : Colors.purple.shade200,
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  count == 1 ? '1P Solo' : '$count Players',
                                  style: AppTheme.bodyFont.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _playerCount == count
                                        ? Colors.white
                                        : AppTheme.bubblePurple,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final p in activePlayers)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: p.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: p.color.withValues(alpha: 0.6), width: 1.5),
                              ),
                              child: Text(
                                '${p.emoji} ${p.name}',
                                style: AppTheme.bodyFont.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: p.color,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Levels List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: MemoryLevel.allLevels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final level = MemoryLevel.allLevels[index];
                    // In Pass & Play mode, unlock all board sizes so friends can play any grid!
                    final isUnlocked = isMultiplayer || level.number <= highestUnlocked;
                    final stars = widget.storage.getLevelStars('animal_memory_match', level.number);
                    final highScore = widget.storage.getLevelHighScore('animal_memory_match', level.number);

                    return GestureDetector(
                      onTap: () async {
                        if (isUnlocked) {
                          AudioController().playClick();
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AnimalMemoryMatchScreen(
                                level: level,
                                storage: widget.storage,
                                playerCount: _playerCount,
                              ),
                            ),
                          );
                          setState(() {});
                        } else {
                          AudioController().playWrong();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppTheme.bubblePurple,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              content: Text(
                                'Clear Level ${level.number - 1} with at least 1 star to unlock! 🔒',
                                style: AppTheme.bodyFont.copyWith(color: Colors.white),
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isUnlocked ? Colors.white : Colors.white.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isUnlocked ? level.color : Colors.grey.shade300,
                            width: isUnlocked ? 3 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isUnlocked
                                  ? level.color.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.04),
                              offset: const Offset(0, 5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Level Number Circle
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isUnlocked ? level.color : Colors.grey.shade400,
                                shape: BoxShape.circle,
                                boxShadow: isUnlocked
                                    ? [
                                        BoxShadow(
                                          color: level.color.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: isUnlocked
                                    ? Text(
                                        '${level.number}',
                                        style: AppTheme.headingFont.copyWith(
                                          color: Colors.white,
                                          fontSize: 26,
                                        ),
                                      )
                                    : const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Level Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        level.title,
                                        style: AppTheme.headingFont.copyWith(
                                          fontSize: 17,
                                          color: isUnlocked ? AppTheme.darkText : Colors.grey.shade600,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: level.color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${level.pairsCount * 2} cards',
                                          style: AppTheme.bodyFont.copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: level.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    level.subtitle,
                                    style: AppTheme.bodyFont.copyWith(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (isUnlocked && highScore > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Best Score: $highScore',
                                      style: AppTheme.bodyFont.copyWith(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.bubblePurple,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Stars / Lock indicator
                            if (isUnlocked)
                              StarRatingDisplay(stars: stars, starSize: 22)
                            else
                              const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 28),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
