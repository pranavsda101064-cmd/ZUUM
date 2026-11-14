import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';

/// Shimmer skeleton — gradient sweep from divider → background, 1100ms.
/// Geometry mirrors the loaded widget tree so hydration causes zero layout
/// shift (per Gemini spec §3.10).
class ZSkeleton extends StatefulWidget {
  const ZSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = ZRadii.sm,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<ZSkeleton> createState() => _ZSkeletonState();
}

class _ZSkeletonState extends State<ZSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Sweep band travels left → right across the base fill.
        final dx = -1.0 + t * 3.0;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + dx, 0),
              end: Alignment(1 + dx, 0),
              colors: const [ZColors.divider, ZColors.background, ZColors.divider],
            ),
          ),
        );
      },
    );
  }
}

/// A few stacked skeleton rows shaped like a list card.
class ZSkeletonList extends StatelessWidget {
  const ZSkeletonList({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < itemCount; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ZSkeleton(width: 140, height: 14),
                  SizedBox(height: 8),
                  ZSkeleton(width: double.infinity, height: 44, radius: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
