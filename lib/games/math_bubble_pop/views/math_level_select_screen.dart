import 'package:flutter/material.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/storage/game_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/star_rating_display.dart';
import '../models/math_level.dart';
import 'math_bubble_pop_screen.dart';

class MathLevelSelectScreen extends StatefulWidget {
  final GameStorage storage;

  const MathLevelSelectScreen({super.key, required this.storage});

  @override
  State<MathLevelSelectScreen> createState() => _MathLevelSelectScreenState();
}

class _MathLevelSelectScreenState extends State<MathLevelSelectScreen> {
  @override
  Widget build(BuildContext context) {
    final highestUnlocked = widget.storage.getHighestUnlockedLevel('math_bubble_pop');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE1F5FE), // Light sky blue
              Color(0xFFB3E5FC),
              Color(0xFF81D4FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.deepBlue,
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
                          Text('Select Level', style: AppTheme.titleFont.copyWith(fontSize: 26)),
                          Text(
                            'Bubble speed & math complexity increase each level!',
                            style: AppTheme.bodyFont.copyWith(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Levels List
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: MathLevel.allLevels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final level = MathLevel.allLevels[index];
                    final isUnlocked = level.number <= highestUnlocked;
                    final stars = widget.storage.getLevelStars('math_bubble_pop', level.number);
                    final highScore = widget.storage.getLevelHighScore('math_bubble_pop', level.number);

                    return GestureDetector(
                      onTap: () async {
                        if (isUnlocked) {
                          AudioController().playClick();
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MathBubblePopScreen(
                                level: level,
                                storage: widget.storage,
                              ),
                            ),
                          );
                          setState(() {}); // Refresh stars and unlocked state
                        } else {
                          AudioController().playWrong();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppTheme.amberOrange,
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
                                          '${level.baseSpeed.toInt()} px/s',
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
                                        color: AppTheme.deepBlue,
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
