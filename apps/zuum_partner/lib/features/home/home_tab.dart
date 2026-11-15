import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';
import 'home_controllers.dart';
import 'offer_sheet.dart';
import 'partner_gps.dart';

/// Driver dashboard: online hero, simulated live map, earnings snapshot,
/// active-trip card and the incoming-offer sheet driven by the realtime
/// simulator.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  static const _base = LocationPoint(
    lat: 12.9352,
    lng: 77.6245,
    address: 'Koramangala, Bengaluru',
  );

  bool _toggling = false;
  bool _sheetOpen = false;
  StreamSubscription<DriverOffer>? _offerSub;
  StreamSubscription<LocationPoint>? _gpsSub;
  Timer? _presenceTimer;
  var _tick = 0;
  bool _gpsLive = false;
  DateTime? _lastLocationSent;
  LocationPoint _position = _base;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(onlineStatusProvider.notifier).hydrate();
      _offerSub = ref.read(driverRealtimeProvider).offers().listen(_onOffer);
      _startGps();
    });
    // Fallback: gentle drift while online until a real GPS fix arrives.
    _presenceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _gpsLive || !ref.read(onlineStatusProvider)) return;
      setState(() {
        _tick++;
        _position = LocationPoint(
          lat: _base.lat + 0.0008 * math.sin(_tick / 2),
          lng: _base.lng + 0.0008 * math.cos(_tick / 2),
          address: _base.address,
        );
      });
    });
  }

  Future<void> _startGps() async {
    final gps = ref.read(partnerGpsProvider);
    final fix = await gps.current();
    if (!mounted) return;
    if (fix != null) {
      setState(() {
        _position = fix;
        _gpsLive = true;
      });
      _pushLocation(fix);
    }
    _gpsSub ??= gps.stream().listen(
      (fix) {
        if (!mounted) return;
        setState(() {
          _position = fix;
          _gpsLive = true;
        });
        _pushLocation(fix);
      },
      onError: (_) {},
    );
  }

  void _pushLocation(LocationPoint fix) {
    final now = DateTime.now();
    final last = _lastLocationSent;
    if (last != null && now.difference(last).inSeconds < 15) return;
    if (!ref.read(onlineStatusProvider)) return;
    _lastLocationSent = now;
    ref
        .read(partnerApiProvider)
        .updateLocation(
          lat: fix.lat,
          lng: fix.lng,
          recordedAt: now.toUtc(),
        )
        .catchError((_) {});
  }

  @override
  void dispose() {
    _offerSub?.cancel();
    _gpsSub?.cancel();
    _presenceTimer?.cancel();
    super.dispose();
  }

  void _onOffer(DriverOffer offer) {
    if (!mounted || _sheetOpen) return; // one offer at a time
    _openOfferSheet(offer);
  }

  Future<void> _openOfferSheet(DriverOffer offer) async {
    _sheetOpen = true;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ZColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadii.xl)),
      ),
      builder: (_) => OfferSheet(offer: offer),
    );
    _sheetOpen = false;
    if (accepted == true && mounted) {
      ref.invalidate(activeTripProvider);
      ref.invalidate(todayEarningsProvider);
    }
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _toggling = true);
    try {
      await ref.read(onlineStatusProvider.notifier).setOnline(value);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update availability.')),
        );
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  void _simulateOffer() {
    final api = ref.read(partnerApiProvider);
    if (api is! MockPartnerApi) return;
    try {
      _onOffer(api.createSimulatedOffer());
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(partnerAuthProvider).profile;
    final online = ref.watch(onlineStatusProvider);
    final earnings = ref.watch(todayEarningsProvider);
    final acceptance = ref.watch(acceptanceProvider);
    final activeTrip = ref.watch(activeTripProvider).value;

    return Scaffold(
      backgroundColor: ZColors.background,
      appBar: ZAppBar(
        title: 'Partner',
        subtitle: profile?.fullName,
        actions: [
          ZIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'Sign out',
            onPressed: () => ref.read(partnerAuthProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: ZColors.primary,
        onRefresh: () async {
          ref.invalidate(todayEarningsProvider);
          ref.invalidate(activeTripProvider);
          ref.invalidate(acceptanceProvider);
          await ref.read(onlineStatusProvider.notifier).hydrate();
        },
        child: ListView(
          padding: const EdgeInsets.all(ZSpacing.lg),
          children: [
            ZEntrance(
              index: 0,
              child: ZOnlineHero(
                online: online,
                busy: _toggling,
                onChanged: _toggleOnline,
                earningsLabel: earnings.value == null
                    ? null
                    : '${ZFormat.inr(earnings.value!.netPaise)} today',
                subtitle: online
                    ? 'You are visible to riders nearby'
                    : 'Go online to start earning',
              ),
            ),
            const SizedBox(height: ZSpacing.lg),
            ZEntrance(
              index: 1,
              child: _MapCard(position: _position, online: online, gpsLive: _gpsLive),
            ),
            const SizedBox(height: ZSpacing.lg),
            ZEntrance(
              index: 2,
              child: Row(
                children: [
                  Expanded(
                    child: earnings.value == null
                        ? const _StatSkeleton()
                        : ZStatCard(
                            label: 'Net today',
                            value: ZFormat.inr(earnings.value!.netPaise),
                            valueWidget: ZAnimatedCounter(
                              value: earnings.value!.netPaise,
                              format: (value) => ZFormat.inr(value.toInt()),
                              style: ZTypography.numericLg.copyWith(fontSize: 20),
                            ),
                            caption: '${earnings.value!.trips} trips',
                            icon: Icons.account_balance_wallet_outlined,
                            accent: true,
                          ),
                  ),
                  const SizedBox(width: ZSpacing.sm),
                  Expanded(
                    child: acceptance.value == null
                        ? const _StatSkeleton()
                        : ZStatCard(
                            label: 'Acceptance',
                            value:
                                '${acceptance.value!.toStringAsFixed(0)}%',
                            valueWidget: ZAnimatedCounter(
                              value: acceptance.value!.round(),
                              format: (value) => '$value%',
                              style: ZTypography.numericLg.copyWith(fontSize: 20),
                            ),
                            caption: 'Last 30 days',
                            icon: Icons.thumb_up_alt_outlined,
                          ),
                  ),
                ],
              ),
            ),
            if (activeTrip != null) ...[
              const SizedBox(height: ZSpacing.lg),
              ZEntrance(index: 3, child: _ActiveTripCard(trip: activeTrip)),
            ],
            const SizedBox(height: ZSpacing.lg),
            if (AppEnv.isMock)
              ZEntrance(
                index: 4,
                child: ZButton(
                  label: 'Simulate offer (dev)',
                  variant: ZButtonVariant.secondary,
                  icon: Icons.bolt_rounded,
                  onPressed: _simulateOffer,
                ),
              ),
            if (!online) ...[
              const SizedBox(height: ZSpacing.md),
              Text(
                'Offers arrive once you go online. Keep the app open while '
                'you are available.',
                style: ZTypography.caption
                    .copyWith(color: ZColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Placeholder with the same geometry as [ZStatCard] while earnings load.
class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZSpacing.lg),
      decoration: BoxDecoration(
        color: ZColors.surface,
        borderRadius: BorderRadius.circular(ZRadii.md),
        border: Border.all(color: ZColors.divider),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZSkeleton(width: 72, height: 10),
          SizedBox(height: ZSpacing.md),
          ZSkeleton(width: 96, height: 22),
          SizedBox(height: ZSpacing.sm),
          ZSkeleton(width: 54, height: 10),
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.position,
    required this.online,
    this.gpsLive = false,
  });

  final LocationPoint position;
  final bool online;
  final bool gpsLive;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(ZRadii.lg),
      child: SizedBox(
        height: 200,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ZMapView(
              center: ZMapCenter(position.lat, position.lng),
              follow: ZMapCenter(position.lat, position.lng),
              interactive: false,
              showAttribution: false,
              markers: [
                ZMapMarker(
                  position.lat,
                  position.lng,
                  color: online ? ZColors.highlight : ZColors.textTertiary,
                ),
              ],
            ),
            Positioned(
              left: ZSpacing.sm,
              top: ZSpacing.sm,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ZColors.surface.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ZColors.divider),
                ),
                child: Text(
                  gpsLive ? 'GPS · Bengaluru' : 'SIM GPS · Koramangala',
                  style: ZTypography.overline.copyWith(letterSpacing: 0.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.trip});

  final PartnerTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              const ZLiveDot(color: ZColors.highlight),
              const SizedBox(width: ZSpacing.sm),
              Text(
                'ACTIVE TRIP · ${trip.serviceCategoryName.toUpperCase()}',
                style: ZTypography.overline.copyWith(
                  color: ZColors.primary,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              ZBadge(label: trip.status.name),
            ],
          ),
          const SizedBox(height: ZSpacing.md),
          ZRouteTimeline(
            pickup: trip.pickup.address ?? 'Pickup',
            drop: trip.drop.address ?? 'Drop',
            trailing: Text(
              ZFormat.inr(trip.earningPaise),
              style: ZTypography.numeric.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(height: ZSpacing.lg),
          ZButton(
            label: 'Open trip',
            onPressed: () => context.push('/trip'),
          ),
        ],
      ),
    );
  }
}
