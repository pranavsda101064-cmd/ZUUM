import 'package:flutter/material.dart';

import '../tokens/motion.dart';
import '../tokens/typography.dart';

/// Odometer-style numeric text: when [value] changes, digits slide vertically
/// (180ms easeOutCubic) instead of snapping — per Gemini spec §4.4.
class ZOdometerText extends StatelessWidget {
  const ZOdometerText(
    this.value, {
    super.key,
    this.style,
    this.textAlign,
  });

  final String value;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: ZMotion.fast,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.6),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Text(
        value,
        key: ValueKey(value),
        style: style ?? ZTypography.numericLg,
        textAlign: textAlign,
      ),
    );
  }
}
