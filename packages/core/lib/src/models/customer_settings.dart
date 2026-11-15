/// Customer-owned profile data persisted by the backend.
class GstDetails {
  const GstDetails({this.gstin, this.businessName});

  final String? gstin;
  final String? businessName;

  factory GstDetails.fromJson(Map<String, dynamic> json) => GstDetails(
        gstin: (json['gstin'] as String?)?.trim().isEmpty ?? true
            ? null
            : (json['gstin'] as String).trim(),
        businessName:
            (json['business_name'] as String?)?.trim().isEmpty ?? true
                ? null
                : (json['business_name'] as String).trim(),
      );

  Map<String, dynamic> toJson() => {
        'gstin': gstin ?? '',
        'business_name': businessName ?? '',
      };
}

class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  factory TrustedContact.fromJson(Map<String, dynamic> json) =>
      TrustedContact(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );
}
