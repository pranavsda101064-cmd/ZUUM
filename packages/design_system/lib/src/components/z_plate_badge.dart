import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// Indian commercial licence-plate badge — signboard style: light fill,
/// 1.5dp Dark border, tabular monospace-feel digits.
class ZPlateBadge extends StatelessWidget {
  const ZPlateBadge({super.key, required this.plate, this.fontSize = 15});

  final String plate;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ZColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ZColors.dark, width: 1.5),
      ),
      child: Text(
        plate.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: ZColors.dark,
          fontFeatures: const [FontFeature.tabularFigures()],
          letterSpacing: 0.8,
          height: 1.2,
        ),
      ),
    );
  }
}
