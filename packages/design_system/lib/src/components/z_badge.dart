import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';

enum ZBadgeTone { neutral, primary, highlight, error, success }

/// Small status/context pill.
class ZBadge extends StatelessWidget {
  const ZBadge({super.key, required this.label, this.tone = ZBadgeTone.neutral});

  final String label;
  final ZBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      ZBadgeTone.neutral => (ZColors.accent, ZColors.primary),
      ZBadgeTone.primary => (ZColors.primary, ZColors.onPrimary),
      ZBadgeTone.highlight => (ZColors.highlightTint, ZColors.dark),
      ZBadgeTone.error => (ZColors.errorTint, ZColors.error),
      ZBadgeTone.success => (ZColors.successTint, ZColors.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: ZTypography.overline.copyWith(
          color: foreground,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
