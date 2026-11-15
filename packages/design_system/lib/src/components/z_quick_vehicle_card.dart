import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';
import 'z_illustration.dart';

/// Quick vehicle category card used in the Home quick strip.
class ZQuickVehicleCard extends StatelessWidget {
  const ZQuickVehicleCard({
    super.key,
    required this.label,
    required this.assetName,
    this.etaLabel,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String assetName;
  final String? etaLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZRadii.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 76,
        height: 82,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? ZColors.accent : ZColors.background,
          borderRadius: BorderRadius.circular(ZRadii.md),
          border: Border.all(
            color: selected ? ZColors.primary : ZColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ZIllustration(
              assetName,
              width: 42,
              height: 27,
              semanticLabel: label,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: ZTypography.overline.copyWith(
                color: ZColors.dark,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (etaLabel != null) ...[
              const SizedBox(height: 1),
              Text(
                etaLabel!,
                style: ZTypography.overline.copyWith(
                  color: ZColors.textSecondary,
                  letterSpacing: 0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
