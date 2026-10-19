import 'package:flutter/material.dart';

class HeartsDisplay extends StatelessWidget {
  final int maxHearts;
  final int remainingHearts;

  const HeartsDisplay({
    super.key,
    this.maxHearts = 3,
    required this.remainingHearts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(maxHearts, (index) {
          final isAlive = index < remainingHearts;
          return AnimatedScale(
            scale: isAlive ? 1.0 : 0.85,
            duration: const Duration(milliseconds: 300),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Icon(
                isAlive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isAlive ? const Color(0xFFFF1744) : Colors.grey.shade400,
                size: 26,
                shadows: isAlive
                    ? [
                        Shadow(
                          color: const Color(0xFFFF5252).withValues(alpha: 0.6),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
