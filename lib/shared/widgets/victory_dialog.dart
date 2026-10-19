import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../../core/audio/audio_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/mini_game_model.dart';
import 'kid_button.dart';
import 'star_rating_display.dart';

class VictoryDialog extends StatefulWidget {
  final GameResult result;
  final VoidCallback onPlayAgain;
  final VoidCallback onExit;

  const VictoryDialog({
    super.key,
    required this.result,
    required this.onPlayAgain,
    required this.onExit,
  });

  static Future<void> show({
    required BuildContext context,
    required GameResult result,
    required VoidCallback onPlayAgain,
    required VoidCallback onExit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => VictoryDialog(
        result: result,
        onPlayAgain: onPlayAgain,
        onExit: onExit,
      ),
    );
  }

  @override
  State<VictoryDialog> createState() => _VictoryDialogState();
}

class _VictoryDialogState extends State<VictoryDialog> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
    AudioController().playCelebrate();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String _getPraiseText() {
    switch (widget.result.stars) {
      case 3:
        return 'Super Genius! 🌟';
      case 2:
        return 'Great Job! 🎉';
      default:
        return 'Awesome Effort! 👏';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: AppTheme.sunnyYellow, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  offset: const Offset(0, 10),
                  blurRadius: 20,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Text(
                  _getPraiseText(),
                  style: AppTheme.titleFont.copyWith(
                    color: AppTheme.bubblePurple,
                    fontSize: 30,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                StarRatingDisplay(
                  stars: widget.result.stars,
                  starSize: 52,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.lightBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Score:', style: AppTheme.bodyFont.copyWith(fontSize: 18)),
                          Text(
                            '${widget.result.score}',
                            style: AppTheme.headingFont.copyWith(
                              color: AppTheme.deepBlue,
                              fontSize: 22,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Accuracy:', style: AppTheme.bodyFont.copyWith(fontSize: 18)),
                          Text(
                            '${widget.result.correctAnswers}/${widget.result.totalQuestions}',
                            style: AppTheme.headingFont.copyWith(
                              color: AppTheme.mintGreen,
                              fontSize: 22,
                            ),
                          ),
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
                        widget.onExit();
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.home_rounded, color: AppTheme.darkText),
                          const SizedBox(width: 6),
                          Text('Home', style: AppTheme.bodyFont),
                        ],
                      ),
                    ),
                    KidButton(
                      minWidth: 130,
                      height: 48,
                      color: AppTheme.mintGreen,
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onPlayAgain();
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.replay_rounded, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Again!',
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
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: pi / 2, // shoot downwards
          blastDirectionality: BlastDirectionality.explosive,
          maxBlastForce: 20,
          minBlastForce: 8,
          emissionFrequency: 0.05,
          numberOfParticles: 30,
          gravity: 0.25,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple,
            Colors.yellow,
          ],
        ),
      ],
    );
  }
}
