class FleetOverview {
  const FleetOverview({
    required this.driversActive,
    required this.driversTotal,
    required this.vehiclesActive,
    required this.vehiclesTotal,
    required this.earningsTodayPaise,
    required this.utilisation,
  });

  final int driversActive;
  final int driversTotal;
  final int vehiclesActive;
  final int vehiclesTotal;
  final int earningsTodayPaise;

  /// 0..1 share of online drivers actively on trips.
  final double utilisation;

  factory FleetOverview.fromJson(Map<String, dynamic> json) => FleetOverview(
        driversActive: (json['drivers_active'] as num?)?.toInt() ?? 0,
        driversTotal: (json['drivers_total'] as num?)?.toInt() ?? 0,
        vehiclesActive: (json['vehicles_active'] as num?)?.toInt() ?? 0,
        vehiclesTotal: (json['vehicles_total'] as num?)?.toInt() ?? 0,
        earningsTodayPaise:
            (json['earnings_today_paise'] as num?)?.toInt() ?? 0,
        utilisation: (json['utilisation'] as num?)?.toDouble() ?? 0,
      );
}

class FleetDriver {
  const FleetDriver({
    required this.id,
    required this.name,
    required this.phoneMasked,
    required this.online,
    required this.ratingAvg,
    required this.tripsToday,
    required this.earningsTodayPaise,
    this.vehicleRegistration,
    this.isVerified = true,
  });

  final String id;
  final String name;
  final String phoneMasked;
  final bool online;
  final double ratingAvg;
  final int tripsToday;
  final int earningsTodayPaise;
  final String? vehicleRegistration;
  final bool isVerified;

  factory FleetDriver.fromJson(Map<String, dynamic> json) => FleetDriver(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phoneMasked: json['phone_masked'] as String? ?? '',
        online: json['online'] as bool? ?? false,
        ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
        tripsToday: (json['trips_today'] as num?)?.toInt() ?? 0,
        earningsTodayPaise:
            (json['earnings_today_paise'] as num?)?.toInt() ?? 0,
        vehicleRegistration: json['vehicle_registration'] as String?,
        isVerified: json['is_verified'] as bool? ?? true,
      );
}
