import 'route.dart';

class FareBreakdown {
  const FareBreakdown({
    required this.basePaise,
    required this.distancePaise,
    required this.timePaise,
    required this.surgePaise,
    required this.tollPaise,
    required this.waitingPaise,
    required this.discountPaise,
    required this.totalPaise,
  });

  final int basePaise;
  final int distancePaise;
  final int timePaise;
  final int surgePaise;
  final int tollPaise;
  final int waitingPaise;
  final int discountPaise;
  final int totalPaise;

  factory FareBreakdown.fromJson(Map<String, dynamic> json) => FareBreakdown(
        basePaise: (json['base_paise'] as num?)?.toInt() ?? 0,
        distancePaise: (json['distance_paise'] as num?)?.toInt() ?? 0,
        timePaise: (json['time_paise'] as num?)?.toInt() ?? 0,
        surgePaise: (json['surge_paise'] as num?)?.toInt() ?? 0,
        tollPaise: (json['toll_paise'] as num?)?.toInt() ?? 0,
        waitingPaise: (json['waiting_paise'] as num?)?.toInt() ?? 0,
        discountPaise: (json['discount_paise'] as num?)?.toInt() ?? 0,
        totalPaise: (json['total_paise'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'base_paise': basePaise,
        'distance_paise': distancePaise,
        'time_paise': timePaise,
        'surge_paise': surgePaise,
        'toll_paise': tollPaise,
        'waiting_paise': waitingPaise,
        'discount_paise': discountPaise,
        'total_paise': totalPaise,
      };
}

class FareQuote {
  const FareQuote({
    required this.id,
    required this.serviceCategory,
    required this.distanceM,
    required this.durationS,
    required this.breakdown,
    required this.validUntil,
    this.route,
  });

  final String id;
  final String serviceCategory;
  final int distanceM;
  final int durationS;
  final FareBreakdown breakdown;
  final DateTime validUntil;
  final RouteInfo? route;

  factory FareQuote.fromJson(Map<String, dynamic> json) => FareQuote(
        id: json['id'] as String,
        serviceCategory: json['service_category'] as String,
        distanceM: (json['distance_m'] as num).toInt(),
        durationS: (json['duration_s'] as num).toInt(),
        breakdown: FareBreakdown.fromJson(json['breakdown'] as Map<String, dynamic>),
        validUntil: DateTime.parse(json['valid_until'] as String),
        route: json['route'] == null
            ? null
            : RouteInfo.fromJson(json['route'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'service_category': serviceCategory,
        'distance_m': distanceM,
        'duration_s': durationS,
        'breakdown': breakdown.toJson(),
        'valid_until': validUntil.toIso8601String(),
        'route': route?.toJson(),
      };
}
