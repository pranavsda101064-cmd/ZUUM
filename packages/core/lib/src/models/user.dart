enum UserRole { customer, driver, fleetOwner, staff }

class ZUser {
  const ZUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.phoneVerified,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final bool phoneVerified;
  final UserRole role;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final both = '$f$l';
    return both.isEmpty ? (email.isNotEmpty ? email[0].toUpperCase() : '?') : both.toUpperCase();
  }

  ZUser copyWith({String? firstName, String? lastName, String? phone}) {
    return ZUser(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      phoneVerified: phoneVerified,
      role: role,
      createdAt: createdAt,
    );
  }

  factory ZUser.fromJson(Map<String, dynamic> json) => ZUser(
        id: json['id'] as String,
        email: json['email'] as String,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        phone: json['phone'] as String?,
        phoneVerified: json['phone_verified'] as bool? ?? false,
        role: UserRole.values.asNameMap()[json['role'] as String? ?? 'customer'] ??
            UserRole.customer,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'phone_verified': phoneVerified,
        'role': role.name,
        'created_at': createdAt.toIso8601String(),
      };
}
