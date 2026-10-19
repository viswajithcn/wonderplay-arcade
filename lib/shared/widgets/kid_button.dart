import 'package:flutter/material.dart';
import '../../core/audio/audio_controller.dart';
import '../../core/theme/app_theme.dart';

class KidButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color color;
  final Color? shadowColor;
  final double height;
  final double minWidth;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  const KidButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color = AppTheme.sunnyYellow,
    this.shadowColor,
    this.height = 54,
    this.minWidth = 140,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    this.borderRadius,
  });

  @override
  State<KidButton> createState() => _KidButtonState();
}

class _KidButtonState extends State<KidButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
    AudioController().playClick();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onPressed();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(24);
    final darkShadow = widget.shadowColor ??
        HSLColor.fromColor(widget.color)
            .withLightness((HSLColor.fromColor(widget.color).lightness - 0.18).clamp(0.0, 1.0))
            .toColor();

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: widget.height,
              constraints: BoxConstraints(minWidth: widget.minWidth),
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: effectiveRadius,
                boxShadow: [
                  BoxShadow(
                    color: darkShadow,
                    offset: _isPressed ? const Offset(0, 2) : const Offset(0, 6),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}
