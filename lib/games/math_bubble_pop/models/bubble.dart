import 'package:flutter/material.dart';

class Bubble {
  final int id;
  final int value;
  final Color color;
  final double radius;
  double x; // Horizontal fraction 0.0 to 1.0
  double y; // Vertical pixel offset from top
  final double speed;
  final double wobbleFreq;
  final double wobbleAmp;
  double wobblePhase;
  bool isPopped;
  bool isShaking;

  Bubble({
    required this.id,
    required this.value,
    required this.color,
    required this.radius,
    required this.x,
    required this.y,
    required this.speed,
    required this.wobbleFreq,
    required this.wobbleAmp,
    this.wobblePhase = 0.0,
    this.isPopped = false,
    this.isShaking = false,
  });
}
