import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Vertical pickup → drop route timeline: success circle, dashed connector,
/// primary/error square (Gemini spec §2g / §3.9).
class ZRouteTimeline extends StatelessWidget {
  const ZRouteTimeline({
    super.key,
    required this.pickup,
    required this.drop,
    this.trailing,
    this.connectorHeight = 36,
  });

  final String pickup;
  final String drop;
  final Widget? trailing;
  final double connectorHeight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const _Endpoint(
              color: ZColors.success,
              filled: true,
            ),
            _DashedLine(height: connectorHeight),
            const _Endpoint(color: ZColors.primary),
          ],
        ),
        const SizedBox(width: ZSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickup, style: ZTypography.captionStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: connectorHeight - 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      drop,
                      style: ZTypography.captionStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({required this.color, this.filled = false});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: filled ? color : ZColors.surface,
        shape: filled ? BoxShape.circle : BoxShape.rectangle,
        border: Border.all(color: color, width: 2),
        borderRadius: filled ? null : BorderRadius.circular(2),
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: height,
      child: CustomPaint(painter: _DashPainter()),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ZColors.textTertiary
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 3.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
