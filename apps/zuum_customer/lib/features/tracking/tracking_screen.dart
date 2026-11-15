import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../booking/booking_controller.dart';
import 'trip_controller.dart';

/// Live trip — Gemini spec §2g: top 55% map (radar pulse while matching,
/// driver marker glide), dark signboard status header with PIN/ETA pill,
/// captain identity row with rating pill + licence-plate badge, action bar,
/// route timeline, and a ghost cancel footer.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  Timer? _etaTicker;
  int _etaRemaining = 0;
  int _waitRemaining = 0;
  bool _arrived = false;
  bool _cancelling = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final booking = ref.read(activeBookingProvider);
      final trip = ref.read(tripControllerProvider);
      if (booking != null && trip == null) {
        ref.read(tripControllerProvider.notifier).start(booking);
      }
    });
  }

  @override
  void dispose() {
    _etaTicker?.cancel();
    super.dispose();
  }

  void _startEtaCountdown(int seconds) {
    _etaTicker?.cancel();
    setState(() {
      _etaRemaining = seconds;
      _arrived = false;
      _waitRemaining = 0;
    });
    _etaTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _etaRemaining = (_etaRemaining - 1).clamp(0, 1 << 31);
        if (_etaRemaining == 0) {
          t.cancel();
          // Spec §2g State 3 — free wait window once the captain is at pickup.
          _arrived = true;
          _waitRemaining = 165; // 02:45
          _etaTicker = Timer.periodic(const Duration(seconds: 1), (wt) {
            if (!mounted) return;
            setState(() {
              _waitRemaining = (_waitRemaining - 1).clamp(0, 1 << 31);
              if (_waitRemaining == 0) wt.cancel();
            });
          });
        }
      });
    });
  }

  void _handleCompleted(TripState next) {
    if (!mounted) return;
    if (next.booking.isGoods) {
      context.pushReplacement('/booking/pod');
    } else {
      context.pushReplacement('/booking/payment');
    }
  }

  Future<void> _cancel(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(
          booking.status == BookingStatus.searching
              ? 'Your driver search will stop.'
              : 'Your captain is on the way. Cancellation charges may apply.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep booking'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Cancel booking',
              style: ZTypography.bodyStrong.copyWith(color: ZColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(apiContractProvider).cancelBooking(
            booking.id,
            reason: 'cancelled by customer',
          );
      ref.read(tripControllerProvider.notifier).abort();
      ref.invalidate(bookingsProvider);
      if (!mounted) return;
      context.go('/home');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel. Try again.')),
      );
    }
  }

  void _sos(Booking booking) {
    ZSheet.show<void>(
      context: context,
      title: 'Emergency',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Zuum Safety is here. Reach the helplines below or alert us instantly.',
            style: ZTypography.body.copyWith(color: ZColors.textSecondary),
          ),
          const SizedBox(height: ZSpacing.lg),
          const _HelplineRow(number: '112', label: 'Emergency Response (all India)'),
          const _HelplineRow(number: '100', label: 'Police'),
          const _HelplineRow(number: '108', label: 'Ambulance'),
          const _HelplineRow(number: '1091', label: 'Women’s helpline'),
          const SizedBox(height: ZSpacing.lg),
          ZButton(
            label: 'Send SOS to Zuum Safety',
            variant: ZButtonVariant.danger,
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(apiContractProvider).sendSos(bookingId: booking.id);
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('SOS sent. Our safety team is alerted.'),
                  ),
                );
              } catch (_) {
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Could not send SOS. Call 112.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _shareTrip(Booking booking) {
    SharePlus.instance.share(
      ShareParams(
        text: 'Track my Zuum trip: ${booking.serviceCategoryName} '
            'from ${booking.pickupAddress} to ${booking.dropAddress} '
            '(booking ${booking.id})',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripControllerProvider);

    ref.listen(tripControllerProvider, (previous, next) {
      if (next == null || _navigated) return;
      if (next.etaSeconds != null &&
          next.status == BookingStatus.driverArriving) {
        _startEtaCountdown(next.etaSeconds!);
      }
      if (next.status == BookingStatus.completed) {
        _navigated = true;
        _etaTicker?.cancel();
        Future.microtask(() => _handleCompleted(next));
      }
    });

    if (trip == null) {
      return Scaffold(
        backgroundColor: ZColors.background,
        appBar: const ZAppBar(title: 'Trip'),
        body: ZEmptyState(
          title: 'No active trip',
          subtitle: 'Your active ride will appear here.',
          actionLabel: 'Back to home',
          onAction: () => context.go('/home'),
        ),
      );
    }

    final booking = trip.booking;
    final status = trip.status;
    final isGoods = booking.isGoods;
    final searching = status == BookingStatus.searching;

    return Scaffold(
      body: Stack(
        children: [
          // Top 55% — live map.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: ZMapView(
              center: ZMapCenter(
                booking.pickupLat ?? 12.9352,
                booking.pickupLng ?? 77.6245,
              ),
              route: ZMapRoute(
                booking.route != null && booking.route!.geometry.length > 1
                    ? [
                        for (final point in booking.route!.geometry)
                          ZMapCenter(point.lat, point.lng),
                      ]
                    : [
                        ZMapCenter(
                          booking.pickupLat ?? 12.9352,
                          booking.pickupLng ?? 77.6245,
                        ),
                        ZMapCenter(
                          booking.dropLat ?? 12.9719,
                          booking.dropLng ?? 77.6412,
                        ),
                      ],
              ),
              markers: [
                ZMapMarker(
                  booking.pickupLat ?? 12.9352,
                  booking.pickupLng ?? 77.6245,
                ),
                ZMapMarker(
                  booking.dropLat ?? 12.9719,
                  booking.dropLng ?? 77.6412,
                  color: ZColors.textSecondary,
                ),
                if (trip.location != null)
                  ZMapMarker(
                    trip.location!.lat,
                    trip.location!.lng,
                    color: ZColors.primary,
                  ),
              ],
              follow: trip.location == null
                  ? null
                  : ZMapCenter(trip.location!.lat, trip.location!.lng),
            ),
          ),

          // Radar pulse while matching (spec §4.4).
          if (searching)
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.55 / 2 - 80,
              left: MediaQuery.sizeOf(context).width / 2 - 80,
              child: const IgnorePointer(child: ZRadarPulse(size: 160)),
            ),

          // Top bar: back + safety pill.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(ZSpacing.lg),
              child: Row(
                children: [
                  ZIconButton(
                    icon: Icons.arrow_back_rounded,
                    filled: true,
                    onPressed: () => context.go('/home'),
                  ),
                  const Spacer(),
                  ZIconButton(
                    icon: Icons.shield_outlined,
                    filled: true,
                    foreground: ZColors.error,
                    tooltip: 'Safety',
                    onPressed: () => _sos(booking),
                  ),
                ],
              ),
            ),
          ),

          // Bottom sheet.
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.52,
              ),
              decoration: const BoxDecoration(
                color: ZColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(top: BorderSide(color: ZColors.divider)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(ZSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Dark signboard status header.
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZSpacing.lg,
                      ),
                      decoration: const BoxDecoration(
                        color: ZColors.dark,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _statusLine(trip, isGoods),
                              style: ZTypography.bodyStrong.copyWith(
                                color: ZColors.onDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isGoods &&
                              trip.otp != null &&
                              (status == BookingStatus.assigned ||
                                  status == BookingStatus.driverArriving) &&
                              !_arrived)
                            ZPinPill(pin: trip.otp!)
                          else if (_arrived &&
                              status == BookingStatus.driverArriving)
                            Container(
                              height: 28,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: ZColors.successTint,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  _waitRemaining > 0
                                      ? 'Wait ${_mmss(_waitRemaining)}'
                                      : 'Trip started ✓',
                                  style: ZTypography.captionStrong.copyWith(
                                    color: ZColors.success,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else if (status == BookingStatus.driverArriving &&
                              _etaRemaining > 0)
                            Container(
                              height: 28,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: ZColors.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'ETA ${ZFormat.duration(_etaRemaining)}',
                                  style: ZTypography.numeric.copyWith(
                                    fontSize: 13,
                                    color: ZColors.dark,
                                  ),
                                ),
                              ),
                            )
                          else if (status == BookingStatus.inProgress)
                            Container(
                              height: 28,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: ZColors.successTint,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'On trip',
                                  style: ZTypography.captionStrong
                                      .copyWith(color: ZColors.success),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ZSpacing.lg),

                    // Captain identity row.
                    if (trip.driver != null && trip.vehicle != null) ...[
                      Row(
                        children: [
                          ZAvatar(
                            initials: trip.driver!.name.isEmpty
                                ? 'D'
                                : trip.driver!.name.substring(0, 1),
                            imageUrl: trip.driver!.photoUrl,
                            size: 48,
                          ),
                          const SizedBox(width: ZSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        trip.driver!.name,
                                        style: ZTypography.titleMd,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: ZSpacing.xs),
                                    ZRatingStars(
                                      rating: trip.driver!.ratingAvg,
                                      size: 14,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${trip.vehicle!.make} · Kannada, English',
                                  style: ZTypography.caption.copyWith(
                                    color: ZColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          ZPlateBadge(plate: trip.vehicle!.registrationNumber),
                        ],
                      ),
                      const SizedBox(height: ZSpacing.lg),

                      // Action bar: message (SMS), call, share.
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  _launch('sms:${trip.driver!.phone}'),
                              borderRadius:
                                  BorderRadius.circular(ZRadii.md),
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: ZSpacing.md,
                                ),
                                decoration: BoxDecoration(
                                  color: ZColors.background,
                                  borderRadius:
                                      BorderRadius.circular(ZRadii.md),
                                  border:
                                      Border.all(color: ZColors.divider),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.chat_bubble_outline_rounded,
                                        size: 18, color: ZColors.textSecondary),
                                    const SizedBox(width: ZSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        'Message ${trip.driver!.name.split(' ').first}...',
                                        style: ZTypography.caption.copyWith(
                                          color: ZColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: ZSpacing.sm),
                          ZIconButton(
                            icon: Icons.call_rounded,
                            background: ZColors.primary,
                            foreground: ZColors.onPrimary,
                            onPressed: () =>
                                _launch('tel:${trip.driver!.phone}'),
                            tooltip: 'Call captain',
                          ),
                          const SizedBox(width: ZSpacing.sm),
                          ZIconButton(
                            icon: Icons.share_outlined,
                            filled: true,
                            onPressed: () => _shareTrip(booking),
                            tooltip: 'Share trip',
                          ),
                        ],
                      ),
                      const SizedBox(height: ZSpacing.lg),
                      const Divider(height: 1),
                      const SizedBox(height: ZSpacing.lg),
                    ],

                    // Route timeline.
                    ZRouteTimeline(
                      pickup: booking.pickupAddress,
                      drop: booking.dropAddress,
                      trailing: Text(
                        '${ZFormat.inr(booking.quotedFarePaise)} · '
                        '${switch (booking.paymentMethod) {
                          PaymentMethod.cash => 'Cash',
                          PaymentMethod.upi => 'UPI',
                          PaymentMethod.card => 'Card',
                          PaymentMethod.wallet => 'Wallet',
                        }}',
                        style: ZTypography.numeric.copyWith(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: ZSpacing.lg),

                    // Ghost cancel footer.
                    TextButton(
                      onPressed: _cancelling ? null : () => _cancel(booking),
                      child: _cancelling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Cancel booking',
                              style: ZTypography.bodyStrong
                                  .copyWith(color: ZColors.error),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  String _statusLine(TripState trip, bool isGoods) {
    return switch (trip.status) {
      BookingStatus.searching =>
        isGoods ? 'Finding a ${trip.booking.serviceCategoryName}…' : 'Finding your captain...',
      BookingStatus.assigned => isGoods
          ? 'Captain assigned · heading to pickup'
          : 'Captain assigned · heading to you',
      BookingStatus.driverArriving => _arrived
          ? 'Captain has arrived at pickup'
          : _etaRemaining > 0
              ? 'Arriving in ${_mmss(_etaRemaining)}'
              : 'Arriving now',
      BookingStatus.inProgress =>
        isGoods ? 'In transit' : 'Heading to ${trip.booking.dropAddress}',
      BookingStatus.completed => 'Completed',
      _ => '',
    };
  }

  Future<void> _launch(String uri) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null) return;
    try {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No dialler available; the number is visible on screen.
    }
  }
}

class _HelplineRow extends StatelessWidget {
  const _HelplineRow({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ZListTile(
      title: number,
      subtitle: label,
      leading: const Icon(Icons.call_outlined, color: ZColors.error),
      showChevron: false,
      onTap: () => _launch('tel:$number'),
    );
  }
}

Future<void> _launch(String uri) async {
  final parsed = Uri.tryParse(uri);
  if (parsed == null) return;
  try {
    await launchUrl(parsed, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No dialler available; the number is visible on screen.
  }
}
