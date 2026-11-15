import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Star rating — read-only display or tappable input.
class ZRatingStars extends StatelessWidget {
  const ZRatingStars({
    super.key,
    required this.rating,
    this.size = 16,
    this.onRate,
    this.showValue = false,
  });

  final double rating;
  final double size;
  final ValueChanged<int>? onRate;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: GestureDetector(
              onTap: onRate == null ? null : () => onRate!(i),
              child: Icon(
                rating >= i - 0.25
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: size,
                color: ZColors.primary,
              ),
            ),
          ),
        if (showValue)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              rating.toStringAsFixed(1),
              style: ZTypography.numeric.copyWith(
                fontSize: size - 2,
                color: ZColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
