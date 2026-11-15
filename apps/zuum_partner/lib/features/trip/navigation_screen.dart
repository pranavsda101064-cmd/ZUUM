import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../home/partner_gps.dart';

/// Full-screen navigation: MapLibre route, live position, next-turn banner,
/// remaining ETA and basic off-route reroute. Foreground GPS only.
class PartnerNavigationScreen extends ConsumerStatefulWidget {
  const PartnerNavigationScreen({super.key, required this.trip});

  final PartnerTrip trip;

  @override
  ConsumerState<PartnerNavigationScreen> createState() =>
      _PartnerNavigationScreenState();
}

class _PartnerNavigationScreenState
    extends ConsumerState<PartnerNavigationScreen> {
  RouteInfo? _route;
  LocationPoint? _position;
  String? _error;
  bool _loading = true;
  bool _gpsLive = false;
  Timer? _simTimer;
  Timer? _rerouteTimer;
  StreamSubscription<LocationPoint>? _gpsSub;
  double _simProgress = 0;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastLocationSent;
  bool _arrived = false;

  bool get _isPickupLeg =>
      widget.trip.status == PartnerTripStatus.assigned ||
      widget.trip.status == PartnerTripStatus.arrived;

  String get _leg => _isPickupLeg ? 'pickup' : 'drop';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _rerouteTimer?.cancel();
    _gpsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final route = await ref
          .read(partnerApiProvider)
          .tripRoute(widget.trip.bookingId, leg: _leg);
      if (!mounted) return;
      final gps = ref.read(partnerGpsProvider);
      final fix = await gps.current();
      final start = fix ??
          (route.geometry.isNotEmpty
              ? LocationPoint(
                  lat: route.geometry.first.lat,
                  lng: route.geometry.first.lng,
                )
              : null);
      setState(() {
        _route = route;
        _position = start;
        _gpsLive = fix != null;
        _loading = false;
      });
      _startGps(gps);
      if (fix == null) _startSimulation();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load the route.';
        });
      }
    }
  }

  void _startGps(PartnerGps gps) {
    _gpsSub ??= gps.stream().listen(
      (fix) {
        if (!mounted) return;
        _simTimer?.cancel();
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
    if (last != null && now.difference(last).inSeconds < 10) return;
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

  /// Demo movement when GPS is unavailable so the screen is still testable.
  void _startSimulation() {
    final route = _route;
    if (route == null || route.geometry.length < 2) return;
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted || _gpsLive) return;
      _simProgress = math.min(1, _simProgress + 0.01);
      setState(() {
        _position = _pointAlong(route.geometry, _simProgress);
      });
    });
  }

  LocationPoint _pointAlong(List<RoutePoint> points, double t) {
    final exact = (points.length - 1) * t.clamp(0.0, 1.0);
    final index = exact.floor().clamp(0, points.length - 1);
    final next = math.min(index + 1, points.length - 1);
    final frac = exact - index;
    return LocationPoint(
      lat: points[index].lat + (points[next].lat - points[index].lat) * frac,
      lng: points[index].lng + (points[next].lng - points[index].lng) * frac,
    );
  }

  _Progress _progress() {
    final route = _route;
    final position = _position;
    if (route == null || position == null || route.geometry.length < 2) {
      return const _Progress(0, 0, 0, 0, 0);
    }
    final points = route.geometry;
    var bestIndex = 0;
    var bestDistance = double.infinity;
    var bestAlong = 0.0;
    var total = 0.0;
    final meanLat = points.map((p) => p.lat).reduce((a, b) => a + b) /
        points.length;
    final kx = 111320.0 * math.cos(meanLat * math.pi / 180);
    const ky = 110540.0;

    double px = position.lng * kx;
    double py = position.lat * ky;
    for (var i = 0; i < points.length - 1; i++) {
      final ax = points[i].lng * kx;
      final ay = points[i].lat * ky;
      final bx = points[i + 1].lng * kx;
      final by = points[i + 1].lat * ky;
      final length = math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay));
      if (length == 0) continue;
      var t = ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) /
          (length * length);
      t = t.clamp(0.0, 1.0);
      final cx = ax + t * (bx - ax);
      final cy = ay + t * (by - ay);
      final distance = math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
        bestAlong = total + t * length;
      }
      total += length;
    }
    final remaining = math.max(0.0, total - bestAlong);
    final ratio = total > 0 ? remaining / total : 0.0;
    return _Progress(
      bestIndex,
      bestDistance,
      remaining,
      total,
      ratio,
    );
  }

  RouteStep? _nextStep(_Progress progress) {
    final steps = _route?.steps ?? const <RouteStep>[];
    for (final step in steps) {
      if (step.endShapeIndex > progress.index) return step;
    }
    return steps.isEmpty ? null : steps.last;
  }

  String _distanceLabel(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }

  void _maybeReroute(_Progress progress) {
    if (_gpsLive == false) return;
    if (progress.offRouteM < 120) return;
    final now = DateTime.now();
    if (now.difference(_lastReroute).inSeconds < 20) return;
    _lastReroute = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Off route — rerouting…')));
    _load();
  }

  Future<void> _markArrived() async {
    try {
      await ref.read(partnerApiProvider).arrive(widget.trip.bookingId);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  double _bearing() {
    final route = _route;
    final progress = _progress();
    if (route == null || route.geometry.length < 2) return 0;
    final index = progress.index.clamp(0, route.geometry.length - 2);
    final a = route.geometry[index];
    final b = route.geometry[index + 1];
    final dLng = b.lng - a.lng;
    final dLat = b.lat - a.lat;
    final angle = math.atan2(dLng, dLat) * 180 / math.pi;
    return (angle + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final position = _position;
    final progress = _progress();
    final step = _nextStep(progress);

    // Arrival geofence (pickup or drop) + basic off-route reroute.
    if (route != null && progress.remainingM < 80 && !_arrived) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _arrived = true);
      });
    }
    if (route != null && _gpsLive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeReroute(progress));
    }

    final target = _isPickupLeg ? widget.trip.pickup : widget.trip.drop;

    return Scaffold(
      backgroundColor: ZColors.dark,
      body: Stack(
        children: [
          if (route != null && position != null)
            ZMapView(
              center: ZMapCenter(position.lat, position.lng),
              follow: ZMapCenter(position.lat, position.lng),
              tilt: 32,
              bearing: _bearing(),
              initialZoom: 16.5,
              showControls: true,
              route: ZMapRoute(
                [for (final point in route.geometry) ZMapCenter(point.lat, point.lng)],
                color: ZColors.highlight,
              ),
              markers: [
                ZMapMarker(
                  position.lat,
                  position.lng,
                  color: ZColors.highlight,
                  kind: ZMapMarkerKind.driver,
                ),
                ZMapMarker(
                  target.lat,
                  target.lng,
                  color: ZColors.error,
                  kind: ZMapMarkerKind.drop,
                ),
              ],
            )
          else
            Center(
              child: _loading
                  ? const CircularProgressIndicator(color: ZColors.highlight)
                  : ZEmptyState(
                      illustration: 'empty_generic',
                      title: _error ?? 'Navigation unavailable',
                      subtitle: 'Check your connection and try again.',
                      actionLabel: 'Retry',
                      onAction: _load,
                    ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(ZSpacing.md),
              child: Row(
                children: [
                  ZIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'End navigation',
                    background: ZColors.surface,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: ZSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPickupLeg ? 'NAVIGATING TO PICKUP' : 'NAVIGATING TO DROP',
                          style: ZTypography.overline.copyWith(
                            color: ZColors.onDark,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          _gpsLive ? 'GPS live' : 'Demo location',
                          style: ZTypography.overline.copyWith(
                            color: _gpsLive
                                ? ZColors.highlight
                                : ZColors.onDarkSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ZColors.dark,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ZColors.darkOutline),
                    ),
                    child: Text(
                      _arrived
                          ? 'ARRIVED'
                          : '${(progress.ratio * (route?.durationS ?? 0) / 60).round()} min',
                      style: ZTypography.overline.copyWith(
                        color: ZColors.highlight,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (step != null && !_arrived)
            Positioned(
              left: ZSpacing.md,
              right: ZSpacing.md,
              top: MediaQuery.paddingOf(context).top + 64,
              child: ZNavigationBanner(
                maneuverType: step.type,
                instruction: step.instruction,
                distanceLabel: _distanceLabel(
                  route == null
                      ? 0
                      : route.distanceM * 0.08,
                ),
                remainingLabel:
                    '${ZFormat.distance(progress.remainingM.round())} · '
                    '${_distanceLabel(route?.distanceM.toDouble() ?? 0)} route',
              ),
            ),
          Positioned(
            left: ZSpacing.md,
            right: ZSpacing.md,
            bottom: ZSpacing.md,
            child: Container(
              padding: const EdgeInsets.all(ZSpacing.lg),
              decoration: BoxDecoration(
                color: ZColors.surface,
                borderRadius: BorderRadius.circular(ZRadii.lg),
                boxShadow: const [
                  BoxShadow(
                    color: ZColors.shadow,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _arrived
                        ? 'You have arrived'
                        : (_isPickupLeg ? 'Head to pickup' : 'Head to drop'),
                    style: ZTypography.titleMd,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    target.address ?? 'Destination',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        ZTypography.caption.copyWith(color: ZColors.textSecondary),
                  ),
                  const SizedBox(height: ZSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          label: 'Remaining',
                          value: _distanceLabel(progress.remainingM),
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: 'ETA',
                          value:
                              '${((progress.ratio * (route?.durationS ?? 0)) / 60).ceil()} min',
                        ),
                      ),
                      Expanded(
                        child: _Metric(
                          label: 'Route',
                          value: route?.degraded == true ? 'Approx' : 'Live',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZSpacing.md),
                  if (_isPickupLeg && _arrived)
                    ZButton(
                      label: 'Mark arrived at pickup',
                      icon: Icons.place_rounded,
                      expand: true,
                      onPressed: _markArrived,
                    )
                  else
                    ZButton(
                      label: 'End navigation',
                      variant: ZButtonVariant.secondary,
                      icon: Icons.close_rounded,
                      expand: true,
                      onPressed: () => context.pop(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          label.toUpperCase(),
          style: ZTypography.overline.copyWith(color: ZColors.textTertiary),
        ),
        Text(value, style: ZTypography.numeric),
      ],
    );
  }
}

class _Progress {
  const _Progress(
    this.index,
    this.offRouteM,
    this.remainingM,
    this.totalM,
    this.ratio,
  );

  final int index;
  final double offRouteM;
  final double remainingM;
  final double totalM;
  final double ratio;
}
