import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'z_fare_breakdown.dart';

/// Commission split for a completed trip: fare, tip, platform share and the
/// driver's take-home, presented with the same ledger look as fares.
class ZCommissionBreakdown extends StatelessWidget {
  const ZCommissionBreakdown({
    super.key,
    required this.farePaise,
    required this.commissionPaise,
    required this.earningPaise,
    this.tipPaise = 0,
    this.commissionPercent = 20,
  });

  final int farePaise;
  final int commissionPaise;
  final int earningPaise;
  final int tipPaise;
  final int commissionPercent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZFareBreakdown(
          lines: [
            FareLine('Trip fare', farePaise),
            if (tipPaise > 0) FareLine('Customer tip', tipPaise),
            FareLine(
              'Platform commission ($commissionPercent%)',
              -commissionPaise,
            ),
            FareLine(
              'You earn',
              earningPaise + tipPaise,
              isTotal: true,
            ),
          ],
        ),
        const SizedBox(height: ZSpacing.sm),
        Text(
          'Commission is deducted by Zuum. Cash trips: you collect the fare '
          'and the commission is adjusted in your next payout.',
          style: ZTypography.overline.copyWith(
            color: ZColors.textTertiary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
