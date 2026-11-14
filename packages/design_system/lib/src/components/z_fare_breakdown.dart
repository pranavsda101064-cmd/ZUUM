import 'package:flutter/material.dart';

import '../format/z_format.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

class FareLine {
  const FareLine(this.label, this.paise, {this.isTotal = false, this.highlight = false});

  final String label;
  final int paise;
  final bool isTotal;
  final bool highlight;
}

/// Itemized fare breakdown — server-provided lines only; the app never
/// computes fares itself.
class ZFareBreakdown extends StatelessWidget {
  const ZFareBreakdown({super.key, required this.lines, this.discountLast = true});

  final List<FareLine> lines;
  final bool discountLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final line in lines) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    line.label,
                    style: line.isTotal
                        ? ZTypography.bodyStrong
                        : ZTypography.body.copyWith(
                            color: ZColors.textSecondary,
                          ),
                  ),
                ),
                Text(
                  line.paise < 0
                      ? '- ${ZFormat.inr(line.paise.abs())}'
                      : ZFormat.inr(line.paise),
                  style: line.isTotal
                      ? ZTypography.numericLg
                      : ZTypography.numeric.copyWith(
                          color: line.highlight
                              ? ZColors.success
                              : ZColors.textPrimary,
                        ),
                ),
              ],
            ),
          ),
          if (line.isTotal && lines.last != line) ...[
            const SizedBox(height: ZSpacing.xs),
            const Divider(height: 1),
            const SizedBox(height: ZSpacing.xs),
          ],
        ],
      ],
    );
  }
}
