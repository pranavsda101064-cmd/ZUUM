import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import 'booking_controller.dart';

/// Vehicle category & fare selection — Gemini spec §2f: top 42% map with
/// route-draw animation + route summary pill, DraggableScrollableSheet with
/// vehicle rows (SVG illustrations), and a sticky 112dp dock (payment +
/// coupon + odometer CTA). Itemised fare breakdown modal.
class CategoryFareScreen extends ConsumerStatefulWidget {
  const CategoryFareScreen({super.key});

  @override
  ConsumerState<CategoryFareScreen> createState() => _CategoryFareScreenState();
}

class _CategoryFareScreenState extends ConsumerState<CategoryFareScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _routeAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..forward();
  bool _booking = false;

  @override
  void dispose() {
    _routeAnim.dispose();
    super.dispose();
  }

  Future<void> _confirm(FareOption option) async {
    final draft = ref.read(bookingControllerProvider);
    if (draft.pickup == null || draft.drop == null) return;
    if (draft.mode == BookingMode.goods &&
        !(draft.goods?.isComplete ?? false)) {
      context.push('/booking/goods');
      return;
    }
    setState(() => _booking = true);
    try {
      final goods = draft.goods;
      final booking = await ref.read(apiContractProvider).createBooking(
            quoteId: option.quote.id,
            serviceCategory: option.category.code,
            pickup: draft.pickupPoint!,
            drop: draft.dropPoint!,
            paymentMethod: draft.paymentMethod,
            scheduledAt: draft.scheduledAt,
            promoCode: draft.promoCode,
            goodsType: goods?.goodsType,
            weightKg: goods?.weightKg,
            dimensionsCuft: goods?.dimensionsCuft,
            needsLoadingHelp: goods?.needsLoadingHelp ?? false,
            senderName: goods?.senderName,
            senderPhone: goods?.senderPhone,
            receiverName: goods?.receiverName,
            receiverPhone: goods?.receiverPhone,
          );
      ref.read(activeBookingProvider.notifier).set(booking);
      ref.invalidate(bookingsProvider);
      if (!mounted) return;
      context.pushReplacement('/booking/tracking');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _booking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create booking. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(bookingControllerProvider);
    final options = ref.watch(fareOptionsProvider);

    if (!draft.hasRoute) {
      return Scaffold(
        backgroundColor: ZColors.surface,
        appBar: const ZAppBar(title: 'Choose a ride', showBack: true),
        body: ZEmptyState(
          title: 'No route selected',
          subtitle: 'Pick a pickup and destination to see fares.',
          actionLabel: 'Set route',
          onAction: () => context.go('/search'),
        ),
      );
    }

    final isGoods = draft.mode == BookingMode.goods;
    final selected = (options.value ?? const <FareOption>[])
        .where((o) => o.category.code == draft.selectedCategoryCode)
        .firstOrNull;

    return Scaffold(
      backgroundColor: ZColors.surface,
      body: Stack(
        children: [
          // Top map viewport (42%).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: AnimatedBuilder(
              animation: _routeAnim,
              builder: (context, _) => ZMapView(
                center: ZMapCenter(
                  draft.pickup!.lat,
                  draft.pickup!.lng,
                ),
                route: ZMapRoute(
                  _mapPoints(
                    pickupLat: draft.pickup!.lat,
                    pickupLng: draft.pickup!.lng,
                    dropLat: draft.drop!.lat,
                    dropLng: draft.drop!.lng,
                    route: selected?.quote.route,
                  ),
                ),
                routeProgress: _routeAnim.value,
                markers: [
                  ZMapMarker(draft.pickup!.lat, draft.pickup!.lng),
                  ZMapMarker(
                    draft.drop!.lat,
                    draft.drop!.lng,
                    color: ZColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Route engine status (degraded fallback is labelled honestly).
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 72,
                  top: ZSpacing.lg,
                ),
                child: ZMapStatusChip(
                  degraded: selected?.quote.route?.degraded ?? true,
                  provider: selected?.quote.route?.provider,
                ),
              ),
            ),
          ),

          // Route summary pill.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(ZSpacing.lg),
              child: Row(
                children: [
                  ZIconButton(
                    icon: Icons.arrow_back_rounded,
                    filled: true,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: ZSpacing.sm),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: ZSpacing.md),
                    decoration: BoxDecoration(
                      color: ZColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ZColors.divider),
                      boxShadow: const [
                        BoxShadow(
                          color: ZColors.shadow,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 8, color: ZColors.primary),
                        const SizedBox(width: ZSpacing.xs),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                          ),
                          child: Text(
                            '${draft.pickup!.name} → ${draft.drop!.name}',
                            style: ZTypography.captionStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selected != null) ...[
                          const SizedBox(width: ZSpacing.xs),
                          Text(
                            '· ${ZFormat.distance(selected.quote.distanceM)}',
                            style: ZTypography.overline.copyWith(
                              color: ZColors.textSecondary,
                              letterSpacing: 0.2,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Draggable sheet (0.58 → 0.88).
          DraggableScrollableSheet(
            initialChildSize: 0.58,
            minChildSize: 0.45,
            maxChildSize: 0.88,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: ZColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(top: BorderSide(color: ZColors.divider)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  ZSpacing.lg,
                  0,
                  ZSpacing.lg,
                  140, // room for the fixed dock
                ),
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(top: ZSpacing.sm),
                      decoration: BoxDecoration(
                        color: ZColors.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: ZSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isGoods ? 'Choose a goods vehicle' : 'Choose a ride',
                          style: ZTypography.titleMd,
                        ),
                      ),
                      const ZBadge(label: 'Upfront fare', tone: ZBadgeTone.neutral),
                    ],
                  ),
                  const SizedBox(height: ZSpacing.sm),
                  _ScheduleRow(draft: draft),
                  const SizedBox(height: ZSpacing.sm),
                  options.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.only(top: ZSpacing.lg),
                      child: ZSkeletonList(itemCount: 4),
                    ),
                    error: (_, _) => ZErrorState(
                      title: 'Could not load fares',
                      message: 'Check your connection and try again.',
                      onRetry: () => ref.invalidate(fareOptionsProvider),
                    ),
                    data: (list) => list.isEmpty
                        ? const ZEmptyState(
                            title: 'No vehicles available',
                            subtitle:
                                'Nothing can serve this route right now. Try another route.',
                          )
                        : Column(
                            children: [
                              for (final option in list) ...[
                                _VehicleRow(
                                  option: option,
                                  selected: option.category.code ==
                                      draft.selectedCategoryCode,
                                  isGoods: isGoods,
                                  onTap: () => ref
                                      .read(bookingControllerProvider.notifier)
                                      .selectCategory(option.category.code),
                                  onFareTap: () => _showBreakdown(option),
                                ),
                                const SizedBox(height: ZSpacing.sm),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Sticky booking dock (112dp).
          Align(
            alignment: Alignment.bottomCenter,
            child: _Dock(
              draft: draft,
              options: options.value ?? const <FareOption>[],
              booking: _booking,
              onPaymentTap: _showPaymentSheet,
              onCouponTap: _showPromoSheet,
              onConfirm: _confirm,
            ),
          ),
        ],
      ),
    );
  }

  void _showBreakdown(FareOption option) {
    final b = option.quote.breakdown;
    final gst = (b.totalPaise * 5) ~/ 100;
    ZSheet.show(
      context: context,
      title: '${option.category.name} · Fare breakdown',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ZFareBreakdown(
            lines: [
              FareLine('Base fare', b.basePaise),
              FareLine(
                'Distance (${ZFormat.distance(option.quote.distanceM)})',
                b.distancePaise,
              ),
              FareLine(
                'Ride time (${ZFormat.duration(option.quote.durationS)})',
                b.timePaise,
              ),
              if (b.surgePaise > 0)
                FareLine('Peak demand', b.surgePaise, highlight: true),
              if (b.tollPaise > 0) FareLine('Tolls & parking', b.tollPaise),
              if (b.waitingPaise > 0) FareLine('Waiting', b.waitingPaise),
              if (b.discountPaise > 0)
                FareLine('Discount', -b.discountPaise, highlight: true),
              FareLine('Platform & GST (5%)', gst),
              FareLine('Total payable', b.totalPaise, isTotal: true),
            ],
          ),
          const SizedBox(height: ZSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZSpacing.md),
            decoration: BoxDecoration(
              color: ZColors.background,
              borderRadius: BorderRadius.circular(ZRadii.sm),
            ),
            child: Text(
              'Excludes tolls paid at plaza. Waiting charge ₹1.50/min after '
              '3 mins at pickup.',
              style: ZTypography.overline.copyWith(
                color: ZColors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: ZSpacing.md),
          Text(
            'ಮೀಟರ್ ಪ್ರಕಾರ ನ್ಯಾಯಯುತ ದರ',
            style: ZTypography.kannada(fontSize: 13, color: ZColors.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZSpacing.lg),
          ZButton(
            label: 'Got it',
            variant: ZButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showPaymentSheet() {
    final current = ref.read(bookingControllerProvider).paymentMethod;
    ZSheet.show<void>(
      context: context,
      title: 'Payment method',
      child: Column(
        children: [
          for (final method in const [
            PaymentMethod.cash,
            PaymentMethod.upi,
            PaymentMethod.wallet,
          ])
            ZListTile(
              title: switch (method) {
                PaymentMethod.cash => 'Cash',
                PaymentMethod.upi => 'UPI',
                PaymentMethod.card => 'Card (on delivery)',
                PaymentMethod.wallet => 'Zuum Wallet',
              },
              leading: Icon(
                switch (method) {
                  PaymentMethod.cash => Icons.payments_outlined,
                  PaymentMethod.upi => Icons.account_balance_outlined,
                  PaymentMethod.card => Icons.credit_card_outlined,
                  PaymentMethod.wallet =>
                    Icons.account_balance_wallet_outlined,
                },
                color: ZColors.textSecondary,
              ),
              trailing: Icon(
                current == method
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: current == method
                    ? ZColors.primary
                    : ZColors.textTertiary,
              ),
              onTap: () {
                ref
                    .read(bookingControllerProvider.notifier)
                    .setPaymentMethod(method);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  void _showPromoSheet() {
    final draft = ref.read(bookingControllerProvider);
    if (draft.promoCode != null) {
      // Already applied → show status with remove option.
      ZSheet.show<void>(
        context: context,
        title: 'Coupon applied',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ZCouponCard(
              code: draft.promoCode!,
              title: 'Applied to this booking',
              actionLabel: 'Remove',
              onAction: () {
                ref.read(bookingControllerProvider.notifier).setPromo(null);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
      return;
    }
    final codeController = TextEditingController();
    var error = '';
    ZSheet.show<void>(
      context: context,
      title: 'Apply coupon',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ZTextField(
              controller: codeController,
              label: 'Coupon code',
              hint: 'e.g. ZUUM50',
              textCapitalization: TextCapitalization.characters,
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: ZSpacing.sm),
              Text(error,
                  style: ZTypography.caption.copyWith(color: ZColors.error)),
            ],
            const SizedBox(height: ZSpacing.xl),
            ZButton(
              label: 'Apply',
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final promo =
                      await ref.read(apiContractProvider).validatePromo(
                            code: code,
                            farePaise: 10000, // min-fare gate; server re-checks
                            serviceCategory: draft.selectedCategoryCode ?? '',
                          );
                  ref
                      .read(bookingControllerProvider.notifier)
                      .setPromo(promo.code);
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  messenger.showSnackBar(
                    SnackBar(content: Text('${promo.code} applied')),
                  );
                } on ApiException catch (e) {
                  setSheetState(() => error = e.message);
                } catch (_) {
                  setSheetState(() => error = 'Could not apply coupon.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow extends ConsumerWidget {
  const _ScheduleRow({required this.draft});

  final BookingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(bookingControllerProvider.notifier);
    final scheduled = draft.scheduledAt;
    return Row(
      children: [
        ZChip(
          label: 'Ride now',
          selected: scheduled == null,
          icon: Icons.bolt_rounded,
          onTap: () => notifier.setSchedule(null),
        ),
        const SizedBox(width: ZSpacing.sm),
        ZChip(
          label: scheduled == null
              ? 'Schedule'
              : ZFormat.shortDateTime(scheduled),
          icon: Icons.schedule_rounded,
          selected: scheduled != null,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(hours: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (date == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: const TimeOfDay(hour: 10, minute: 0),
            );
            if (time == null) return;
            notifier.setSchedule(
              DateTime(date.year, date.month, date.day, time.hour, time.minute),
            );
          },
        ),
      ],
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({
    required this.option,
    required this.selected,
    required this.isGoods,
    required this.onTap,
    required this.onFareTap,
  });

  final FareOption option;
  final bool selected;
  final bool isGoods;
  final VoidCallback onTap;
  final VoidCallback onFareTap;

  @override
  Widget build(BuildContext context) {
    final category = option.category;
    final meta = isGoods
        ? [
            if (category.capacityKg != null) 'Up to ${category.capacityKg} kg',
            if (category.volumeCuft != null) '${category.volumeCuft} cu ft',
          ].join(' · ')
        : '${category.seats ?? 1} seats';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZRadii.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 72,
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpacing.md,
          vertical: ZSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? ZColors.accent : ZColors.surface,
          borderRadius: BorderRadius.circular(ZRadii.md),
          border: Border.all(
            color: selected ? ZColors.primary : ZColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: ZVehicleIcon(
                categoryCode: category.code,
                width: 64,
                height: 42,
                semanticLabel: category.name,
              ),
            ),
            const SizedBox(width: ZSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(category.name, style: ZTypography.bodyStrong),
                      const SizedBox(width: ZSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ZColors.background,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: ZColors.divider),
                        ),
                        child: Text(
                          meta,
                          style: ZTypography.overline.copyWith(
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${ZFormat.duration(option.quote.durationS + 180)} away'
                    ' · Drop ${_dropTime(option.quote.durationS)}',
                    style: ZTypography.caption.copyWith(
                      color: ZColors.textSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onFareTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ZFormat.inr(option.quote.breakdown.totalPaise),
                    style: ZTypography.numericLg.copyWith(fontSize: 17),
                  ),
                  Text(
                    'Fare breakup',
                    style: ZTypography.overline.copyWith(
                      color: ZColors.primary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dropTime(int durationS) {
    final t = DateTime.now().toLocal().add(Duration(seconds: durationS + 180));
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _Dock extends StatelessWidget {
  const _Dock({
    required this.draft,
    required this.options,
    required this.booking,
    required this.onPaymentTap,
    required this.onCouponTap,
    required this.onConfirm,
  });

  final BookingDraft draft;
  final List<FareOption> options;
  final bool booking;
  final VoidCallback onPaymentTap;
  final VoidCallback onCouponTap;
  final ValueChanged<FareOption> onConfirm;

  @override
  Widget build(BuildContext context) {
    final selected = options
        .where((o) => o.category.code == draft.selectedCategoryCode)
        .firstOrNull;
    return Container(
      // 12+32+8+56+12 = 120 — fits the 48dp utility row + 56dp L CTA.
      height: 120,
      padding: const EdgeInsets.fromLTRB(
        ZSpacing.lg,
        ZSpacing.md,
        ZSpacing.lg,
        ZSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: ZColors.surface,
        border: Border(top: BorderSide(color: ZColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onPaymentTap,
                    child: Row(
                      children: [
                        const Icon(Icons.payments_outlined,
                            size: 18, color: ZColors.primary),
                        const SizedBox(width: ZSpacing.xs),
                        Text(
                          switch (draft.paymentMethod) {
                            PaymentMethod.cash => 'Cash',
                            PaymentMethod.upi => 'UPI',
                            PaymentMethod.card => 'Card',
                            PaymentMethod.wallet => 'Wallet',
                          },
                          style: ZTypography.captionStrong,
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: ZColors.textSecondary),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, height: 16, color: ZColors.divider),
                const SizedBox(width: ZSpacing.md),
                Expanded(
                  child: InkWell(
                    onTap: onCouponTap,
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          size: 18,
                          color: draft.promoCode != null
                              ? ZColors.success
                              : ZColors.primary,
                        ),
                        const SizedBox(width: ZSpacing.xs),
                        Expanded(
                          child: Text(
                            draft.promoCode ?? 'Apply coupon',
                            style: ZTypography.captionStrong.copyWith(
                              color: draft.promoCode != null
                                  ? ZColors.success
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZSpacing.sm),
          ZButton(
            label: selected == null
                ? (draft.mode == BookingMode.goods
                    ? 'Select a vehicle'
                    : 'Select a vehicle')
                : '${draft.mode == BookingMode.goods ? 'Book ' : 'Book '}${selected.category.name} · ${ZFormat.inr(selected.quote.breakdown.totalPaise)}',
            loading: booking,
            onPressed: selected == null || booking
                ? null
                : () => onConfirm(selected),
          ),
        ],
      ),
    );
  }
}


List<ZMapCenter> _mapPoints({
  required double pickupLat,
  required double pickupLng,
  required double dropLat,
  required double dropLng,
  RouteInfo? route,
}) {
  if (route != null && route.geometry.length > 1) {
    return [for (final point in route.geometry) ZMapCenter(point.lat, point.lng)];
  }
  return [ZMapCenter(pickupLat, pickupLng), ZMapCenter(dropLat, dropLng)];
}
