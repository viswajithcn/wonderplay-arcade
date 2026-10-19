import 'package:flutter/material.dart';
import '../models/laser_gate.dart';

/// Horizontal laser gate widget spanning across the courier track.
/// Features side emitter pylons, an energetic laser beam with glowing halo,
/// and a centered accessibility emblem displaying the gate's geometric symbol.
class LaserGateWidget extends StatelessWidget {
  final LaserGate gate;
  final double width;

  const LaserGateWidget({
    super.key,
    required this.gate,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final beamColor = gate.color.color;
    final glowColor = gate.color.glowColor;
    final accentColor = gate.color.accentColor;

    return SizedBox(
      width: width,
      height: gate.height + 16.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer wide laser glow
          Container(
            height: 12.0,
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6.0),
              boxShadow: [
                BoxShadow(
                  color: beamColor.withValues(alpha: 0.75),
                  blurRadius: 16.0,
                  spreadRadius: 2.5,
                ),
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.5),
                  blurRadius: 24.0,
                  spreadRadius: 5.0,
                ),
              ],
            ),
          ),

          // Core intense laser beam line
          Container(
            height: 6.0,
            margin: const EdgeInsets.symmetric(horizontal: 18.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3.0),
              gradient: LinearGradient(
                colors: [
                  beamColor.withValues(alpha: 0.6),
                  Colors.white,
                  beamColor,
                  Colors.white,
                  beamColor.withValues(alpha: 0.6),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 4.0,
                ),
              ],
            ),
          ),

          // Left Emitter Pylon
          Positioned(
            left: 2.0,
            child: _EmitterNode(
              beamColor: beamColor,
              accentColor: accentColor,
              isLeft: true,
            ),
          ),

          // Right Emitter Pylon
          Positioned(
            right: 2.0,
            child: _EmitterNode(
              beamColor: beamColor,
              accentColor: accentColor,
              isLeft: false,
            ),
          ),

          // Centered Accessibility Glyph Emblem
          Container(
            width: 32.0,
            height: 32.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E293B),
              border: Border.all(
                color: beamColor,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: beamColor.withValues(alpha: 0.8),
                  blurRadius: 10.0,
                  spreadRadius: 2.0,
                ),
                const BoxShadow(
                  color: Colors.black45,
                  blurRadius: 4.0,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                gate.color.symbol,
                color: Colors.white,
                size: 18.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmitterNode extends StatelessWidget {
  final Color beamColor;
  final Color accentColor;
  final bool isLeft;

  const _EmitterNode({
    required this.beamColor,
    required this.accentColor,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22.0,
      height: 28.0,
      decoration: BoxDecoration(
        color: const Color(0xFF334155),
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(6.0) : const Radius.circular(2.0),
          right: isLeft ? const Radius.circular(2.0) : const Radius.circular(6.0),
        ),
        border: Border.all(
          color: const Color(0xFF64748B),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 4.0,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 8.0,
          height: 16.0,
          decoration: BoxDecoration(
            color: beamColor,
            borderRadius: BorderRadius.circular(3.0),
            boxShadow: [
              BoxShadow(
                color: beamColor.withValues(alpha: 0.9),
                blurRadius: 6.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
