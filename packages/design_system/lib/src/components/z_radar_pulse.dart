import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// Captain-matching radar: two concentric Primary rings expanding from a
/// center point, staggered 1600ms loop (Gemini spec §4.4).
class ZRadarPulse extends StatefulWidget {
  const ZRadarPulse({super.key, this.size = 160});

  final double size;

  @override
  State<ZRadarPulse> createState() => _ZRadarPulseState();
}

class _ZRadarPulseState extends State<ZRadarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(painter: _RadarPainter(_controller.value));
        },
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Two rings, phase-shifted by half a cycle.
    for (final phase in const [0.0, 0.5]) {
      final progress = (t + phase) % 1.0;
      final radius = 12 + (maxRadius - 12) * progress;
      final opacity = (0.28 * (1 - progress)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = ZColors.primary.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }

    // Static centre dot (the pickup pin).
    final dot = Paint()..color = ZColors.primary;
    canvas.drawCircle(center, 5, dot);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.t != t;
}
