import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Compact metric card used across the partner dashboard (earnings,
/// acceptance, trips, online time).
class ZStatCard extends StatelessWidget {
  const ZStatCard({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.accent = false,
    this.onTap,
    this.valueWidget,
  });

  final String label;
  final String value;

  /// Optional animated value (e.g. [ZAnimatedCounter]); falls back to [value].
  final Widget? valueWidget;
  final String? caption;
  final IconData? icon;

  /// Lime accent for the headline metric of a screen.
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(ZSpacing.lg),
      decoration: BoxDecoration(
        color: accent ? ZColors.primaryTint : ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.md),
        border: Border.all(
          color: accent ? ZColors.primary : ZColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: ZTypography.overline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null)
                Icon(icon, size: 16, color: ZColors.textTertiary),
            ],
          ),
          const SizedBox(height: ZSpacing.sm),
          valueWidget ??
              Text(
                value,
                style: ZTypography.numericLg.copyWith(fontSize: 20),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              style: ZTypography.overline.copyWith(
                color: ZColors.textSecondary,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZRadii.md),
      child: content,
    );
  }
}
