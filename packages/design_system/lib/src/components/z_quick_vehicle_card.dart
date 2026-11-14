import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

/// Quick vehicle category card (68×76) with live ETA micro-badge —
/// used in the Home quick strip (Gemini spec §2d).
class ZQuickVehicleCard extends StatelessWidget {
  const ZQuickVehicleCard({
    super.key,
    required this.label,
    required this.assetName,
    required this.etaLabel,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final String assetName;
  final String etaLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZRadii.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 68,
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
            SvgPicture.asset(
              'assets/illustrations/$assetName.svg',
              width: 34,
              height: 22,
            ),
            const SizedBox(height: 3),
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
            const SizedBox(height: 1),
            Text(
              etaLabel,
              style: ZTypography.overline.copyWith(
                color: ZColors.textSecondary,
                letterSpacing: 0.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
