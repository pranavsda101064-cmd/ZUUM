import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';

/// Perforated ticket card (receipt) — surface card with a dashed divider
/// carrying semicircular notch cutouts on both edges (Gemini spec §2j).
class ZTicketCard extends StatelessWidget {
  const ZTicketCard({
    super.key,
    required this.top,
    required this.bottom,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget top;
  final Widget bottom;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.lg),
        border: Border.all(color: ZColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: padding, child: top),
          const _PerforatedDivider(),
          Padding(padding: padding, child: bottom),
        ],
      ),
    );
  }
}

class _PerforatedDivider extends StatelessWidget {
  const _PerforatedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: CustomPaint(painter: _PerforationPainter()),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dash = Paint()
      ..color = ZColors.divider
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    var x = 22.0; // leave room for notches
    while (x < size.width - 22) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(x + dashWidth, size.height / 2), dash);
      x += dashWidth + dashSpace;
    }

    // Semicircular notches bitten out of both edges.
    final notch = Paint()
      ..color = ZColors.background // matches the screen behind the ticket
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(0, size.height / 2), 8, notch);
    canvas.drawCircle(Offset(size.width, size.height / 2), 8, notch);

    final ring = Paint()
      ..color = ZColors.divider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, size.height / 2), radius: 8),
      -1.2, 2.4, false, ring,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width, size.height / 2), radius: 8),
      1.94, 2.4, false, ring,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
