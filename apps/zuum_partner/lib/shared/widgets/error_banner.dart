import 'package:flutter/material.dart';
import 'package:zuum_design_system/design_system.dart';

/// Inline error banner used across partner auth + wizard screens.
class ZErrorBanner extends StatelessWidget {
  const ZErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZSpacing.md),
      decoration: const BoxDecoration(
        color: ZColors.errorTint,
        borderRadius: BorderRadius.all(Radius.circular(ZRadii.md)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: ZColors.error, size: 18),
          const SizedBox(width: ZSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: ZTypography.caption.copyWith(color: ZColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
