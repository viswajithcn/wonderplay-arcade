import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/audio/audio_controller.dart';
import '../../../core/storage/game_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/mini_game_model.dart';
import '../../../shared/widgets/game_over_dialog.dart';
import '../../../shared/widgets/kid_button.dart';
import '../models/courier_color.dart';
import '../models/laser_gate.dart';
import '../widgets/courier_ship_widget.dart';
import '../widgets/laser_gate_widget.dart';

/// Main screen for Color Switch Courier mini-game.
/// Driven by a 60fps AnimationController game loop with downward scrolling
/// laser gates, color matching collision checks, score tracking, and audio SFX.
class ColorSwitchCourierScreen extends StatefulWidget {
  final GameStorage? storage;
  final GameDifficulty difficulty;
  final void Function(int score)? onGameOver;
  final VoidCallback? onExit;

  const ColorSwitchCourierScreen({
    super.key,
    this.storage,
    this.difficulty = GameDifficulty.medium,
    this.onGameOver,
    this.onExit,
  });

  /// Factory builder matching MiniGameRegistry convention.
  static Widget builder(
    BuildContext context,
    GameDifficulty difficulty, {
    GameStorage? storage,
  }) {
    return ColorSwitchCourierScreen(
      storage: storage,
      difficulty: difficulty,
    );
  }

  @override
  State<ColorSwitchCourierScreen> createState() =>
      ColorSwitchCourierScreenState();
}

class ColorSwitchCourierScreenState extends State<ColorSwitchCourierScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gameLoopController;
  final math.Random _rng = math.Random();
  Timer? _flashTimer;

  CourierColor _shipColor = CourierColor.red;
  CourierColor get shipColor => _shipColor;

  int _score = 0;
  int get score => _score;

  int _highScore = 0;
  int get highScore => _highScore;

  bool _isGameOver = false;
  bool get isGameOver => _isGameOver;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  final List<LaserGate> _gates = [];
  List<LaserGate> get gates => List.unmodifiable(_gates);

  DateTime? _lastTick;
  double _spawnTimer = 0.0;
  int _gateCounter = 0;
  bool _matchFlash = false;
  double _trackHeight = 600.0;
  double _trackWidth = 400.0;

  // Fixed player ship geometry
  static const double shipSize = 64.0;
  static const double shipBottomOffset = 110.0;
  static const double maxTrackWidth = 420.0;

  double get shipCenterY => _trackHeight - shipBottomOffset;

  @override
  void initState() {
    super.initState();
    _loadHighScore();

    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onGameLoopTick);

    _gameLoopController.repeat();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _speedUpBannerTimer?.cancel();
    _gameLoopController.removeListener(_onGameLoopTick);
    _gameLoopController.stop();
    _gameLoopController.dispose();
    super.dispose();
  }

  void _loadHighScore() {
    if (widget.storage != null) {
      _highScore =
          widget.storage!.getLevelHighScore('color_switch_courier', 1);
    }
  }

  void _onGameLoopTick() {
    if (!mounted || _isPaused || _isGameOver) return;

    final now = DateTime.now();
    final dt = _lastTick != null
        ? (now.difference(_lastTick!).inMicroseconds / 1000000.0)
            .clamp(0.001, 0.05)
        : 0.016;
    _lastTick = now;

    updateGame(dt);
  }

  /// Advances physics, spawns gates, checks collisions, and cleans up offscreen gates.
  void updateGame(double dt) {
    if (_isGameOver || _isPaused) return;

    // 1. Advance all active gates
    for (final gate in _gates) {
      gate.update(dt);
    }

    // 2. Check collisions
    checkCollisions();

    // 3. Remove passed offscreen gates
    _gates.removeWhere((gate) => gate.y > _trackHeight + 60.0);

    // 4. Gate spawner timer
    _spawnTimer += dt;
    final spawnInterval = _getSpawnInterval();
    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0.0;
      spawnGate();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Timer? _speedUpBannerTimer;
  String? _speedUpBannerText;

  int get speedTier => LaserGate.speedTierForScore(_score);

  double _getBaseSpeedForDifficulty() {
    return switch (widget.difficulty) {
      GameDifficulty.easy => 160.0,
      GameDifficulty.medium => 180.0,
      GameDifficulty.hard => 200.0,
    };
  }

  double _getSpawnInterval() {
    final baseInterval = switch (widget.difficulty) {
      GameDifficulty.easy => 2.2,
      GameDifficulty.medium => 1.85,
      GameDifficulty.hard => 1.5,
    };
    final tierIndex = _score ~/ 10;
    // Step down spawn interval noticeably every 10 rounds + per-round tightening
    final scaled = baseInterval - (tierIndex * 0.20) - (_score * 0.012);
    return scaled.clamp(0.75, 2.5);
  }

  /// Spawns a new laser gate at the top of the track.
  LaserGate spawnGate({CourierColor? color, double? speed, double? y}) {
    _gateCounter++;
    final assignedColor = color ?? _chooseNextGateColor();
    final gateSpeed = speed ??
        LaserGate.calculateProgressiveSpeed(
          _score,
          baseSpeed: _getBaseSpeedForDifficulty(),
        );

    final gate = LaserGate(
      id: 'gate_$_gateCounter',
      y: y ?? -30.0,
      color: assignedColor,
      speed: gateSpeed,
    );

    _gates.add(gate);
    return gate;
  }

  CourierColor _chooseNextGateColor() {
    final values = CourierColor.values;
    // Avoid spawning 3 identical colors sequentially
    if (_gates.length >= 2) {
      final last1 = _gates.last.color;
      final last2 = _gates[_gates.length - 2].color;
      if (last1 == last2) {
        final remaining = values.where((c) => c != last1).toList();
        return remaining[_rng.nextInt(remaining.length)];
      }
    }
    return values[_rng.nextInt(values.length)];
  }

  /// Evaluates gate crossing at the player ship Y position.
  void checkCollisions() {
    final threshold = shipCenterY;

    for (final gate in _gates) {
      if (gate.y >= threshold && !gate.isPassed) {
        if (gate.color == _shipColor) {
          // Color Match!
          gate.isPassed = true;
          _score++;
          if (_score > _highScore) {
            _highScore = _score;
          }

          // Every 10 rounds: boost speed tier and notify player!
          if (_score > 0 && _score % 10 == 0) {
            final newSpeed = LaserGate.calculateProgressiveSpeed(
              _score,
              baseSpeed: _getBaseSpeedForDifficulty(),
            );
            for (final activeGate in _gates) {
              if (!activeGate.isPassed && activeGate.speed < newSpeed) {
                activeGate.speed = newSpeed;
              }
            }
            AudioController().playCelebrate();
            _triggerSpeedUpBanner(speedTier);
          } else {
            AudioController().playCorrect();
          }
          _triggerMatchFlash();
        } else {
          // Color Mismatch! Game Over!
          _handleGameOver();
          break;
        }
      }
    }
  }

  void _triggerSpeedUpBanner(int newTier) {
    if (!mounted) return;
    _speedUpBannerTimer?.cancel();
    setState(() {
      _speedUpBannerText = '⚡ SPEED UP! LEVEL $newTier ⚡';
    });
    _speedUpBannerTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _speedUpBannerText = null);
      }
    });
  }

  void _triggerMatchFlash() {
    if (!mounted) return;
    _flashTimer?.cancel();
    setState(() => _matchFlash = true);
    _flashTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        setState(() => _matchFlash = false);
      }
    });
  }

  /// Cycles courier ship color: Red -> Green -> Blue -> Red.
  void cycleColor() {
    if (_isGameOver || _isPaused) return;

    setState(() {
      _shipColor = _shipColor.next();
    });
    AudioController().playPop();
  }

  /// Toggles game pause state.
  void togglePause() {
    if (_isGameOver) return;

    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _gameLoopController.stop();
      } else {
        _lastTick = DateTime.now();
        _gameLoopController.repeat();
      }
    });
    AudioController().playClick();
  }

  /// Restarts the game session.
  void restartGame() {
    _flashTimer?.cancel();
    _speedUpBannerTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _matchFlash = false;
      _speedUpBannerText = null;
      _score = 0;
      _gates.clear();
      _isGameOver = false;
      _isPaused = false;
      _shipColor = CourierColor.red;
      _spawnTimer = 0.0;
      _lastTick = DateTime.now();
    });
    _gameLoopController.repeat();
  }

  Future<void> _handleGameOver() async {
    if (_isGameOver) return;
    _isGameOver = true;
    _gameLoopController.stop();

    AudioController().playWrong();

    final stars =
        _score >= 15 ? 3 : (_score >= 5 ? 2 : (_score > 0 ? 1 : 0));

    if (widget.storage != null) {
      await widget.storage!.saveLevelResult(
        'color_switch_courier',
        1,
        _score,
        stars,
      );
      await widget.storage!.saveGameResult(
        'color_switch_courier',
        widget.difficulty.name,
        _score,
        stars,
      );
    }

    widget.onGameOver?.call(_score);

    if (stars > 0) {
      AudioController().playCelebrate();
    }

    if (!mounted) return;
    setState(() {});

    GameOverDialog.show(
      context: context,
      score: _score,
      questionsAnswered: _score,
      onRetry: restartGame,
      onExit: () {
        Navigator.of(context).pop();
        widget.onExit?.call();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Cosmic midnight background
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _trackHeight = constraints.maxHeight;
            _trackWidth = constraints.maxWidth > maxTrackWidth
                ? maxTrackWidth
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: _trackWidth,
                height: _trackHeight,
                child: Stack(
                  children: [
                    // Background starfield & borders
                    _buildCosmicBackground(),

                    // Tap surface to cycle color
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: cycleColor,
                      child: Stack(
                        children: [
                          // Downward scrolling laser gates
                          for (final gate in _gates)
                            Positioned(
                              top: gate.y - (gate.height / 2),
                              left: 0,
                              right: 0,
                              child: LaserGateWidget(
                                key: ValueKey(gate.id),
                                gate: gate,
                                width: _trackWidth,
                              ),
                            ),

                          // Fixed player courier ship
                          Positioned(
                            top: shipCenterY - (shipSize / 2),
                            left: (_trackWidth - shipSize) / 2 - 12.0,
                            child: CourierShipWidget(
                              key: const Key('courier_ship'),
                              color: _shipColor,
                              size: shipSize,
                              isPulsing: _matchFlash,
                            ),
                          ),

                          // Match celebration flash overlay
                          if (_matchFlash)
                            Positioned(
                              top: shipCenterY - 40.0,
                              left: (_trackWidth - 140.0) / 2,
                              child: Container(
                                width: 140.0,
                                height: 80.0,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _shipColor.glowColor
                                      .withValues(alpha: 0.35),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _shipColor.color
                                          .withValues(alpha: 0.6),
                                      blurRadius: 30.0,
                                      spreadRadius: 8.0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Top HUD
                    _buildTopHUD(),

                    // 10-Round Speed Up Milestone Banner
                    if (_speedUpBannerText != null && !_isGameOver)
                      Positioned(
                        top: 76.0,
                        left: 16.0,
                        right: 16.0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6D00), Color(0xFFFFD600)],
                              ),
                              borderRadius: BorderRadius.circular(24.0),
                              border: Border.all(color: Colors.white, width: 2.0),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFAB00).withValues(alpha: 0.6),
                                  blurRadius: 16.0,
                                  spreadRadius: 2.0,
                                ),
                              ],
                            ),
                            child: Text(
                              _speedUpBannerText!,
                              style: AppTheme.headingFont.copyWith(
                                color: Colors.white,
                                fontSize: 15.0,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Bottom helper prompt (visible during initial learning)
                    if (_score < 3 && !_isGameOver && !_isPaused)
                      Positioned(
                        bottom: 24.0,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14.0,
                              vertical: 6.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color: _shipColor.color.withValues(alpha: 0.6),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  color: _shipColor.color,
                                  size: 18.0,
                                ),
                                const SizedBox(width: 6.0),
                                Text(
                                  'Tap to switch color!',
                                  style: AppTheme.bodyFont.copyWith(
                                    color: Colors.white,
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Pause Overlay
                    if (_isPaused) _buildPauseOverlay(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCosmicBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.2,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
            Color(0xFF020617),
          ],
        ),
        border: Border.symmetric(
          vertical: BorderSide(
            color: const Color(0xFF334155).withValues(alpha: 0.6),
            width: 2.0,
          ),
        ),
      ),
    );
  }

  Widget _buildTopHUD() {
    return Positioned(
      top: 12.0,
      left: 12.0,
      right: 12.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          InkWell(
            borderRadius: BorderRadius.circular(24.0),
            onTap: () {
              Navigator.of(context).pop();
              widget.onExit?.call();
            },
            child: Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2.0),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 24.0,
              ),
            ),
          ),

          // Score & Speed Level Badges
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(
                    color: const Color(0xFFFFD54F),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
                      blurRadius: 10.0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFD54F),
                      size: 24.0,
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      '$_score',
                      style: AppTheme.gameFont.copyWith(
                        color: Colors.white,
                        fontSize: 22.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(
                    color: speedTier > 1
                        ? const Color(0xFFFF9100)
                        : const Color(0xFF38BDF8),
                    width: 2.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: speedTier > 1
                          ? const Color(0xFFFFAB00)
                          : const Color(0xFF38BDF8),
                      size: 18.0,
                    ),
                    const SizedBox(width: 2.0),
                    Text(
                      'Lv.$speedTier',
                      style: AppTheme.bodyFont.copyWith(
                        color: Colors.white,
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Pause button
          InkWell(
            borderRadius: BorderRadius.circular(24.0),
            onTap: togglePause,
            child: Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 2.0),
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 24.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          width: 280.0,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(28.0),
            border: Border.all(color: const Color(0xFF29B6F6), width: 3.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF29B6F6).withValues(alpha: 0.4),
                blurRadius: 20.0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PAUSED',
                style: AppTheme.titleFont.copyWith(
                  color: Colors.white,
                  letterSpacing: 3.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20.0),
              KidButton(
                minWidth: 160.0,
                height: 48.0,
                color: const Color(0xFF66BB6A),
                onPressed: togglePause,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, color: Colors.white),
                    const SizedBox(width: 8.0),
                    Text(
                      'Resume',
                      style: AppTheme.bodyFont.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12.0),
              KidButton(
                minWidth: 160.0,
                height: 48.0,
                color: const Color(0xFFFFA726),
                onPressed: restartGame,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, color: Colors.white),
                    const SizedBox(width: 8.0),
                    Text(
                      'Restart',
                      style: AppTheme.bodyFont.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12.0),
              KidButton(
                minWidth: 160.0,
                height: 48.0,
                color: const Color(0xFFFF5252),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onExit?.call();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.home_rounded, color: Colors.white),
                    const SizedBox(width: 8.0),
                    Text(
                      'Exit',
                      style: AppTheme.bodyFont.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
