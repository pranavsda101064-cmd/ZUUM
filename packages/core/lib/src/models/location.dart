class LocationPoint {
  const LocationPoint({required this.lat, required this.lng, this.address});

  final double lat;
  final double lng;
  final String? address;

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        address: json['address'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'lat': lat, 'lng': lng, if (address != null) 'address': address};
}

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.name,
    required this.lat,
    required this.lng,
    required this.address,
    this.isDefault = false,
  });

  final String id;
  final String label; // home | work | other
  final String name;
  final double lat;
  final double lng;
  final String address;
  final bool isDefault;

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'other',
        name: json['name'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        address: json['address'] as String? ?? '',
        isDefault: json['is_default'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'name': name,
        'lat': lat,
        'lng': lng,
        'address': address,
        'is_default': isDefault,
      };
}
