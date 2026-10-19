import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/storage/game_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/mini_game_model.dart';
import '../../../shared/widgets/game_over_dialog.dart';
import '../../../shared/widgets/hearts_display.dart';
import '../../../shared/widgets/kid_button.dart';
import '../../../shared/widgets/victory_dialog.dart';
import '../models/bubble.dart';
import '../models/math_level.dart';
import '../models/math_problem.dart';
import '../widgets/bubble_widget.dart';
import '../widgets/pop_effect.dart';

class MathBubblePopScreen extends StatefulWidget {
  final MathLevel level;
  final GameStorage storage;

  const MathBubblePopScreen({
    super.key,
    required this.level,
    required this.storage,
  });

  @override
  State<MathBubblePopScreen> createState() => _MathBubblePopScreenState();
}

class _MathBubblePopScreenState extends State<MathBubblePopScreen> with TickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _hearts = 3;
  static const int _maxHearts = 3;
  bool _isPaused = false;
  String? _encouragementMessage;
  Timer? _encouragementTimer;

  bool _isTransitioning = false;

  late MathProblem _currentProblem;
  final List<Bubble> _bubbles = [];
  final List<Widget> _activePopEffects = [];
  int _bubbleIdCounter = 0;

  late final AnimationController _gameLoopController;
  DateTime _lastFrameTime = DateTime.now();

  final List<Color> _bubbleColors = const [
    Color(0xFFFF5252), // Coral Red
    Color(0xFF29B6F6), // Sky Blue
    Color(0xFF66BB6A), // Mint Green
    Color(0xFFFFA000), // Amber
    Color(0xFFAB47BC), // Purple
    Color(0xFFEC407A), // Hot Pink
  ];

  @override
  void initState() {
    super.initState();
    _startNewQuestion();

    // Start background music throughout gameplay
    AudioController().startBgm();

    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onGameTick);

    _gameLoopController.repeat();
  }

  @override
  void dispose() {
    _gameLoopController.dispose();
    _encouragementTimer?.cancel();
    super.dispose();
  }

  void _startNewQuestion([Size? size]) {
    _isTransitioning = false;
    _currentProblem = MathProblem.generateForLevel(widget.level);
    _bubbles.clear();
    _lastFrameTime = DateTime.now();

    if (size != null && size.width > 0 && size.height > 0) {
      _spawnInitialBubbles(size);
    }
  }

  void _spawnInitialBubbles(Size size) {
    if (_bubbles.isNotEmpty) return;

    final rand = Random();
    final options = _currentProblem.options;
    final columnWidth = size.width / options.length;

    // Distribute bubbles nicely across the active play area below the question card
    // Question card ends around y = 180. Bubbles float from mid-screen & lower-screen up.
    final minSpawnY = size.height * 0.42;
    final maxSpawnY = size.height - 40.0;
    final segmentHeight = (maxSpawnY - minSpawnY) / options.length;

    for (int i = 0; i < options.length; i++) {
      final value = options[i];
      final color = _bubbleColors[rand.nextInt(_bubbleColors.length)];
      final radius = (size.width < 500) ? 38.0 : 48.0;

      final startY = minSpawnY + (i * segmentHeight) + (rand.nextDouble() - 0.5) * 20;
      final startX = (i * columnWidth) + (columnWidth / 2) + (rand.nextDouble() - 0.5) * 16;

      // Speed increases with level.baseSpeed
      final floatSpeed = widget.level.baseSpeed + rand.nextDouble() * 25.0;

      _bubbles.add(
        Bubble(
          id: _bubbleIdCounter++,
          value: value,
          color: color,
          radius: radius,
          x: (startX / size.width).clamp(0.15, 0.85),
          y: startY,
          speed: floatSpeed,
          wobbleFreq: 2.2 + rand.nextDouble() * 1.5,
          wobbleAmp: 18.0 + rand.nextDouble() * 12.0,
          wobblePhase: rand.nextDouble() * 2 * pi,
        ),
      );
    }
  }

  void _onGameTick() {
    if (_isPaused || !mounted) return;

    final now = DateTime.now();
    final dt = now.difference(_lastFrameTime).inMicroseconds / 1000000.0;
    _lastFrameTime = now;

    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0 || size.height <= 0) return;

    if (_bubbles.isEmpty) {
      _spawnInitialBubbles(size);
    }

    setState(() {
      for (final bubble in _bubbles) {
        if (bubble.isPopped) continue;

        // Move upward with level's speed
        bubble.y -= bubble.speed * dt;
        bubble.wobblePhase += bubble.wobbleFreq * dt;

        // If the correct bubble floats completely off top of screen, lose a heart!
        if (!_isTransitioning &&
            bubble.value == _currentProblem.correctAnswer &&
            bubble.y < -bubble.radius * 2) {
          bubble.isPopped = true;
          _isTransitioning = true;
          _handleBubbleEscaped();
          break;
        }

        // Distractor bubbles loop from bottom if they float off screen
        if (bubble.y < -bubble.radius * 2) {
          bubble.y = size.height + 20;
          bubble.x = (0.15 + Random().nextDouble() * 0.7);
        }
      }
    });
  }

  void _handleBubbleEscaped() {
    AudioController().playWrong();
    setState(() {
      _streak = 0;
      _hearts--;
      _showEncouragement('Missed it! Lost a Heart 💔');
    });

    if (_hearts <= 0) {
      _triggerGameOver();
    } else {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        if (_currentQuestionIndex + 1 >= widget.level.questionCount) {
          _finishLevelSuccess();
        } else {
          setState(() {
            _currentQuestionIndex++;
            final size = MediaQuery.sizeOf(context);
            _startNewQuestion(size);
          });
        }
      });
    }
  }

  void _onBubbleTapped(Bubble bubble, Size size) {
    if (bubble.isPopped || _isPaused || _isTransitioning) return;

    final bubbleCenterX = bubble.x * size.width + sin(bubble.wobblePhase) * bubble.wobbleAmp;
    final bubbleCenterY = bubble.y;

    if (bubble.value == _currentProblem.correctAnswer) {
      // Correct bubble popped!
      _isTransitioning = true;
      AudioController().playPop();
      AudioController().playCorrect();

      setState(() {
        bubble.isPopped = true;
        _streak++;
        _score += 100 + (_streak * 25) + (widget.level.number * 20);
        _showEncouragement(_streak > 2 ? 'Combo x$_streak! 🔥' : 'Great Job! ⭐');
      });

      _triggerPopEffect(Offset(bubbleCenterX, bubbleCenterY), bubble.color, bubble.radius);

      Future.delayed(const Duration(milliseconds: 550), () {
        if (!mounted) return;
        if (_currentQuestionIndex + 1 >= widget.level.questionCount) {
          _finishLevelSuccess();
        } else {
          setState(() {
            _currentQuestionIndex++;
            _startNewQuestion(size);
          });
        }
      });
    } else {
      // Wrong bubble popped: Lose a Heart!
      AudioController().playWrong();
      setState(() {
        _streak = 0;
        _hearts--;
        bubble.isShaking = true;
        _showEncouragement('Oops! Lost a Heart 💔');
      });

      if (_hearts <= 0) {
        // Game Over! 3 strikes reached.
        _triggerGameOver();
      } else {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() => bubble.isShaking = false);
          }
        });
      }
    }
  }

  void _triggerGameOver() {
    _gameLoopController.stop();

    GameOverDialog.show(
      context: context,
      score: _score,
      questionsAnswered: _currentQuestionIndex,
      onRetry: () {
        setState(() {
          _hearts = _maxHearts;
          _score = 0;
          _streak = 0;
          _currentQuestionIndex = 0;
          final size = MediaQuery.sizeOf(context);
          _startNewQuestion(size);
          _gameLoopController.repeat();
        });
      },
      onExit: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _triggerPopEffect(Offset position, Color color, double radius) {
    final key = UniqueKey();
    final effectSize = radius * 4;
    setState(() {
      _activePopEffects.add(
        Positioned(
          key: key,
          left: position.dx - (effectSize / 2),
          top: position.dy - (effectSize / 2),
          child: PopEffectWidget(
            color: color,
            initialRadius: radius,
            onComplete: () {
              if (mounted) {
                setState(() {
                  _activePopEffects.removeWhere((w) => w.key == key);
                });
              }
            },
          ),
        ),
      );
    });
  }

  void _showEncouragement(String message) {
    _encouragementTimer?.cancel();
    setState(() => _encouragementMessage = message);
    _encouragementTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _encouragementMessage = null);
    });
  }

  void _finishLevelSuccess() {
    _gameLoopController.stop();

    // Calculate stars from remaining hearts:
    // 3 hearts = 3 stars, 2 hearts = 2 stars, 1 heart = 1 star
    final stars = _hearts.clamp(1, 3);

    widget.storage.saveLevelResult(
      'math_bubble_pop',
      widget.level.number,
      _score,
      stars,
    );

    final result = GameResult(
      score: _score,
      totalQuestions: widget.level.questionCount,
      correctAnswers: widget.level.questionCount,
      stars: stars,
      difficulty: GameDifficulty.easy,
    );

    VictoryDialog.show(
      context: context,
      result: result,
      onPlayAgain: () {
        setState(() {
          _hearts = _maxHearts;
          _score = 0;
          _streak = 0;
          _currentQuestionIndex = 0;
          final size = MediaQuery.sizeOf(context);
          _startNewQuestion(size);
          _gameLoopController.repeat();
        });
      },
      onExit: () {
        Navigator.of(context).pop();
      },
    );
  }

  void _showPauseDialog() {
    setState(() => _isPaused = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Center(child: Text('Game Paused', style: AppTheme.headingFont)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pause_circle_filled_rounded, size: 64, color: AppTheme.amberOrange),
            const SizedBox(height: 16),
            Text('Take a breath or jump right back in!', style: AppTheme.bodyFont, textAlign: TextAlign.center),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          KidButton(
            minWidth: 100,
            height: 48,
            color: Colors.grey.shade300,
            shadowColor: Colors.grey.shade500,
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to level select
            },
            child: Text('Exit', style: AppTheme.bodyFont),
          ),
          const SizedBox(width: 8),
          KidButton(
            minWidth: 120,
            height: 48,
            color: AppTheme.mintGreen,
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isPaused = false;
                _lastFrameTime = DateTime.now();
              });
            },
            child: Text('Resume', style: AppTheme.bodyFont.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFFB3E5FC),
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
          child: Stack(
            children: [
              // 1. Floating Bubbles
              ..._bubbles.where((b) => !b.isPopped).map((bubble) {
                final wobbleX = sin(bubble.wobblePhase) * bubble.wobbleAmp;
                final left = (bubble.x * size.width + wobbleX - bubble.radius)
                    .clamp(4.0, size.width - bubble.radius * 2 - 4);
                final top = bubble.y - bubble.radius;

                return Positioned(
                  key: ValueKey(bubble.id),
                  left: left,
                  top: top,
                  child: BubbleWidget(
                    bubble: bubble,
                    onTap: () => _onBubbleTapped(bubble, size),
                  ),
                );
              }),

              // 2. Active Pop Droplet Effects
              ..._activePopEffects,

              // 3. Top Header & Equation Card
              Positioned(
                top: 8,
                left: 10,
                right: 10,
                child: Column(
                  children: [
                    // Top controls row: Pause, Level badge, Hearts, Score
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Pause Button
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.deepBlue,
                            elevation: 3,
                            padding: const EdgeInsets.all(6),
                            minimumSize: const Size(38, 38),
                          ),
                          onPressed: _showPauseDialog,
                          icon: const Icon(Icons.pause_rounded, size: 22),
                        ),

                        // Level & Progress Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            'L${widget.level.number} • Q${_currentQuestionIndex + 1}/${widget.level.questionCount}',
                            style: AppTheme.bodyFont.copyWith(
                              fontWeight: FontWeight.bold,
                              color: widget.level.color,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        // Hearts / Lives Display (3 Strikes)
                        HeartsDisplay(remainingHearts: _hearts),

                        // Score Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.sunnyYellow,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.amberOrange.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                '$_score',
                                style: AppTheme.headingFont.copyWith(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Big Equation Banner Card
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: widget.level.color, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: widget.level.color.withValues(alpha: 0.25),
                            offset: const Offset(0, 6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Pop the matching answer!',
                            style: AppTheme.bodyFont.copyWith(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentProblem.equationString,
                            style: AppTheme.titleFont.copyWith(
                              fontSize: 34,
                              color: AppTheme.darkText,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Encouragement Popover Banner (Placed AFTER header in Stack with top: 200)
              Positioned(
                top: 200,
                left: 16,
                right: 16,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: CurvedAnimation(
                          parent: animation,
                          curve: Curves.elasticOut,
                        ),
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: _encouragementMessage != null
                        ? Container(
                            key: ValueKey(_encouragementMessage),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _hearts == 1
                                    ? const Color(0xFFFF1744)
                                    : AppTheme.sunnyYellow,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              _encouragementMessage!,
                              style: AppTheme.headingFont.copyWith(
                                color: _hearts == 1
                                    ? const Color(0xFFFF1744)
                                    : AppTheme.bubblePurple,
                                fontSize: 19,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
