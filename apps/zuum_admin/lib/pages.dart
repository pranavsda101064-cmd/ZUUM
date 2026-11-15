import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zuum_design_system/design_system.dart';

import 'admin_api.dart';
import 'admin_auth.dart';
import 'admin_widgets.dart';
import 'driver_review.dart';

const _pagePad = EdgeInsets.fromLTRB(28, 26, 28, 40);

String _titleCase(String value) {
  final text = value.replaceAll('_', ' ').toLowerCase();
  if (text.isEmpty) return value;
  return text
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

String _time(DateTime? dt) {
  if (dt == null) return '—';
  final local = dt.toLocal();
  final h = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$h:${local.minute.toString().padLeft(2, '0')} $suffix';
}

String _day(DateTime date) {
  const labels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return labels[date.weekday - 1];
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.title,
    required this.caption,
    this.trailing,
  });

  final String title;
  final String caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ZTypography.display.copyWith(
                  color: ZColors.onDark,
                  fontSize: 30,
                  height: 1.1,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                caption,
                style: ZTypography.body.copyWith(
                  color: ZColors.onDarkSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({
    required this.children,
    required this.minItemWidth,
  });

  final List<Widget> children;
  final double minItemWidth;

  @override
  Widget build(BuildContext context) {
    const spacing = ZSpacing.md;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / minItemWidth).floor().clamp(1, 4);
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// OVERVIEW
// ---------------------------------------------------------------------------

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.refreshSignal});
  final int refreshSignal;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late Future<_OverviewBundle> _future;

  AdminApi get _api => AdminScope.of(context).api;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant OverviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) {
      setState(() => _future = _load());
    }
  }

  Future<_OverviewBundle> _load() async {
    final overview = await _api.overview();
    final analytics = await _api.analytics(range: 'week');
    final bookings = await _api.bookings(pageSize: 6);
    final kyc = await _api.drivers(kyc: 'submitted', pageSize: 5);
    return _OverviewBundle(
      overview: overview,
      analytics: analytics,
      bookings: bookings.results,
      kyc: kyc.results,
    );
  }

  Future<void> _review(OpsDriver driver) async {
    await DriverReviewDialog.show(
      context,
      driverId: driver.id,
      api: _api,
      onChanged: () {
        if (mounted) setState(() => _future = _load());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_OverviewBundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingPage();
        }
        if (snapshot.hasError) {
          return Padding(
            padding: _pagePad,
            child: AdminError(
              message: snapshot.error is AdminApiException
                  ? (snapshot.error as AdminApiException).message
                  : 'Could not load the command center.',
              onRetry: () => setState(() => _future = _load()),
            ),
          );
        }
        final data = snapshot.data!;
        return ListView(
          padding: _pagePad,
          children: [
            _PageIntro(
              title: 'Command center',
              caption:
                  'Everything moving in Bengaluru, right now. Auto-refreshes every 30 seconds.',
              trailing: _LiveSummary(overview: data.overview),
            ),
            const SizedBox(height: ZSpacing.xxl),
            _DashboardGrid(
              minItemWidth: 240,
              children: [
                AdminMetricCard(
                  label: 'Gross fares today',
                  value: ZFormat.inr(data.overview.revenueTodayPaise, compact: true),
                  caption:
                      '${ZFormat.inr(data.overview.commissionTodayPaise, compact: true)} platform commission',
                  icon: Icons.currency_rupee_rounded,
                  accent: true,
                  bars: data.analytics.series
                      .map((p) => p.revenuePaise)
                      .toList(),
                ),
                AdminMetricCard(
                  label: 'Trips today',
                  value: '${data.overview.bookingsToday}',
                  caption:
                      '${data.overview.completedToday} completed · ${data.overview.bookingsToday - data.overview.completedToday} open',
                  icon: Icons.route_rounded,
                  bars: data.analytics.series.map((p) => p.trips).toList(),
                ),
                AdminMetricCard(
                  label: 'Captains online',
                  value:
                      '${data.overview.onlineDrivers}/${data.overview.driversTotal}',
                  caption:
                      '${data.overview.pendingKyc} KYC submissions waiting',
                  icon: Icons.groups_2_outlined,
                  tone: data.overview.onlineDrivers > 0
                      ? ZColors.success
                      : null,
                ),
                AdminMetricCard(
                  label: 'Active SOS',
                  value: '${data.overview.activeSos}',
                  caption: data.overview.activeSos == 0
                      ? 'No emergencies open'
                      : 'Needs immediate attention',
                  icon: Icons.sos_rounded,
                  tone: data.overview.activeSos == 0 ? null : ZColors.error,
                ),
              ],
            ),
            const SizedBox(height: ZSpacing.md),
            _DashboardGrid(
              minItemWidth: 210,
              children: [
                _MicroStat(
                  label: 'Pending KYC',
                  value: '${data.overview.pendingKyc}',
                  icon: Icons.badge_outlined,
                ),
                _MicroStat(
                  label: 'Open tickets',
                  value: '${data.overview.openTickets}',
                  icon: Icons.support_agent_rounded,
                ),
                _MicroStat(
                  label: 'Payouts pending',
                  value: ZFormat.inr(
                    data.overview.payoutsPendingPaise,
                    compact: true,
                  ),
                  icon: Icons.account_balance_outlined,
                ),
                _MicroStat(
                  label: 'Commission today',
                  value: ZFormat.inr(
                    data.overview.commissionTodayPaise,
                    compact: true,
                  ),
                  icon: Icons.savings_outlined,
                ),
              ],
            ),
            const SizedBox(height: ZSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final chart = _RevenuePanel(analytics: data.analytics);
                final mix = _CategoryPanel(categories: data.analytics.topCategories);
                if (!wide) {
                  return Column(
                    children: [
                      chart,
                      const SizedBox(height: ZSpacing.md),
                      mix,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: chart),
                    const SizedBox(width: ZSpacing.md),
                    Expanded(flex: 4, child: mix),
                  ],
                );
              },
            ),
            const SizedBox(height: ZSpacing.xl),
            _InMotion(overview: data.overview),
            const SizedBox(height: ZSpacing.xl),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1050;
                final recent = _RecentBookings(
                  bookings: data.bookings,
                  onRefresh: () => setState(() => _future = _load()),
                );
                final attention = _AttentionPanel(
                  kyc: data.kyc,
                  overview: data.overview,
                  onReview: _review,
                );
                if (!wide) {
                  return Column(
                    children: [
                      recent,
                      const SizedBox(height: ZSpacing.md),
                      attention,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: recent),
                    const SizedBox(width: ZSpacing.md),
                    Expanded(flex: 4, child: attention),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _OverviewBundle {
  const _OverviewBundle({
    required this.overview,
    required this.analytics,
    required this.bookings,
    required this.kyc,
  });

  final OpsOverview overview;
  final OpsAnalytics analytics;
  final List<OpsBooking> bookings;
  final List<OpsDriver> kyc;
}

class _LiveSummary extends StatelessWidget {
  const _LiveSummary({required this.overview});
  final OpsOverview overview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: ZColors.darkSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ZColors.darkOutline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AdminPill(label: 'LIVE', tone: AdminTone.success, dot: true),
          const SizedBox(width: 10),
          Text(
            '${overview.status('SEARCHING')} searching · ${overview.status('IN_PROGRESS')} on trip',
            style: ZTypography.caption.copyWith(
              color: ZColors.onDarkSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicroStat extends StatelessWidget {
  const _MicroStat({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ZColors.onDarkSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: ZTypography.caption.copyWith(
                color: ZColors.onDarkSecondary,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: ZTypography.numeric.copyWith(
              color: ZColors.onDark,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenuePanel extends StatelessWidget {
  const _RevenuePanel({required this.analytics});
  final OpsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Revenue rhythm',
            caption: 'Fares settled over the last seven days',
            trailing: AdminPill(
              label: ZFormat.inr(analytics.revenuePaise, compact: true),
              tone: AdminTone.info,
            ),
          ),
          const SizedBox(height: ZSpacing.xl),
          AdminTrendChart(
            values: analytics.series.map((p) => p.revenuePaise).toList(),
            labels: analytics.series.map((p) => _day(p.date)).toList(),
          ),
          const SizedBox(height: ZSpacing.md),
          Row(
            children: [
              _Legend(
                label: 'Driver payout',
                value: ZFormat.inr(analytics.driverPaise, compact: true),
              ),
              const SizedBox(width: 24),
              _Legend(
                label: 'Platform',
                value: ZFormat.inr(analytics.commissionPaise, compact: true),
              ),
              const Spacer(),
              Text(
                '${analytics.trips} trips',
                style: ZTypography.caption.copyWith(
                  color: ZColors.onDarkSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: ZColors.onDarkSecondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label  ',
          style: ZTypography.caption.copyWith(
            color: ZColors.onDarkSecondary,
            fontSize: 11,
          ),
        ),
        Text(
          value,
          style: ZTypography.captionStrong.copyWith(
            color: ZColors.onDark,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({required this.categories});
  final List<CategorySlice> categories;

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<int>(0, (sum, c) => sum + c.revenuePaise);
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Category mix',
            caption: 'Where the week’s revenue sits',
          ),
          const SizedBox(height: ZSpacing.lg),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: AdminEmpty(title: 'No settled trips yet'),
            )
          else
            for (final category in categories) ...[
              _CategoryRow(category: category, total: total),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.total});
  final CategorySlice category;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : category.revenuePaise / total;
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ZColors.onDark,
                borderRadius: BorderRadius.circular(6),
              ),
              child: ZVehicleIcon(
                categoryCode: category.name,
                width: 30,
                height: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                category.name,
                style: ZTypography.captionStrong.copyWith(
                  color: ZColors.onDark,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              ZFormat.inr(category.revenuePaise, compact: true),
              style: ZTypography.numeric.copyWith(
                color: ZColors.onDark,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio.toDouble().clamp(0.04, 1),
            minHeight: 4,
            backgroundColor: ZColors.darkRaised,
            valueColor: const AlwaysStoppedAnimation(ZColors.onDarkSecondary),
          ),
        ),
      ],
    );
  }
}

class _InMotion extends StatelessWidget {
  const _InMotion({required this.overview});
  final OpsOverview overview;

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('Searching', overview.status('SEARCHING'), Icons.radar_rounded),
      ('Assigned', overview.status('ASSIGNED'), Icons.person_pin_circle_outlined),
      ('Arrived', overview.status('ARRIVED'), Icons.pin_drop_outlined),
      ('On trip', overview.status('IN_PROGRESS'), Icons.navigation_rounded),
    ];
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'In motion now',
            caption: 'Live booking pipeline across the city',
            trailing: Text(
              '${overview.bookingsToday} created today',
              style: ZTypography.caption.copyWith(
                color: ZColors.onDarkSecondary,
              ),
            ),
          ),
          const SizedBox(height: ZSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 900 ? 4 : 2;
              final width =
                  (constraints.maxWidth - 10 * (columns - 1)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final stage in stages)
                    SizedBox(
                      width: width,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ZColors.darkRaised.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(ZRadii.md),
                          border: Border.all(color: ZColors.darkOutline),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              stage.$3,
                              size: 17,
                              color: ZColors.onDarkSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stage.$1,
                                style: ZTypography.captionStrong.copyWith(
                                  color: ZColors.onDarkSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            Text(
                              '${stage.$2}',
                              style: ZTypography.numericLg.copyWith(
                                color: ZColors.onDark,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentBookings extends StatelessWidget {
  const _RecentBookings({required this.bookings, required this.onRefresh});
  final List<OpsBooking> bookings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeader(
            title: 'Latest bookings',
            caption: 'Most recent demand into the network',
            trailing: AdminButton(
              label: 'Refresh',
              icon: Icons.refresh_rounded,
              compact: true,
              onPressed: onRefresh,
            ),
          ),
          const SizedBox(height: ZSpacing.md),
          if (bookings.isEmpty)
            const AdminEmpty(title: 'No bookings yet')
          else
            _BookingTable(bookings: bookings, compact: true),
        ],
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({
    required this.kyc,
    required this.overview,
    required this.onReview,
  });

  final List<OpsDriver> kyc;
  final OpsOverview overview;
  final ValueChanged<OpsDriver> onReview;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminSectionHeader(
            title: 'Needs attention',
            caption: 'Clear the queue before it becomes a trend',
          ),
          const SizedBox(height: ZSpacing.lg),
          if (overview.activeSos > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ZColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(ZRadii.md),
                border: Border.all(color: ZColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sos_rounded, color: ZColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${overview.activeSos} active SOS',
                      style: ZTypography.captionStrong.copyWith(
                        color: ZColors.error,
                      ),
                    ),
                  ),
                  Text(
                    'Resolve in tools',
                    style: ZTypography.overline.copyWith(
                      color: ZColors.error,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          if (kyc.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: ZColors.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'KYC queue is clear',
                    style: ZTypography.caption.copyWith(
                      color: ZColors.onDarkSecondary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              'KYC waiting',
              style: ZTypography.overline.copyWith(
                color: ZColors.onDarkSecondary,
                fontSize: 9,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            for (final driver in kyc) ...[
              Row(
                children: [
                  AdminAvatar(label: driver.name, size: 30),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: ZTypography.captionStrong.copyWith(
                            color: ZColors.onDark,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          driver.vehicles.isEmpty
                              ? 'No vehicle on file'
                              : driver.vehicles.first,
                          style: ZTypography.overline.copyWith(
                            color: ZColors.onDarkSecondary,
                            fontSize: 9,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  AdminButton(
                    label: 'Review docs',
                    compact: true,
                    onPressed: () => onReview(driver),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
          const Divider(height: 26, color: ZColors.darkOutline),
          _AttentionLine(
            icon: Icons.support_agent_rounded,
            label: 'Open support tickets',
            value: '${overview.openTickets}',
          ),
          const SizedBox(height: 10),
          _AttentionLine(
            icon: Icons.account_balance_outlined,
            label: 'Payouts pending',
            value: ZFormat.inr(overview.payoutsPendingPaise, compact: true),
          ),
          const SizedBox(height: 10),
          _AttentionLine(
            icon: Icons.badge_outlined,
            label: 'KYC submissions',
            value: '${overview.pendingKyc}',
          ),
        ],
      ),
    );
  }
}

class _AttentionLine extends StatelessWidget {
  const _AttentionLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: ZColors.onDarkSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: ZTypography.caption.copyWith(
              color: ZColors.onDarkSecondary,
              fontSize: 11,
            ),
          ),
        ),
        Text(
          value,
          style: ZTypography.numeric.copyWith(
            color: ZColors.onDark,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _BookingTable extends StatelessWidget {
  const _BookingTable({
    required this.bookings,
    this.compact = false,
    this.onCancel,
  });

  final List<OpsBooking> bookings;
  final bool compact;
  final Future<void> Function(OpsBooking)? onCancel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: compact ? 760 : 980,
        child: Column(
          children: [
            AdminTableHeader(
              cells: compact
                  ? const ['Booking', 'Customer', 'Category', 'Fare', 'Status']
                  : const [
                      'Booking',
                      'Customer',
                      'Route',
                      'Driver',
                      'Fare',
                      'Status',
                      'When',
                      '',
                    ],
              widths: compact
                  ? const [15, 27, 18, 15, 25]
                  : const [13, 20, 27, 15, 10, 12, 9, 12],
            ),
            for (final booking in bookings)
              _BookingRow(
                booking: booking,
                compact: compact,
                onCancel: onCancel,
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({
    required this.booking,
    required this.compact,
    this.onCancel,
  });

  final OpsBooking booking;
  final bool compact;
  final Future<void> Function(OpsBooking)? onCancel;

  @override
  Widget build(BuildContext context) {
    final cells = compact
        ? [
            _Mono(
              '#${_shortId(booking.id)}',
              style: ZTypography.numeric.copyWith(fontSize: 11),
            ),
            _TwoLine(top: booking.customer, bottom: _time(booking.createdAt)),
            _Mono(booking.serviceCategory),
            _Mono(ZFormat.inr(booking.farePaise)),
            AdminPill(
              label: _titleCase(booking.status),
              tone: AdminPill.toneFor(booking.status),
            ),
          ]
        : [
            _Mono(
              '#${_shortId(booking.id)}',
              style: ZTypography.numeric.copyWith(fontSize: 11),
            ),
            _TwoLine(top: booking.customer, bottom: booking.paymentState),
            _TwoLine(
              top: booking.pickup,
              bottom: booking.drop,
              maxWidth: 260,
            ),
            _Mono(booking.driver ?? 'Unassigned'),
            _Mono(ZFormat.inr(booking.farePaise)),
            AdminPill(
              label: _titleCase(booking.status),
              tone: AdminPill.toneFor(booking.status),
            ),
            _Mono(_time(booking.createdAt)),
            if (onCancel != null &&
                booking.status != 'COMPLETED' &&
                booking.status != 'CANCELLED')
              AdminButton(
                label: 'Cancel',
                compact: true,
                danger: true,
                onPressed: () => onCancel!(booking),
              )
            else
              const SizedBox.shrink(),
          ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ZColors.darkOutline)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: compact
                  ? const [15, 27, 18, 15, 25][i]
                  : const [13, 20, 27, 15, 10, 12, 9, 12][i],
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: cells[i],
              ),
            ),
        ],
      ),
    );
  }
}

class _Mono extends StatelessWidget {
  const _Mono(this.text, {this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ??
        ZTypography.caption.copyWith(
          color: ZColors.onDark,
          fontSize: 12,
        );
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: base.copyWith(color: ZColors.onDark),
    );
  }
}

class _TwoLine extends StatelessWidget {
  const _TwoLine({
    required this.top,
    required this.bottom,
    this.maxWidth,
  });
  final String top;
  final String bottom;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            top,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ZTypography.captionStrong.copyWith(
              color: ZColors.onDark,
              fontSize: 12,
            ),
          ),
          Text(
            bottom,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ZTypography.overline.copyWith(
              color: ZColors.onDarkSecondary,
              fontSize: 9,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LIVE OPS
// ---------------------------------------------------------------------------

class LiveOpsPage extends StatefulWidget {
  const LiveOpsPage({super.key, required this.refreshSignal});
  final int refreshSignal;

  @override
  State<LiveOpsPage> createState() => _LiveOpsPageState();
}

class _LiveOpsPageState extends State<LiveOpsPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _filter = 'All';
  int _page = 1;
  late Future<OpsPage<OpsBooking>> _future;
  final Set<String> _cancelling = {};

  static const _filters = [
    'All',
    'Searching',
    'Assigned',
    'Arrived',
    'In progress',
    'Completed',
    'Cancelled',
  ];

  AdminApi get _api => AdminScope.of(context).api;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant LiveOpsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<OpsPage<OpsBooking>> _load() {
    final status = switch (_filter) {
      'Searching' => 'SEARCHING',
      'Assigned' => 'ASSIGNED',
      'Arrived' => 'ARRIVED',
      'In progress' => 'IN_PROGRESS',
      'Completed' => 'COMPLETED',
      'Cancelled' => 'CANCELLED',
      _ => null,
    };
    return _api.bookings(
      status: status,
      search: _search.text,
      page: _page,
      pageSize: 20,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _cancel(OpsBooking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: ZColors.darkRaised,
        title: const Text('Cancel booking?', style: TextStyle(color: ZColors.onDark)),
        content: Text(
          'This cancels #${_shortId(booking.id)} for ${booking.customer}. The customer and captain are notified.',
          style: const TextStyle(color: ZColors.onDarkSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Cancel booking',
                style: TextStyle(color: ZColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _cancelling.add(booking.id));
    try {
      await _api.cancelBooking(booking.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is AdminApiException ? e.message : 'Cancel failed')),
      );
    } finally {
      if (mounted) setState(() => _cancelling.remove(booking.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePad,
      children: [
        const _PageIntro(
          title: 'Live ops',
          caption: 'Every booking in the pipeline, from request to receipt.',
        ),
        const SizedBox(height: ZSpacing.xxl),
        Wrap(
          spacing: ZSpacing.sm,
          runSpacing: ZSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminSearch(
              controller: _search,
              hint: 'Search booking, rider, or route',
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  _page = 1;
                  _reload();
                });
              },
            ),
            AdminFilterBar(
              options: _filters,
              value: _filter,
              onChanged: (value) {
                setState(() {
                  _filter = value;
                  _page = 1;
                  _future = _load();
                });
              },
            ),
          ],
        ),
        const SizedBox(height: ZSpacing.md),
        FutureBuilder<OpsPage<OpsBooking>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const AdminSkeleton(height: 300);
            }
            if (snapshot.hasError) {
              return AdminError(
                message: snapshot.error is AdminApiException
                    ? (snapshot.error as AdminApiException).message
                    : 'Could not load bookings.',
                onRetry: _reload,
              );
            }
            final page = snapshot.data!;
            return AdminPanel(
              child: Column(
                children: [
                  if (page.results.isEmpty)
                    const AdminEmpty(
                      title: 'No bookings in this slice',
                      message: 'Try another status or clear the search.',
                    )
                  else
                    _BookingTable(
                      bookings: page.results,
                      onCancel: _cancel,
                    ),
                  const SizedBox(height: ZSpacing.md),
                  AdminPager(
                    page: _page,
                    total: page.count,
                    pageSize: 20,
                    onPrevious: _page > 1
                        ? () {
                            setState(() {
                              _page--;
                              _future = _load();
                            });
                          }
                        : null,
                    onNext: _page * 20 < page.count
                        ? () {
                            setState(() {
                              _page++;
                              _future = _load();
                            });
                          }
                        : null,
                  ),
                  if (_cancelling.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Cancelling ${_cancelling.length} booking(s)…',
                        style: ZTypography.overline.copyWith(
                          color: ZColors.onDarkSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// DRIVERS
// ---------------------------------------------------------------------------

class DriversPage extends StatefulWidget {
  const DriversPage({super.key, required this.refreshSignal});
  final int refreshSignal;

  @override
  State<DriversPage> createState() => _DriversPageState();
}

class _DriversPageState extends State<DriversPage> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _filter = 'All';
  int _page = 1;
  late Future<OpsPage<OpsDriver>> _future;

  AdminApi get _api => AdminScope.of(context).api;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant DriversPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<OpsPage<OpsDriver>> _load() {
    final kyc = _filter == 'KYC pending' ? 'submitted' : null;
    final approval = switch (_filter) {
      'Approved' => 'active',
      'Suspended' => 'suspended',
      _ => null,
    };
    return _api.drivers(
      kyc: kyc,
      approval: approval,
      search: _search.text,
      page: _page,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _review(OpsDriver driver) async {
    await DriverReviewDialog.show(
      context,
      driverId: driver.id,
      api: _api,
      onChanged: _reload,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePad,
      children: [
        const _PageIntro(
          title: 'Captains',
          caption: 'Verification, fleet assignment and account health.',
        ),
        const SizedBox(height: ZSpacing.xxl),
        Wrap(
          spacing: ZSpacing.sm,
          runSpacing: ZSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AdminSearch(
              controller: _search,
              hint: 'Search name, email, phone, licence',
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 350), () {
                  _page = 1;
                  _reload();
                });
              },
            ),
            AdminFilterBar(
              options: const [
                'All',
                'KYC pending',
                'Approved',
                'Suspended',
              ],
              value: _filter,
              onChanged: (value) => setState(() {
                _filter = value;
                _page = 1;
                _future = _load();
              }),
            ),
          ],
        ),
        const SizedBox(height: ZSpacing.md),
        FutureBuilder<OpsPage<OpsDriver>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const AdminSkeleton(height: 340);
            }
            if (snapshot.hasError) {
              return AdminError(
                message: snapshot.error is AdminApiException
                    ? (snapshot.error as AdminApiException).message
                    : 'Could not load drivers.',
                onRetry: _reload,
              );
            }
            final page = snapshot.data!;
            return AdminPanel(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  if (page.results.isEmpty)
                    const AdminEmpty(title: 'No captains match this view')
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 980,
                        child: Column(
                          children: [
                            const AdminTableHeader(
                              cells: [
                                'Captain',
                                'Vehicle',
                                'Rating',
                                'Docs',
                                'KYC',
                                'Online',
                                '',
                              ],
                              widths: [24, 20, 10, 8, 12, 10, 16],
                            ),
                            for (final driver in page.results)
                              _DriverRow(
                                driver: driver,
                                onReview: () => _review(driver),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: ZSpacing.md),
                  AdminPager(
                    page: _page,
                    total: page.count,
                    pageSize: 25,
                    onPrevious: _page > 1
                        ? () => setState(() {
                              _page--;
                              _future = _load();
                            })
                        : null,
                    onNext: _page * 25 < page.count
                        ? () => setState(() {
                              _page++;
                              _future = _load();
                            })
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DriverRow extends StatelessWidget {
  const _DriverRow({
    required this.driver,
    required this.onReview,
  });

  final OpsDriver driver;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ZColors.darkOutline)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 24,
            child: Row(
              children: [
                AdminAvatar(label: driver.name, size: 32),
                const SizedBox(width: 9),
                Expanded(
                  child: _TwoLine(top: driver.name, bottom: driver.email),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 20,
            child: _TwoLine(
              top: driver.vehicles.isEmpty ? 'No vehicle' : driver.vehicles.first,
              bottom: driver.fleet ?? 'Independent',
            ),
          ),
          Expanded(
            flex: 10,
            child: Row(
              children: [
                const Icon(Icons.star_rounded,
                    size: 13, color: ZColors.onDarkSecondary),
                const SizedBox(width: 3),
                Text(
                  driver.rating.toStringAsFixed(1),
                  style: ZTypography.captionStrong.copyWith(
                    color: ZColors.onDark,
                    fontSize: 12,
                  ),
                ),
                Text(
                  ' (${driver.ratingCount})',
                  style: ZTypography.overline.copyWith(
                    color: ZColors.onDarkSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(
              '${driver.documents}/3',
              style: ZTypography.caption.copyWith(
                color: driver.documents >= 3
                    ? ZColors.success
                    : ZColors.warning,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: AdminPill(
              label: _titleCase(driver.kycStatus),
              tone: AdminPill.toneFor(driver.kycStatus),
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              driver.onlineState == 'offline' ? 'Offline' : 'Online',
              style: ZTypography.caption.copyWith(
                color: driver.onlineState == 'offline'
                    ? ZColors.onDarkSecondary
                    : ZColors.success,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            flex: 16,
            child: Align(
              alignment: Alignment.centerRight,
              child: AdminButton(
                label: driver.isApproved ? 'Review / suspend' : 'Review docs',
                compact: true,
                onPressed: onReview,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MONEY
// ---------------------------------------------------------------------------

class MoneyPage extends StatefulWidget {
  const MoneyPage({super.key, required this.refreshSignal});
  final int refreshSignal;

  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  String _range = 'Today';
  late Future<_MoneyBundle> _future;
  final Set<String> _paying = {};

  AdminApi get _api => AdminScope.of(context).api;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant MoneyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) _reload();
  }

  Future<_MoneyBundle> _load() async {
    final finance = await _api.finance(range: _range.toLowerCase());
    final payouts = await _api.payouts(pageSize: 25);
    return _MoneyBundle(finance: finance, payouts: payouts);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _markPaid(OpsPayout payout) async {
    setState(() => _paying.add(payout.id));
    try {
      await _api.markPayoutPaid(payout.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AdminApiException ? e.message : 'Could not mark payout paid',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _paying.remove(payout.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MoneyBundle>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingPage();
        }
        if (snapshot.hasError) {
          return Padding(
            padding: _pagePad,
            child: AdminError(
              message: snapshot.error is AdminApiException
                  ? (snapshot.error as AdminApiException).message
                  : 'Could not load finance.',
              onRetry: _reload,
            ),
          );
        }
        final data = snapshot.data!;
        final finance = data.finance;
        return ListView(
          padding: _pagePad,
          children: [
            _PageIntro(
              title: 'Money',
              caption:
                  'Fares, commission and captain payouts, reconciled in one place.',
              trailing: AdminFilterBar(
                options: const ['Today', 'Week', 'Month'],
                value: _range,
                onChanged: (value) {
                  setState(() {
                    _range = value;
                    _future = _load();
                  });
                },
              ),
            ),
            const SizedBox(height: ZSpacing.xxl),
            _DashboardGrid(
              minItemWidth: 230,
              children: [
                AdminMetricCard(
                  label: 'Gross fares',
                  value: ZFormat.inr(finance.grossPaise, compact: true),
                  caption: '${finance.trips} completed trips',
                  icon: Icons.receipt_long_outlined,
                  accent: true,
                ),
                AdminMetricCard(
                  label: 'Platform commission',
                  value: ZFormat.inr(finance.commissionPaise, compact: true),
                  caption: '20% blended take rate',
                  icon: Icons.percent_rounded,
                ),
                AdminMetricCard(
                  label: 'Captain earnings',
                  value: ZFormat.inr(finance.driverPaise, compact: true),
                  caption: 'Settled trip payouts',
                  icon: Icons.groups_2_outlined,
                ),
                AdminMetricCard(
                  label: 'Pending payouts',
                  value: ZFormat.inr(finance.pendingPaise, compact: true),
                  caption: '${ZFormat.inr(finance.paidPaise, compact: true)} paid this cycle',
                  icon: Icons.account_balance_outlined,
                  tone: finance.pendingPaise > 0 ? ZColors.warning : null,
                ),
              ],
            ),
            const SizedBox(height: ZSpacing.xl),
            AdminPanel(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  const AdminSectionHeader(
                    title: 'Payout batches',
                    caption: 'Pending and recent captain transfers',
                  ),
                  const SizedBox(height: ZSpacing.md),
                  if (data.payouts.results.isEmpty)
                    const AdminEmpty(title: 'No payouts yet')
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 900,
                        child: Column(
                          children: [
                            const AdminTableHeader(
                              cells: [
                                'Captain',
                                'Amount',
                                'Method',
                                'Batch',
                                'Status',
                                'Created',
                                '',
                              ],
                              widths: [24, 13, 11, 12, 12, 14, 14],
                            ),
                            for (final payout in data.payouts.results)
                              _PayoutRow(
                                payout: payout,
                                busy: _paying.contains(payout.id),
                                onPaid: () => _markPaid(payout),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: ZSpacing.sm),
                  Text(
                    '${data.payouts.count} payout records',
                    style: ZTypography.caption.copyWith(
                      color: ZColors.onDarkSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MoneyBundle {
  const _MoneyBundle({required this.finance, required this.payouts});
  final OpsFinance finance;
  final OpsPage<OpsPayout> payouts;
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({
    required this.payout,
    required this.busy,
    required this.onPaid,
  });
  final OpsPayout payout;
  final bool busy;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ZColors.darkOutline)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 24,
            child: _TwoLine(top: payout.driver, bottom: payout.driverEmail),
          ),
          Expanded(
            flex: 13,
            child: Text(
              ZFormat.inr(payout.amountPaise),
              style: ZTypography.numeric.copyWith(
                color: ZColors.onDark,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 11,
            child: _Mono(_titleCase(payout.method)),
          ),
          Expanded(
            flex: 12,
            child: _Mono(payout.batchRef ?? '—'),
          ),
          Expanded(
            flex: 12,
            child: AdminPill(
              label: _titleCase(payout.status),
              tone: AdminPill.toneFor(payout.status),
            ),
          ),
          Expanded(
            flex: 14,
            child: _Mono(_time(payout.createdAt)),
          ),
          Expanded(
            flex: 14,
            child: payout.status == 'paid'
                ? const Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.check_rounded,
                        size: 16, color: ZColors.success),
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: AdminButton(
                      label: 'Mark paid',
                      compact: true,
                      primary: true,
                      busy: busy,
                      onPressed: busy ? null : onPaid,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SUPPORT
// ---------------------------------------------------------------------------

class SupportPage extends StatefulWidget {
  const SupportPage({super.key, required this.refreshSignal});
  final int refreshSignal;

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  String _filter = 'Open';
  late Future<OpsPage<OpsTicket>> _future;

  AdminApi get _api => AdminScope.of(context).api;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant SupportPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshSignal != oldWidget.refreshSignal) _reload();
  }

  Future<OpsPage<OpsTicket>> _load() {
    final status = switch (_filter) {
      'Open' => 'open',
      'Pending' => 'pending',
      'Resolved' => 'resolved',
      _ => null,
    };
    return _api.tickets(status: status);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _open(OpsTicket ticket) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TicketDialog(ticket: ticket, api: _api, onChanged: _reload),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePad,
      children: [
        const _PageIntro(
          title: 'Support',
          caption: 'Rider and captain issues, triaged for the Bengaluru desk.',
        ),
        const SizedBox(height: ZSpacing.xxl),
        AdminFilterBar(
          options: const ['Open', 'Pending', 'Resolved', 'All'],
          value: _filter,
          onChanged: (value) => setState(() {
            _filter = value;
            _future = _load();
          }),
        ),
        const SizedBox(height: ZSpacing.md),
        FutureBuilder<OpsPage<OpsTicket>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const AdminSkeleton(height: 300);
            }
            if (snapshot.hasError) {
              return AdminError(
                message: snapshot.error is AdminApiException
                    ? (snapshot.error as AdminApiException).message
                    : 'Could not load tickets.',
                onRetry: _reload,
              );
            }
            final page = snapshot.data!;
            return AdminPanel(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  if (page.results.isEmpty)
                    const AdminEmpty(title: 'Queue clear', message: 'No tickets in this view.')
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 900,
                        child: Column(
                          children: [
                            const AdminTableHeader(
                              cells: [
                                'Ticket',
                                'Customer',
                                'Category',
                                'Priority',
                                'Status',
                                'Opened',
                                '',
                              ],
                              widths: [22, 22, 16, 10, 12, 12, 10],
                            ),
                            for (final ticket in page.results)
                              _TicketRow(
                                ticket: ticket,
                                onOpen: () => _open(ticket),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: ZSpacing.sm),
                  Text(
                    '${page.count} tickets',
                    style: ZTypography.caption.copyWith(
                      color: ZColors.onDarkSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.onOpen});
  final OpsTicket ticket;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ZColors.darkOutline)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 22,
            child: _TwoLine(
              top: '#${_shortId(ticket.id)}',
              bottom: ticket.subject,
            ),
          ),
          Expanded(flex: 22, child: _Mono(ticket.customer)),
          Expanded(flex: 16, child: _Mono(_titleCase(ticket.category))),
          Expanded(
            flex: 10,
            child: AdminPill(
              label: _titleCase(ticket.priority),
              tone: AdminPill.toneFor(ticket.priority),
            ),
          ),
          Expanded(
            flex: 12,
            child: AdminPill(
              label: _titleCase(ticket.status),
              tone: AdminPill.toneFor(ticket.status),
            ),
          ),
          Expanded(flex: 12, child: _Mono(_time(ticket.createdAt))),
          Expanded(
            flex: 10,
            child: Align(
              alignment: Alignment.centerRight,
              child: AdminButton(
                label: 'Open',
                compact: true,
                onPressed: onOpen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketDialog extends StatefulWidget {
  const _TicketDialog({
    required this.ticket,
    required this.api,
    required this.onChanged,
  });

  final OpsTicket ticket;
  final AdminApi api;
  final VoidCallback onChanged;

  @override
  State<_TicketDialog> createState() => _TicketDialogState();
}

class _TicketDialogState extends State<_TicketDialog> {
  final _reply = TextEditingController();
  late Future<Map<String, dynamic>> _future;
  String _status = 'open';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _status = widget.ticket.status;
    _future = widget.api.ticket(widget.ticket.id);
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.api.replyTicket(widget.ticket.id, body, status: _status);
      widget.onChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AdminApiException ? e.message : 'Could not send reply',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ZColors.darkRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZRadii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(ZSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AdminEyebrow('#${_shortId(widget.ticket.id)} · ${widget.ticket.category}'),
                        const SizedBox(height: 4),
                        Text(
                          widget.ticket.subject,
                          style: ZTypography.titleMd.copyWith(
                            color: ZColors.onDark,
                          ),
                        ),
                        Text(
                          widget.ticket.customer,
                          style: ZTypography.caption.copyWith(
                            color: ZColors.onDarkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: ZColors.onDarkSecondary),
                  ),
                ],
              ),
              const SizedBox(height: ZSpacing.md),
              FutureBuilder<Map<String, dynamic>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ZColors.onDarkSecondary,
                        ),
                      ),
                    );
                  }
                  final messages = (snapshot.data!['messages'] as List? ?? const []);
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final message in messages)
                          _MessageBubble(
                            body: '${(message as Map)['body'] ?? ''}',
                            author: '${message['author'] ?? ''}',
                            at: DateTime.tryParse('${message['created_at'] ?? ''}'),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: ZSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      dropdownColor: ZColors.darkRaised,
                      style: const TextStyle(
                        color: ZColors.onDark,
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        labelStyle:
                            TextStyle(color: ZColors.onDarkSecondary),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ZColors.darkOutline),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'resolved', child: Text('Resolved')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _status = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _reply,
                      style: const TextStyle(
                        color: ZColors.onDark,
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Reply to the customer…',
                        hintStyle:
                            TextStyle(color: ZColors.onDarkSecondary),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: ZColors.darkOutline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              BorderSide(color: ZColors.onDarkSecondary),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AdminButton(
                    label: 'Send',
                    primary: true,
                    busy: _sending,
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.body,
    required this.author,
    required this.at,
  });
  final String body;
  final String author;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final ops = author == 'ops';
    return Align(
      alignment: ops ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: ops
              ? ZColors.onDark
              : ZColors.darkSurface,
          borderRadius: BorderRadius.circular(ZRadii.md),
          border: Border.all(color: ZColors.darkOutline),
        ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(
              body,
              style: ZTypography.caption.copyWith(
                color: ops ? ZColors.dark : ZColors.onDark,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${ops ? 'OPS' : 'RIDER'} · ${_time(at)}',
              style: ZTypography.overline.copyWith(
                color: ops
                    ? ZColors.dark.withValues(alpha: 0.5)
                    : ZColors.onDarkSecondary,
                fontSize: 8,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SHARED LOADING
// ---------------------------------------------------------------------------

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePad,
      children: const [
        AdminSkeleton(height: 70),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: AdminSkeleton(height: 140)),
            SizedBox(width: 12),
            Expanded(child: AdminSkeleton(height: 140)),
            SizedBox(width: 12),
            Expanded(child: AdminSkeleton(height: 140)),
            SizedBox(width: 12),
            Expanded(child: AdminSkeleton(height: 140)),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(flex: 2, child: AdminSkeleton(height: 280)),
            SizedBox(width: 12),
            Expanded(child: AdminSkeleton(height: 280)),
          ],
        ),
      ],
    );
  }
}
