import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/storage/game_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../hub/views/game_hub_screen.dart';

/// Fun, bouncy animated splash screen displaying "WonderPlay Arcade" branding.
/// Auto-navigates smoothly to [GameHubScreen] or transitions immediately on tap.
class SplashScreen extends StatefulWidget {
  final GameStorage storage;
  final Duration duration;

  const SplashScreen({
    super.key,
    required this.storage,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _rotateAnimation;
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 0.95)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 20,
      ),
    ]).animate(_controller);

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _rotateAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.08, end: 0.06)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.06, end: 0.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_controller);

    _controller.forward();

    // Auto-transition to GameHubScreen after splash duration
    _timer = Timer(widget.duration, _navigateToHub);
  }

  void _navigateToHub() {
    if (!mounted || _navigated) return;
    _navigated = true;
    _timer?.cancel();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GameHubScreen(storage: widget.storage),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToHub,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFE1F5FE), // Light sky blue
                Color(0xFFFFF9C4), // Warm soft yellow
                Color(0xFFFFECB3), // Amber pastel
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Decorative background bubbles/stars
                ..._buildBackgroundDecorations(),

                // Main Centered Mascot & Branding
                Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Transform.rotate(
                          angle: _rotateAnimation.value,
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mascot Arcade Joystick Badge
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.sunnyYellow,
                                AppTheme.amberOrange,
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white,
                              width: 6,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.amberOrange.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '🕹️',
                              style: TextStyle(fontSize: 70),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Title: WonderPlay Arcade
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              AppTheme.deepBlue,
                              AppTheme.bubblePurple,
                              AppTheme.candyCoral,
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'WonderPlay Arcade',
                            textAlign: TextAlign.center,
                            style: AppTheme.titleFont.copyWith(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // Mask overrides this
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  offset: const Offset(2, 3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Subtitle
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Fun & Learning Mini-Games!',
                            style: AppTheme.headingFont.copyWith(
                              fontSize: 16,
                              color: AppTheme.darkText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // Bouncing colorful accent dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            _AccentDot(color: AppTheme.candyCoral, delayMs: 0),
                            SizedBox(width: 8),
                            _AccentDot(color: AppTheme.sunnyYellow, delayMs: 150),
                            SizedBox(width: 8),
                            _AccentDot(color: AppTheme.mintGreen, delayMs: 300),
                            SizedBox(width: 8),
                            _AccentDot(color: AppTheme.primaryBlue, delayMs: 450),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Tap to skip hint at bottom
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Tap anywhere to start!',
                        style: AppTheme.bodyFont.copyWith(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBackgroundDecorations() {
    return const [
      Positioned(top: 40, left: 30, child: Text('⭐', style: TextStyle(fontSize: 26))),
      Positioned(top: 80, right: 40, child: Text('✨', style: TextStyle(fontSize: 28))),
      Positioned(top: 220, left: 20, child: Text('🎮', style: TextStyle(fontSize: 24))),
      Positioned(bottom: 120, left: 40, child: Text('🎈', style: TextStyle(fontSize: 28))),
      Positioned(bottom: 160, right: 30, child: Text('🌟', style: TextStyle(fontSize: 26))),
      Positioned(top: 160, right: 25, child: Text('🎯', style: TextStyle(fontSize: 22))),
    ];
  }
}

class _AccentDot extends StatelessWidget {
  final Color color;
  final int delayMs;

  const _AccentDot({required this.color, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
