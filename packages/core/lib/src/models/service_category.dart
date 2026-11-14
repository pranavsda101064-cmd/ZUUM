enum ServiceKind { ride, goods }

class ServiceCategory {
  const ServiceCategory({
    required this.code,
    required this.kind,
    required this.name,
    this.description,
    this.capacityKg,
    this.volumeCuft,
    this.seats,
    this.isEnabled = true,
  });

  final String code;
  final ServiceKind kind;
  final String name;
  final String? description;
  final int? capacityKg;
  final double? volumeCuft;
  final int? seats;
  final bool isEnabled;

  factory ServiceCategory.fromJson(Map<String, dynamic> json) => ServiceCategory(
        code: json['code'] as String,
        kind: (json['kind'] as String) == 'goods' ? ServiceKind.goods : ServiceKind.ride,
        name: json['name'] as String? ?? json['code'] as String,
        description: json['description'] as String?,
        capacityKg: (json['capacity_kg'] as num?)?.toInt(),
        volumeCuft: (json['volume_cuft'] as num?)?.toDouble(),
        seats: (json['seats'] as num?)?.toInt(),
        isEnabled: json['is_enabled'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'kind': kind == ServiceKind.goods ? 'goods' : 'ride',
        'name': name,
        'description': description,
        'capacity_kg': capacityKg,
        'volume_cuft': volumeCuft,
        'seats': seats,
        'is_enabled': isEnabled,
      };
}
