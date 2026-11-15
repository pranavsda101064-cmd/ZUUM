import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Zuum wordmark — dark tile with Z + "Zuum" (marigold dot as the motion spark).
class ZBrandMark extends StatelessWidget {
  const ZBrandMark({super.key, this.scale = 1, this.onDark = false});

  final double scale;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36 * scale,
          height: 36 * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: onDark ? ZColors.accent : ZColors.dark,
            borderRadius: BorderRadius.circular(10 * scale),
          ),
          child: Text(
            'Z',
            style: TextStyle(
              fontSize: 20 * scale,
              fontWeight: FontWeight.w700,
              color: onDark ? ZColors.dark : ZColors.accent,
              height: 1,
            ),
          ),
        ),
        SizedBox(width: 10 * scale),
        Text(
          'Zuum',
          style: (scale >= 1 ? ZTypography.titleLg : ZTypography.titleMd).copyWith(
            color: onDark ? ZColors.onDark : ZColors.dark,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        Container(
          margin: EdgeInsets.only(left: 3 * scale, bottom: 8 * scale),
          width: 6 * scale,
          height: 6 * scale,
          decoration: BoxDecoration(
            color: onDark ? ZColors.accent : ZColors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
