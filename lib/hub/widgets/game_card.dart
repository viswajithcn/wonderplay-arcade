import 'package:flutter/material.dart';
import '../../core/audio/audio_controller.dart';
import '../../core/storage/game_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mini_game_model.dart';
import '../../shared/widgets/star_rating_display.dart';

class GameCard extends StatelessWidget {
  final MiniGameMetadata game;
  final GameStorage storage;
  final Function(GameDifficulty difficulty) onPlayGame;

  const GameCard({
    super.key,
    required this.game,
    required this.storage,
    required this.onPlayGame,
  });

  @override
  Widget build(BuildContext context) {
    int highestStars = 0;
    for (int i = 1; i <= 6; i++) {
      final s = storage.getLevelStars(game.id, i);
      if (s > highestStars) highestStars = s;
    }

    return InkWell(
      onTap: () {
        if (game.isAvailable) {
          AudioController().playClick();
          onPlayGame(GameDifficulty.easy);
        } else {
          AudioController().playWrong();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppTheme.bubblePurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Text(
                '${game.title} is coming soon! Stay tuned! 🚀',
                style: AppTheme.bodyFont.copyWith(color: Colors.white),
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              game.primaryColor,
              game.accentColor,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: game.accentColor.withValues(alpha: 0.35),
              offset: const Offset(0, 8),
              blurRadius: 14,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background subtle circle pattern
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(game.icon, size: 36, color: game.primaryColor),
                      ),
                      if (game.isAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: StarRatingDisplay(stars: highestStars, starSize: 18),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_clock_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Soon',
                                style: AppTheme.bodyFont.copyWith(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    game.title,
                    style: AppTheme.headingFont.copyWith(
                      color: Colors.white,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyFont.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      game.ageRecommendation,
                      style: AppTheme.bodyFont.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
