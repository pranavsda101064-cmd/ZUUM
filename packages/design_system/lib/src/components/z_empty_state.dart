import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'z_button.dart';

/// Empty state with line-art illustration. Never a fake "coming soon" screen —
/// it states plainly what will live here.
class ZEmptyState extends StatelessWidget {
  const ZEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.illustration = 'empty_generic',
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String illustration;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: ZSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 104,
                child: SvgPicture.asset(
                  'assets/illustrations/$illustration.svg',
                  height: 104,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: ZSpacing.lg),
              Text(
                title,
                style: ZTypography.titleMd,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ZSpacing.sm),
              Text(
                subtitle,
                style:
                    ZTypography.caption.copyWith(color: ZColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: ZSpacing.xl),
                SizedBox(
                  width: 200,
                  child: ZButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    variant: ZButtonVariant.secondary,
                    size: ZButtonSize.sm,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
