import 'json_value.dart';

/// Partner vehicle (driver-owned or fleet-assigned).
class PartnerVehicle {
  const PartnerVehicle({
    required this.id,
    required this.categoryCode,
    required this.categoryName,
    required this.registrationNumber,
    required this.make,
    required this.model,
    required this.color,
    this.capacityKg,
    this.volumeCuft,
    this.seats,
    this.isActive = true,
    this.insuranceExpiresAt,
  });

  final String id;
  final String categoryCode;
  final String categoryName;
  final String registrationNumber;
  final String make;
  final String model;
  final String color;
  final int? capacityKg;
  final double? volumeCuft;
  final int? seats;

  /// Availability toggle (spec: per-vehicle availability).
  final bool isActive;
  final DateTime? insuranceExpiresAt;

  bool get insuranceExpiringSoon =>
      insuranceExpiresAt != null &&
      insuranceExpiresAt!.isBefore(DateTime.now().add(const Duration(days: 30)));

  String get displayName => '$make $model'.trim();

  PartnerVehicle copyWith({bool? isActive}) => PartnerVehicle(
        id: id,
        categoryCode: categoryCode,
        categoryName: categoryName,
        registrationNumber: registrationNumber,
        make: make,
        model: model,
        color: color,
        capacityKg: capacityKg,
        volumeCuft: volumeCuft,
        seats: seats,
        isActive: isActive ?? this.isActive,
        insuranceExpiresAt: insuranceExpiresAt,
      );

  factory PartnerVehicle.fromJson(Map<String, dynamic> json) => PartnerVehicle(
        id: json['id'] as String,
        categoryCode: json['category_code'] as String? ?? '',
        categoryName: json['category_name'] as String? ?? '',
        registrationNumber: json['registration_number'] as String? ?? '',
        make: json['make'] as String? ?? '',
        model: json['model'] as String? ?? '',
        color: json['color'] as String? ?? '',
        capacityKg: (json['capacity_kg'] as num?)?.toInt(),
        volumeCuft: jsonDouble(json['volume_cuft']),
        seats: (json['seats'] as num?)?.toInt(),
        isActive: json['is_active'] as bool? ?? true,
        insuranceExpiresAt: json['insurance_expires_at'] == null
            ? null
            : DateTime.tryParse(json['insurance_expires_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'category_code': categoryCode,
        'category_name': categoryName,
        'registration_number': registrationNumber,
        'make': make,
        'model': model,
        'color': color,
        'capacity_kg': capacityKg,
        'volume_cuft': volumeCuft,
        'seats': seats,
        'is_active': isActive,
        'insurance_expires_at': insuranceExpiresAt?.toIso8601String(),
      };
}
