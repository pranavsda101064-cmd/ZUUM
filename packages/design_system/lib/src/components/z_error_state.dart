import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'z_button.dart';

/// Error state with retry. Message is the real failure text — never hidden.
class ZErrorState extends StatelessWidget {
  const ZErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ZSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: ZColors.errorTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: ZColors.error,
                size: 28,
              ),
            ),
            const SizedBox(height: ZSpacing.xl),
            Text(title, style: ZTypography.titleMd, textAlign: TextAlign.center),
            const SizedBox(height: ZSpacing.sm),
            Text(
              message,
              style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: ZSpacing.xxl),
              SizedBox(
                width: 160,
                child: ZButton(
                  label: retryLabel,
                  onPressed: onRetry,
                  variant: ZButtonVariant.secondary,
                  size: ZButtonSize.sm,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
