import 'package:flutter/material.dart';
import '../../core/audio/audio_controller.dart';
import '../../core/theme/app_theme.dart';
import 'kid_button.dart';

class GameOverDialog extends StatelessWidget {
  final int score;
  final int questionsAnswered;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const GameOverDialog({
    super.key,
    required this.score,
    required this.questionsAnswered,
    required this.onRetry,
    required this.onExit,
  });

  static Future<void> show({
    required BuildContext context,
    required int score,
    required int questionsAnswered,
    required VoidCallback onRetry,
    required VoidCallback onExit,
  }) {
    AudioController().playWrong();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => GameOverDialog(
        score: score,
        questionsAnswered: questionsAnswered,
        onRetry: onRetry,
        onExit: onExit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFFF5252), width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              offset: const Offset(0, 10),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '💔',
              style: TextStyle(fontSize: 54),
            ),
            const SizedBox(height: 8),
            Text(
              'Out of Hearts!',
              style: AppTheme.titleFont.copyWith(
                color: const Color(0xFFFF5252),
                fontSize: 30,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              "Don't give up! You're learning fast!\nPractice makes progress. 💪",
              style: AppTheme.bodyFont.copyWith(
                color: Colors.grey.shade700,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Score', style: AppTheme.bodyFont.copyWith(fontSize: 14, color: Colors.grey.shade600)),
                      Text('$score', style: AppTheme.headingFont.copyWith(color: AppTheme.deepBlue)),
                    ],
                  ),
                  Container(width: 1, height: 32, color: Colors.grey.shade300),
                  Column(
                    children: [
                      Text('Cleared', style: AppTheme.bodyFont.copyWith(fontSize: 14, color: Colors.grey.shade600)),
                      Text('$questionsAnswered', style: AppTheme.headingFont.copyWith(color: AppTheme.mintGreen)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                KidButton(
                  minWidth: 100,
                  height: 48,
                  color: Colors.grey.shade300,
                  shadowColor: Colors.grey.shade500,
                  onPressed: () {
                    Navigator.of(context).pop();
                    onExit();
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_rounded, color: AppTheme.darkText, size: 20),
                      const SizedBox(width: 4),
                      Text('Exit', style: AppTheme.bodyFont),
                    ],
                  ),
                ),
                KidButton(
                  minWidth: 130,
                  height: 48,
                  color: const Color(0xFFFF5252),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onRetry();
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        'Try Again!',
                        style: AppTheme.bodyFont.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
