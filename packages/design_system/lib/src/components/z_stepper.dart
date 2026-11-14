import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Horizontal trip stepper (Assigned → Arriving → In progress → Completed).
class ZStepper extends StatelessWidget {
  const ZStepper({super.key, required this.steps, required this.currentIndex});

  final List<String> steps;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= currentIndex
                            ? ZColors.primary
                            : ZColors.disabled,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: i < currentIndex
                            ? ZColors.primary
                            : ZColors.disabled,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    steps[i],
                    style: ZTypography.overline.copyWith(
                      color: i <= currentIndex
                          ? ZColors.textPrimary
                          : ZColors.textTertiary,
                      letterSpacing: 0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (i != steps.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
