import 'dart:math' as math;

import '../../models/models.dart';

/// Deterministic, Bengaluru-looking curved geometry for the mock build.
/// Mirrors the shape of the real Valhalla response so screens built against
/// mock data keep working when the backend is switched on.
RouteInfo mockCurvedRoute(
  LocationPoint pickup,
  LocationPoint drop, {
  double roadFactor = 1.18,
}) {
  final straight = _haversineM(pickup.lat, pickup.lng, drop.lat, drop.lng);
  final distanceM = (straight * roadFactor).round();

  final dx = drop.lng - pickup.lng;
  final dy = drop.lat - pickup.lat;
  final midLat = (pickup.lat + drop.lat) / 2;
  final midLng = (pickup.lng + drop.lng) / 2;
  final curve = 0.18;
  final control = RoutePoint(
    midLat + dx * curve,
    midLng - dy * curve,
  );

  const samples = 22;
  final points = <RoutePoint>[];
  for (var i = 0; i <= samples; i++) {
    final t = i / samples;
    final oneMinus = 1 - t;
    points.add(
      RoutePoint(
        oneMinus * oneMinus * pickup.lat +
            2 * oneMinus * t * control.lat +
            t * t * drop.lat,
        oneMinus * oneMinus * pickup.lng +
            2 * oneMinus * t * control.lng +
            t * t * drop.lng,
      ),
    );
  }

  final durationS = (distanceM / 22 * 3.6).round().clamp(120, 7200);
  final third = (points.length - 1) ~/ 3;
  final steps = [
    RouteStep(
      type: 1,
      instruction: 'Head towards ${pickup.address ?? 'the pickup point'}',
      street: '',
      distanceM: (distanceM * 0.15).round(),
      durationS: (durationS * 0.15).round(),
      beginShapeIndex: 0,
      endShapeIndex: third,
    ),
    RouteStep(
      type: 9,
      instruction: 'Turn onto the main road',
      street: '80 Feet Road',
      distanceM: (distanceM * 0.45).round(),
      durationS: (durationS * 0.45).round(),
      beginShapeIndex: third,
      endShapeIndex: third * 2,
    ),
    RouteStep(
      type: 15,
      instruction: 'Keep left at the junction',
      street: 'Inner Ring Road',
      distanceM: (distanceM * 0.3).round(),
      durationS: (durationS * 0.3).round(),
      beginShapeIndex: third * 2,
      endShapeIndex: points.length - 2,
    ),
    RouteStep(
      type: 4,
      instruction: 'Arrive at ${drop.address ?? 'the destination'}',
      street: '',
      distanceM: (distanceM * 0.1).round(),
      durationS: durationS - (durationS * 0.9).round(),
      beginShapeIndex: points.length - 2,
      endShapeIndex: points.length - 1,
    ),
  ];

  return RouteInfo(
    distanceM: distanceM,
    durationS: durationS,
    geometry: points,
    steps: steps,
    provider: 'mock-valhalla',
    degraded: false,
  );
}

double _haversineM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(h));
}
