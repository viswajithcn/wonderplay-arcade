import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/storage/game_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/mini_game_model.dart';
import '../../../shared/widgets/game_over_dialog.dart';
import '../../../shared/widgets/hearts_display.dart';
import '../../../shared/widgets/kid_button.dart';
import '../game/gravity_glitch_game.dart';

/// Flutter screen hosting the Flame-based Gravity Glitch mini-game.
/// Displays top HUD (hearts, score, pause, back) and handles game-over dialogs.
class GravityGlitchScreen extends StatefulWidget {
  final GameStorage storage;
  final GameDifficulty difficulty;

  const GravityGlitchScreen({
    super.key,
    required this.storage,
    this.difficulty = GameDifficulty.medium,
  });

  @override
  State<GravityGlitchScreen> createState() => GravityGlitchScreenState();
}

class GravityGlitchScreenState extends State<GravityGlitchScreen> {
  late GravityGlitchGame _game;
  GravityGlitchGame get game => _game;
  int _lives = 3;
  int _score = 0;
  bool _isPaused = false;
  bool _isGameOver = false;

  Future<void> handleGameOver(int score, int obstaclesPassed) =>
      _handleGameOver(score, obstaclesPassed);

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    _game = GravityGlitchGame(
      onLivesChanged: (lives) {
        if (mounted) setState(() => _lives = lives);
      },
      onScoreChanged: (score) {
        if (mounted) setState(() => _score = score);
      },
      onGameOver: (score, obstaclesPassed) {
        _handleGameOver(score, obstaclesPassed);
      },
    );
  }

  Future<void> _handleGameOver(int score, int obstaclesPassed) async {
    if (!mounted || _isGameOver) return;
    setState(() => _isGameOver = true);

    // Calculate stars: 3 stars >= 100, 2 stars >= 50, 1 star > 0
    final stars = score >= 100 ? 3 : (score >= 50 ? 2 : (score > 0 ? 1 : 0));

    // Persist scores and stars
    await widget.storage.saveLevelResult('gravity_glitch', 1, score, stars);
    await widget.storage.saveGameResult(
      'gravity_glitch',
      widget.difficulty.name,
      score,
      stars,
    );

    if (stars > 0) {
      AudioController().playCelebrate();
    }

    if (!mounted) return;
    GameOverDialog.show(
      context: context,
      score: score,
      questionsAnswered: obstaclesPassed,
      onRetry: () {
        _restartGame();
      },
      onExit: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _restartGame() {
    if (!mounted) return;
    setState(() {
      _lives = 3;
      _score = 0;
      _isPaused = false;
      _isGameOver = false;
    });
    _game.resetGame();
  }

  void _togglePause() {
    if (_isGameOver) return;
    AudioController().playClick();
    setState(() {
      _isPaused = !_isPaused;
      _game.isPaused = _isPaused;
    });

    if (_isPaused) {
      _game.pauseEngine();
    } else {
      _game.resumeEngine();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.space ||
               event.logicalKey == LogicalKeyboardKey.arrowUp ||
               event.logicalKey == LogicalKeyboardKey.arrowDown)) {
            _game.flipGravity();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            // 1. The Flame Game Engine Canvas wrapped in GestureDetector
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _game.flipGravity(),
                child: GameWidget(game: _game),
              ),
            ),

          // 2. Top HUD Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      AudioController().playClick();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  // Hearts Display
                  HeartsDisplay(
                    maxHearts: 3,
                    remainingHearts: _lives,
                  ),

                  // Score Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFFFFD600),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_score',
                          style: AppTheme.gameFont.copyWith(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pause Button
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _togglePause,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: Icon(
                        _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Instruction Hint at Bottom
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '⚡ Tap anywhere to flip gravity! ⚡',
                    style: AppTheme.bodyFont.copyWith(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Pause Overlay
          if (_isPaused)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF00E5FF), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '⏸️',
                        style: TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Game Paused',
                        style: AppTheme.titleFont.copyWith(
                          color: Colors.white,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take a breath! Ready to flip again?',
                        style: AppTheme.bodyFont.copyWith(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          KidButton(
                            minWidth: 100,
                            height: 48,
                            color: Colors.grey.shade700,
                            shadowColor: Colors.grey.shade900,
                            onPressed: () {
                              _togglePause();
                              Navigator.of(context).pop();
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 4),
                                Text('Exit', style: AppTheme.bodyFont.copyWith(color: Colors.white)),
                              ],
                            ),
                          ),
                          KidButton(
                            minWidth: 120,
                            height: 48,
                            color: const Color(0xFF00E5FF),
                            shadowColor: const Color(0xFF0091EA),
                            onPressed: _togglePause,
                            child: Row(
                              children: [
                                const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                                const SizedBox(width: 4),
                                Text(
                                  'Resume',
                                  style: AppTheme.bodyFont.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
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
            ),
        ],
        ),
      ),
    );
  }
}
