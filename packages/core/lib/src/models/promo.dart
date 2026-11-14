enum PromoType { percent, flat }

class PromoCampaign {
  const PromoCampaign({
    required this.code,
    required this.title,
    required this.description,
    required this.type,
    required this.value,
    required this.maxDiscountPaise,
    required this.minFarePaise,
    this.validUntil,
  });

  final String code;
  final String title;
  final String description;
  final PromoType type;

  /// Percent (0-100) or flat paise, depending on [type].
  final int value;
  final int maxDiscountPaise;
  final int minFarePaise;
  final DateTime? validUntil;

  int discountFor(int farePaise) {
    if (farePaise < minFarePaise) return 0;
    final raw = type == PromoType.percent
        ? (farePaise * value) ~/ 100
        : value;
    return raw.clamp(0, maxDiscountPaise);
  }

  factory PromoCampaign.fromJson(Map<String, dynamic> json) => PromoCampaign(
        code: json['code'] as String,
        title: json['title'] as String? ?? json['code'] as String,
        description: json['description'] as String? ?? '',
        type: (json['type'] as String?) == 'flat' ? PromoType.flat : PromoType.percent,
        value: (json['value'] as num?)?.toInt() ?? 0,
        maxDiscountPaise: (json['max_discount_paise'] as num?)?.toInt() ?? 0,
        minFarePaise: (json['min_fare_paise'] as num?)?.toInt() ?? 0,
        validUntil: json['valid_until'] == null
            ? null
            : DateTime.tryParse(json['valid_until'] as String),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'title': title,
        'description': description,
        'type': type == PromoType.flat ? 'flat' : 'percent',
        'value': value,
        'max_discount_paise': maxDiscountPaise,
        'min_fare_paise': minFarePaise,
        'valid_until': validUntil?.toIso8601String(),
      };
}
