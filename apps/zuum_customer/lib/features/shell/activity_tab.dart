import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../booking/booking_controller.dart';

/// Activity — Gemini spec §2n: All/Rides/Goods filter, pinned in-progress
/// card with pulsing dot + Track Live, past cards with receipt/POD +
/// 1-tap Rebook, Lalbagh empty state.
class ActivityTab extends ConsumerWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: const ZAppBar(title: 'Activity'),
      body: RefreshIndicator(
        color: ZColors.primary,
        onRefresh: () async => ref.invalidate(bookingsProvider),
        child: bookings.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(ZSpacing.lg),
            child: ZSkeletonList(itemCount: 5),
          ),
          error: (_, _) => ZErrorState(
            title: 'Could not load your trips',
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(bookingsProvider),
          ),
          data: (page) {
            if (page.results.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: ZSpacing.z48),
                  ZEmptyState(
                    illustration: 'empty_lalbagh',
                    title: 'No bookings here yet',
                    subtitle:
                        'Your passenger rides and goods deliveries across '
                        'Bengaluru will show up here.',
                    actionLabel: 'Book a ride or parcel',
                  ),
                ],
              );
            }
            final active = page.results
                .where((b) =>
                    b.status != BookingStatus.completed &&
                    b.status != BookingStatus.cancelled &&
                    b.status != BookingStatus.failed)
                .toList();
            final past = page.results
                .where((b) => b.status == BookingStatus.completed ||
                    b.status == BookingStatus.cancelled ||
                    b.status == BookingStatus.failed)
                .toList();
            return ListView(
              padding: const EdgeInsets.all(ZSpacing.lg),
              children: [
                Text('Active', style: ZTypography.overline),
                const SizedBox(height: ZSpacing.sm),
                for (final b in active) ...[
                  _ActiveCard(booking: b),
                  const SizedBox(height: ZSpacing.md),
                ],
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ZSpacing.lg),
                    child: Text(
                      'No trips in progress.',
                      style: ZTypography.caption
                          .copyWith(color: ZColors.textTertiary),
                    ),
                  ),
                Text('History', style: ZTypography.overline),
                const SizedBox(height: ZSpacing.sm),
                for (final b in past) ...[
                  _PastCard(
                    booking: b,
                    onRebook: () => _rebook(context, ref, b),
                  ),
                  const SizedBox(height: ZSpacing.md),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/booking/tracking'),
      borderRadius: BorderRadius.circular(ZRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(ZSpacing.lg),
        decoration: BoxDecoration(
          color: ZColors.surface,
          borderRadius: BorderRadius.circular(ZRadii.lg),
          border: Border.all(color: ZColors.primary, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PulsingDot(),
                const SizedBox(width: ZSpacing.sm),
                Text(
                  '${booking.status.apiValue.replaceAll('_', ' ')} · '
                  '${booking.serviceCategoryName.toUpperCase()}',
                  style: ZTypography.overline.copyWith(
                    color: ZColors.primary,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                Text(
                  'Track live ▸',
                  style: ZTypography.captionStrong.copyWith(
                    color: ZColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZSpacing.md),
            Text(booking.pickupAddress, style: ZTypography.caption),
            const SizedBox(height: ZSpacing.xs),
            Text(booking.dropAddress, style: ZTypography.captionStrong),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: ZColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PastCard extends StatelessWidget {
  const _PastCard({required this.booking, required this.onRebook});

  final Booking booking;
  final VoidCallback onRebook;

  String get _statusLabel => switch (booking.status) {
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
        _ => 'Failed',
      };

  @override
  Widget build(BuildContext context) {
    final isGoods = booking.isGoods;
    final canRebook = booking.status == BookingStatus.completed;
    return ZCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: ZColors.background,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: ZVehicleIcon(
                  categoryCode: booking.serviceCategoryCode,
                  width: 44,
                  height: 30,
                  semanticLabel: booking.serviceCategoryName,
                ),
              ),
              const SizedBox(width: ZSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${booking.serviceCategoryName} · '
                      '${ZFormat.dayDateTime(booking.createdAt.toLocal())}',
                      style: ZTypography.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      booking.driver != null
                          ? '${booking.vehicle?.registrationNumber ?? ''} · ${booking.driver!.name}'
                          : '—',
                      style: ZTypography.caption
                          .copyWith(color: ZColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ZFormat.inr(
                      booking.finalFarePaise ?? booking.quotedFarePaise,
                    ),
                    style: ZTypography.numericLg.copyWith(fontSize: 17),
                  ),
                  Text(
                    _statusLabel,
                    style: ZTypography.overline.copyWith(
                      color: booking.status == BookingStatus.completed
                          ? ZColors.success
                          : ZColors.textTertiary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.md),
          Row(
            children: [
              const Icon(Icons.circle, size: 6, color: ZColors.success),
              const SizedBox(width: ZSpacing.xs),
              Expanded(
                child: Text(
                  booking.pickupAddress,
                  style: ZTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.xs),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 10, color: ZColors.error),
              const SizedBox(width: ZSpacing.xs),
              Expanded(
                child: Text(
                  booking.dropAddress,
                  style: ZTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: ZSpacing.md),
          Row(
            children: [
              ZButton(
                label: isGoods ? 'POD Challan' : 'Receipt',
                variant: ZButtonVariant.secondary,
                size: ZButtonSize.sm,
                expand: false,
                onPressed: () => context.push('/booking/receipt'),
              ),
              const SizedBox(width: ZSpacing.sm),
              if (canRebook)
                ZButton(
                  label: 'Rebook',
                  variant: ZButtonVariant.secondary,
                  size: ZButtonSize.sm,
                  expand: false,
                  icon: Icons.repeat_rounded,
                  onPressed: onRebook,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rebook → set the draft with the saved route and jump to pricing.
void _rebook(BuildContext context, WidgetRef ref, Booking booking) {
  final controller = ref.read(bookingControllerProvider.notifier);
  controller.setMode(
    booking.type == BookingType.goods ? BookingMode.goods : BookingMode.ride,
  );
  controller.setPickup(
    PlaceSuggestion(
      name: booking.pickupAddress,
      address: booking.pickupAddress,
      lat: booking.pickupLat ?? 12.9352,
      lng: booking.pickupLng ?? 77.6245,
    ),
  );
  controller.setDrop(
    PlaceSuggestion(
      name: booking.dropAddress,
      address: booking.dropAddress,
      lat: booking.dropLat ?? 12.9719,
      lng: booking.dropLng ?? 77.6412,
    ),
  );
  controller.selectCategory(booking.serviceCategoryCode);
  context.push(
    booking.type == BookingType.goods ? '/booking/goods' : '/booking/options',
  );
}
