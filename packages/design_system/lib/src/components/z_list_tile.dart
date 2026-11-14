import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Styled settings/menu row — leading icon, title, subtitle, trailing.
class ZListTile extends StatelessWidget {
  const ZListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.titleColor,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? titleColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ZSpacing.lg,
          vertical: dense ? ZSpacing.sm : ZSpacing.md,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: ZSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ZTypography.body.copyWith(
                      color: titleColor ??
                          (enabled ? ZColors.textPrimary : ZColors.textTertiary),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: ZTypography.caption
                          .copyWith(color: ZColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: ZSpacing.sm),
              trailing!,
            ],
            if (showChevron && enabled)
              const Padding(
                padding: EdgeInsets.only(left: ZSpacing.xs),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: ZColors.textTertiary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
