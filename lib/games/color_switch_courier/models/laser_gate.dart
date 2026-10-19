import 'courier_color.dart';

/// Represents a horizontal laser gate that scrolls downward from the top
/// of the screen toward the courier drone.
class LaserGate {
  final String id;
  double y;
  final CourierColor color;
  double speed;
  bool isPassed;
  final double height;

  LaserGate({
    required this.id,
    required this.y,
    required this.color,
    required this.speed,
    this.isPassed = false,
    this.height = 24.0,
  });

  /// Calculates dynamic gate speed scaling with player score,
  /// starting at 180 px/s and capped at 400 px/s for kid-friendly arcade balance.
  static double calculateSpeed(
    int score, {
    double baseSpeed = 180.0,
    double maxSpeed = 400.0,
    double scaleFactor = 2.5,
  }) {
    final speed = baseSpeed + (score * scaleFactor);
    return speed > maxSpeed ? maxSpeed : speed;
  }

  /// Advances the gate position based on delta time (seconds).
  void update(double dt) {
    y += speed * dt;
  }

  /// Creates a shallow copy of the gate with optional parameter overrides.
  LaserGate copyWith({
    String? id,
    double? y,
    CourierColor? color,
    double? speed,
    bool? isPassed,
    double? height,
  }) {
    return LaserGate(
      id: id ?? this.id,
      y: y ?? this.y,
      color: color ?? this.color,
      speed: speed ?? this.speed,
      isPassed: isPassed ?? this.isPassed,
      height: height ?? this.height,
    );
  }

  @override
  String toString() =>
      'LaserGate(id: $id, y: ${y.toStringAsFixed(1)}, color: ${color.name}, speed: ${speed.toStringAsFixed(1)}, isPassed: $isPassed)';
}
