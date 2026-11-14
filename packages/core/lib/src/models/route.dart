/// Route geometry + turn-by-turn steps shared by both apps.
class RoutePoint {
  const RoutePoint(this.lat, this.lng);
  final double lat;
  final double lng;

  factory RoutePoint.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    return RoutePoint(
      (map['lat'] as num).toDouble(),
      (map['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is RoutePoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

class RouteStep {
  const RouteStep({
    required this.type,
    required this.instruction,
    this.street = '',
    this.distanceM = 0,
    this.durationS = 0,
    this.beginShapeIndex = 0,
    this.endShapeIndex = 0,
  });

  final int type;
  final String instruction;
  final String street;
  final int distanceM;
  final int durationS;
  final int beginShapeIndex;
  final int endShapeIndex;

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
        type: (json['type'] as num?)?.toInt() ?? 0,
        instruction: json['instruction'] as String? ?? 'Continue',
        street: json['street'] as String? ?? '',
        distanceM: (json['distance_m'] as num?)?.toInt() ?? 0,
        durationS: (json['duration_s'] as num?)?.toInt() ?? 0,
        beginShapeIndex: (json['begin_shape_index'] as num?)?.toInt() ?? 0,
        endShapeIndex: (json['end_shape_index'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'instruction': instruction,
        'street': street,
        'distance_m': distanceM,
        'duration_s': durationS,
        'begin_shape_index': beginShapeIndex,
        'end_shape_index': endShapeIndex,
      };
}

class RouteInfo {
  const RouteInfo({
    required this.distanceM,
    required this.durationS,
    required this.geometry,
    this.steps = const [],
    this.provider = 'haversine',
    this.degraded = true,
    this.toll,
    this.leg = 'drop',
  });

  final int distanceM;
  final int durationS;
  final List<RoutePoint> geometry;
  final List<RouteStep> steps;
  final String provider;
  final bool degraded;
  final bool? toll;
  final String leg;

  factory RouteInfo.fromJson(Map<String, dynamic> json) => RouteInfo(
        distanceM: (json['distance_m'] as num?)?.toInt() ?? 0,
        durationS: (json['duration_s'] as num?)?.toInt() ?? 0,
        geometry: (json['geometry'] as List<dynamic>? ?? const [])
            .map(RoutePoint.fromJson)
            .toList(),
        steps: (json['steps'] as List<dynamic>? ?? const [])
            .map((step) => RouteStep.fromJson(step as Map<String, dynamic>))
            .toList(),
        provider: json['provider'] as String? ?? 'haversine',
        degraded: json['degraded'] as bool? ?? true,
        toll: json['toll'] as bool?,
        leg: json['leg'] as String? ?? 'drop',
      );

  Map<String, dynamic> toJson() => {
        'distance_m': distanceM,
        'duration_s': durationS,
        'geometry': [for (final point in geometry) point.toJson()],
        'steps': [for (final step in steps) step.toJson()],
        'provider': provider,
        'degraded': degraded,
        'toll': toll,
        'leg': leg,
      };

  RouteInfo copyWith({
    int? distanceM,
    int? durationS,
    List<RoutePoint>? geometry,
    List<RouteStep>? steps,
    String? provider,
    bool? degraded,
    bool? toll,
    String? leg,
  }) =>
      RouteInfo(
        distanceM: distanceM ?? this.distanceM,
        durationS: durationS ?? this.durationS,
        geometry: geometry ?? this.geometry,
        steps: steps ?? this.steps,
        provider: provider ?? this.provider,
        degraded: degraded ?? this.degraded,
        toll: toll ?? this.toll,
        leg: leg ?? this.leg,
      );
}
