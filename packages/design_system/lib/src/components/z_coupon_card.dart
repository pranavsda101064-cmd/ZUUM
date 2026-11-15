import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Perforated-style coupon ticket: dashed primary border, code badge,
/// offer line, savings pill, trailing action (Gemini spec §o).
class ZCouponCard extends StatelessWidget {
  const ZCouponCard({
    super.key,
    required this.code,
    required this.title,
    this.savingsLabel,
    this.actionLabel = 'Apply',
    this.onAction,
  });

  final String code;
  final String title;
  final String? savingsLabel;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZSpacing.md),
      decoration: BoxDecoration(
        color: ZColors.background,
        borderRadius: BorderRadius.circular(ZRadii.md),
        border: Border.all(color: ZColors.primary, style: BorderStyle.solid),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ZColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              code,
              style: ZTypography.captionStrong.copyWith(
                color: ZColors.primary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(width: ZSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ZTypography.captionStrong),
                if (savingsLabel != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: ZColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      savingsLabel!,
                      style: ZTypography.overline.copyWith(
                        color: ZColors.onPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel, style: ZTypography.captionStrong),
            ),
        ],
      ),
    );
  }
}
