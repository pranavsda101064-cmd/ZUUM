import 'package:flutter/animation.dart';

/// Motion tokens — few, deliberate animations. No decorative motion.
abstract final class ZMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve standard = Cubic(0.2, 0, 0, 1);
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
}
