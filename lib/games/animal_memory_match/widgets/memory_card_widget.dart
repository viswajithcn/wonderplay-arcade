import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/animal_card_model.dart';

class MemoryCardWidget extends StatefulWidget {
  final AnimalCardModel card;
  final VoidCallback onTap;

  const MemoryCardWidget({
    super.key,
    required this.card,
    required this.onTap,
  });

  @override
  State<MemoryCardWidget> createState() => _MemoryCardWidgetState();
}

class _MemoryCardWidgetState extends State<MemoryCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.card.isFaceUp || widget.card.isMatched) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant MemoryCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card.isFaceUp || widget.card.isMatched) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isUnder = angle > (pi / 2);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002) // 3D Perspective
              ..rotateY(angle),
            child: isUnder
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildFront(),
                  )
                : _buildBack(),
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    final matchColor = widget.card.matchedPlayerColor ?? AppTheme.sunnyYellow;
    final hasPlayerOwner = widget.card.isMatched && widget.card.matchedByPlayer != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.card.isMatched ? matchColor : AppTheme.primaryBlue,
          width: widget.card.isMatched ? 4 : 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.card.isMatched
                ? matchColor.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: widget.card.isMatched ? 12 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.card.animal.emoji,
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.card.isMatched
                      ? matchColor.withValues(alpha: 0.18)
                      : AppTheme.lightBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.card.animal.name,
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.card.isMatched ? matchColor : AppTheme.darkText,
                  ),
                ),
              ),
            ],
          ),
          if (hasPlayerOwner)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: matchColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'P${widget.card.matchedByPlayer! + 1}',
                  style: AppTheme.bodyFont.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFAB47BC), // Purple
            Color(0xFF7B1FA2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B1FA2).withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🐾', style: TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}
