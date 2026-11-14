import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import 'earnings_controllers.dart';

/// Earnings dashboard: range summary with the commission split, latest payout
/// and the completed-trip ledger.
class EarningsTab extends ConsumerWidget {
  const EarningsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(earningsRangeProvider);
    final summary = ref.watch(earningsSummaryProvider);
    final trips = ref.watch(earningTripsProvider);
    final payouts = ref.watch(payoutsProvider);

    final start = rangeStart(range);
    final entries = (trips.value?.results ?? const <EarningEntry>[])
        .where((e) => e.at.isAfter(start))
        .toList();

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(
        title: 'Earnings',
        subtitle: '20% commission · weekly payouts',
      ),
      body: RefreshIndicator(
        color: ZColors.primary,
        onRefresh: () async {
          ref.invalidate(earningsSummaryProvider);
          ref.invalidate(earningTripsProvider);
          ref.invalidate(payoutsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(ZSpacing.lg),
          children: [
            ZSegmentedSwitch(
              segments: const [
                ZSegment(label: 'Today'),
                ZSegment(label: 'This week'),
                ZSegment(label: 'This month'),
              ],
              selectedIndex: EarningsRange.values.indexOf(range),
              onChanged: (index) => ref
                  .read(earningsRangeProvider.notifier)
                  .select(EarningsRange.values[index]),
            ),
            const SizedBox(height: ZSpacing.lg),
            summary.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(ZSpacing.xl),
                  child: CircularProgressIndicator(color: ZColors.primary),
                ),
              ),
              error: (error, _) => ZEmptyState(
                illustration: 'empty_generic',
                title: 'Could not load earnings',
                subtitle: error is ApiException
                    ? error.message
                    : 'Pull down to retry.',
              ),
              data: (data) => _SummaryCard(range: range, summary: data),
            ),
            if (payouts.value?.results.isNotEmpty ?? false) ...[
              const SizedBox(height: ZSpacing.lg),
              _PayoutCard(payout: payouts.value!.results.first),
            ],
            const SizedBox(height: ZSpacing.lg),
            Row(
              children: [
                Text(
                  'Recent trips',
                  style: ZTypography.titleMd.copyWith(color: ZColors.textPrimary),
                ),
                const Spacer(),
                Text(
                  '${entries.length} in range',
                  style: ZTypography.caption
                      .copyWith(color: ZColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: ZSpacing.sm),
            if (entries.isEmpty)
              const ZEmptyState(
                illustration: 'empty_tumbler',
                title: 'No trips in this range',
                subtitle: 'Completed trips will show up here with their split.',
              )
            else
              for (final entry in entries) ...[
                _TripEntryTile(entry: entry),
                const SizedBox(height: ZSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.range, required this.summary});

  final EarningsRange range;
  final EarningsSummary summary;

  @override
  Widget build(BuildContext context) {
    final hours = summary.onlineMinutes / 60;
    return Container(
      padding: const EdgeInsets.all(ZSpacing.lg),
      decoration: BoxDecoration(
        color: ZColors.dark,
        borderRadius: BorderRadius.circular(ZRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'NET EARNINGS',
                style: ZTypography.overline.copyWith(
                  color: ZColors.onDarkSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              ZBadge(label: switch (range) {
                EarningsRange.today => 'TODAY',
                EarningsRange.week => '7 DAYS',
                EarningsRange.month => '30 DAYS',
              }),
            ],
          ),
          const SizedBox(height: ZSpacing.sm),
          Text(
            ZFormat.inr(summary.netPaise),
            style: ZTypography.display.copyWith(color: ZColors.onDark),
          ),
          const SizedBox(height: ZSpacing.xs),
          Text(
            '${summary.trips} trips · '
            '${hours.toStringAsFixed(hours >= 10 ? 0 : 1)} h online',
            style: ZTypography.caption.copyWith(color: ZColors.onDarkSecondary),
          ),
          const SizedBox(height: ZSpacing.lg),
          const Divider(color: ZColors.darkOutline, height: 1),
          const SizedBox(height: ZSpacing.md),
          _DarkRow(label: 'Gross fares', value: ZFormat.inr(summary.grossPaise)),
          _DarkRow(
            label: 'Commission',
            value: '−${ZFormat.inr(summary.commissionPaise)}',
          ),
          _DarkRow(
            label: 'Acceptance',
            value: '${summary.acceptanceRate.toStringAsFixed(0)}%',
          ),
          _DarkRow(
            label: 'Cancellations',
            value: '${summary.cancellationRate.toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }
}

class _DarkRow extends StatelessWidget {
  const _DarkRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: ZTypography.caption.copyWith(color: ZColors.onDarkSecondary),
          ),
          const Spacer(),
          Text(
            value,
            style: ZTypography.numeric.copyWith(color: ZColors.onDark),
          ),
        ],
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.payout});

  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final paid = payout.status == PayoutStatus.paid;
    return Container(
      padding: const EdgeInsets.all(ZSpacing.lg),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.lg),
        border: Border.all(color: ZColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: ZColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_outlined, size: 22),
          ),
          const SizedBox(width: ZSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Latest payout', style: ZTypography.caption.copyWith(color: ZColors.textSecondary)),
                Text(
                  ZFormat.inr(payout.amountPaise),
                  style: ZTypography.numericLg,
                ),
                Text(
                  payout.paidAt == null
                      ? 'Settles to your bank · ${payout.method}'
                      : '${ZFormat.shortDate(payout.paidAt!)} · ${payout.method}',
                  style: ZTypography.overline
                      .copyWith(color: ZColors.textTertiary),
                ),
              ],
            ),
          ),
          ZStatusBadge(
            label: payout.status.name.toUpperCase(),
            tone: paid ? ZBadgeTone.success : ZBadgeTone.neutral,
          ),
        ],
      ),
    );
  }
}

class _TripEntryTile extends StatelessWidget {
  const _TripEntryTile({required this.entry});

  final EarningEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZSpacing.md),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.md),
        border: Border.all(color: ZColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ZColors.primaryTint,
              borderRadius: BorderRadius.circular(ZRadii.sm),
            ),
            child: Icon(
              entry.isGoods ? Icons.inventory_2_outlined : Icons.local_taxi_outlined,
              size: 20,
              color: ZColors.textSecondary,
            ),
          ),
          const SizedBox(width: ZSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.categoryName, style: ZTypography.bodyStrong),
                Text(
                  '${ZFormat.shortDateTime(entry.at)} · ${entry.paymentMethod.toUpperCase()}',
                  style: ZTypography.overline
                      .copyWith(color: ZColors.textTertiary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(ZFormat.inr(entry.earningPaise), style: ZTypography.numeric),
              Text(
                'fare ${ZFormat.inr(entry.farePaise)}',
                style: ZTypography.overline.copyWith(color: ZColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
