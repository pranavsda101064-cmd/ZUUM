import 'package:flutter/material.dart';

import '../format/z_format.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'z_badge.dart';

/// Incoming offer card — category + kind badge, lime surge pill, countdown
/// ring, route block, metrics and accept/decline actions.
class ZOfferCard extends StatelessWidget {
  const ZOfferCard({
    super.key,
    required this.serviceCategoryName,
    required this.isGoods,
    required this.pickupAddress,
    required this.dropAddress,
    required this.distanceLabel,
    required this.pickupEtaLabel,
    required this.farePaise,
    required this.earningPaise,
    required this.secondsLeft,
    required this.totalSeconds,
    this.surgeMultiplier,
    this.goodsSummary,
    this.onAccept,
    this.onDecline,
    this.busy = false,
  });

  final String serviceCategoryName;
  final bool isGoods;
  final String pickupAddress;
  final String dropAddress;
  final String distanceLabel;
  final String pickupEtaLabel;
  final int farePaise;
  final int earningPaise;
  final int secondsLeft;
  final int totalSeconds;
  final double? surgeMultiplier;
  final String? goodsSummary;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool busy;

  bool get _expired => secondsLeft <= 0;

  @override
  Widget build(BuildContext context) {
    final ringColor = _expired
        ? ZColors.error
        : secondsLeft <= 5
            ? ZColors.error
            : ZColors.primary;
    final progress =
        totalSeconds <= 0 ? 0.0 : (secondsLeft / totalSeconds).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(ZSpacing.lg),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.lg),
        border: Border.all(color: ZColors.divider),
        boxShadow: const [
          BoxShadow(
            color: ZColors.shadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(serviceCategoryName, style: ZTypography.titleMd),
                    const SizedBox(width: ZSpacing.sm),
                    ZBadge(label: isGoods ? 'GOODS' : 'RIDE'),
                    if (surgeMultiplier != null && surgeMultiplier! > 1.01) ...[
                      const SizedBox(width: ZSpacing.xs),
                      ZBadge(
                        label: '${surgeMultiplier!.toStringAsFixed(1)}x',
                        tone: ZBadgeTone.highlight,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: ZSpacing.md),
              _CountdownRing(
                secondsLeft: secondsLeft,
                progress: progress,
                color: ringColor,
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.lg),
          _RouteBlock(pickupAddress: pickupAddress, dropAddress: dropAddress),
          if (goodsSummary != null) ...[
            const SizedBox(height: ZSpacing.sm),
            Text(
              goodsSummary!,
              style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
            ),
          ],
          const SizedBox(height: ZSpacing.md),
          Row(
            children: [
              _Metric(label: 'Distance', value: distanceLabel),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: ZSpacing.md),
                color: ZColors.divider,
              ),
              _Metric(label: 'Pickup in', value: pickupEtaLabel),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(ZFormat.inr(farePaise), style: ZTypography.numericLg),
                  Text(
                    'You earn ${ZFormat.inr(earningPaise)}',
                    style: ZTypography.overline.copyWith(
                      color: ZColors.success,
                      letterSpacing: 0.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ZActionButton(
                  label: 'Decline',
                  onPressed: busy ? null : onDecline,
                  secondary: true,
                ),
              ),
              const SizedBox(width: ZSpacing.sm),
              Expanded(
                flex: 2,
                child: ZActionButton(
                  label: _expired ? 'Expired' : 'Accept trip',
                  onPressed: busy || _expired ? null : onAccept,
                  loading: busy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Local slim action button so the offer card keeps its own footprint.
class ZActionButton extends StatelessWidget {
  const ZActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.secondary = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final bg = !enabled
        ? ZColors.disabled
        : secondary
            ? ZColors.accent
            : ZColors.primary;
    final fg = !enabled
        ? ZColors.textTertiary
        : secondary
            ? ZColors.primary
            : ZColors.onPrimary;
    return SizedBox(
      height: 48,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(ZRadii.md),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(ZRadii.md),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Text(
                    label,
                    style: ZTypography.bodyStrong.copyWith(color: fg),
                  ),
          ),
        ),
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.secondsLeft,
    required this.progress,
    required this.color,
  });

  final int secondsLeft;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              color: color,
              backgroundColor: ZColors.divider,
            ),
          ),
          Text(
            '$secondsLeft',
            style: ZTypography.numeric.copyWith(fontSize: 13, color: color),
          ),
        ],
      ),
    );
  }
}

class _RouteBlock extends StatelessWidget {
  const _RouteBlock({required this.pickupAddress, required this.dropAddress});

  final String pickupAddress;
  final String dropAddress;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.circle, size: 10, color: ZColors.success),
            Container(width: 2, height: 20, color: ZColors.divider),
            const Icon(Icons.location_on_rounded, size: 14, color: ZColors.error),
          ],
        ),
        const SizedBox(width: ZSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickupAddress,
                style: ZTypography.captionStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: ZSpacing.sm),
              Text(
                dropAddress,
                style: ZTypography.captionStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ZTypography.overline.copyWith(color: ZColors.textTertiary),
        ),
        Text(value, style: ZTypography.numeric.copyWith(fontSize: 13)),
      ],
    );
  }
}
