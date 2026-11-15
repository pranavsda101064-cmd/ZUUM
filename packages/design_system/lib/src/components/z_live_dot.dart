import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/motion.dart';

/// Pulsing dot used for live/online states (lime when live). Animates
/// indefinitely by design — tests should `pump(duration)`, not settle.
class ZLiveDot extends StatefulWidget {
  const ZLiveDot({super.key, this.color = ZColors.success, this.size = 8});

  final Color color;
  final double size;

  @override
  State<ZLiveDot> createState() => _ZLiveDotState();
}

class _ZLiveDotState extends State<ZLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: ZMotion.standard),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
