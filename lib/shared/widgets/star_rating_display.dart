import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StarRatingDisplay extends StatelessWidget {
  final int stars; // 0 to 3
  final double starSize;
  final bool animate;

  const StarRatingDisplay({
    super.key,
    required this.stars,
    this.starSize = 36,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isFilled = index < stars;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Icon(
            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: starSize,
            color: isFilled ? AppTheme.sunnyYellow : Colors.grey.shade400,
            shadows: isFilled
                ? [
                    Shadow(
                      color: AppTheme.amberOrange.withValues(alpha: 0.8),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }
}
