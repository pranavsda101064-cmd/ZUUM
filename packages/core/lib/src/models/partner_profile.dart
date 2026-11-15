import 'json_value.dart';

enum KycStatus { draft, submitted, approved, rejected }

enum ApprovalStatus { pending, active, suspended }

enum KycDocType { licence, rc, insurance, puc, profilePhoto, vehiclePhoto }

class KycDocumentInfo {
  const KycDocumentInfo({
    required this.id,
    required this.type,
    this.expiresAt,
    this.filePath,
    this.status = KycStatus.submitted,
  });

  final String id;
  final KycDocType type;
  final DateTime? expiresAt;

  /// Local file path in the mock build (server upload in Phase 2).
  final String? filePath;
  final KycStatus status;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory KycDocumentInfo.fromJson(Map<String, dynamic> json) =>
      KycDocumentInfo(
        id: json['id'] as String,
        type: KycDocType.values.asNameMap()[json['type'] as String?] ??
            KycDocType.licence,
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.tryParse(json['expires_at'] as String),
        filePath: json['file_path'] as String?,
        status: switch (json['status'] as String?) {
          'pending' => KycStatus.submitted,
          'verified' => KycStatus.approved,
          'rejected' => KycStatus.rejected,
          _ => KycStatus.values.asNameMap()[json['status'] as String?] ??
              KycStatus.submitted,
        },
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'expires_at': expiresAt?.toIso8601String(),
        'file_path': filePath,
        'status': status.name,
      };
}

class PartnerProfile {
  const PartnerProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.kycStatus,
    required this.approvalStatus,
    required this.ratingAvg,
    required this.ratingCount,
    required this.acceptanceRate,
    this.languages = const ['Kannada', 'English'],
    this.rejectionReason,
    this.documentCount = 0,
    this.requiredDocumentCount = 3,
    this.onlineState = 'offline',
    this.notificationsEnabled = true,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final KycStatus kycStatus;
  final ApprovalStatus approvalStatus;
  final double ratingAvg;
  final int ratingCount;
  final double acceptanceRate;
  final List<String> languages;
  final String? rejectionReason;
  final int documentCount;
  final int requiredDocumentCount;

  /// Backend availability: `offline | available | busy`.
  final String onlineState;

  final bool notificationsEnabled;

  String get fullName => '$firstName $lastName'.trim();
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}'
      '${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

  bool get isApproved => approvalStatus == ApprovalStatus.active;

  factory PartnerProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final userMap = user is Map<String, dynamic> ? user : null;
    final documents = json['documents'];
    final documentCount = (json['document_count'] as num?)?.toInt() ??
        (documents is List ? documents.length : null) ??
        0;
    return PartnerProfile(
        id: json['id'] as String,
        firstName: (userMap?['first_name'] as String?) ??
            json['first_name'] as String? ??
            '',
        lastName: (userMap?['last_name'] as String?) ??
            json['last_name'] as String? ??
            '',
        email: (userMap?['email'] as String?) ??
            json['email'] as String? ??
            '',
        phone: (userMap?['phone'] as String?) ?? json['phone'] as String?,
        kycStatus: KycStatus.values.asNameMap()[json['kyc_status'] as String?] ??
            KycStatus.draft,
        approvalStatus: ApprovalStatus.values
                .asNameMap()[json['approval_status'] as String?] ??
            ApprovalStatus.pending,
        ratingAvg: jsonDouble(json['rating_avg']) ?? 0,
        ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
        acceptanceRate: jsonDouble(json['acceptance_rate']) ?? 0,
        languages: (json['languages'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const ['Kannada', 'English'],
        rejectionReason: json['rejection_reason'] as String?,
        documentCount: documentCount,
        requiredDocumentCount:
            (json['required_document_count'] as num?)?.toInt() ?? 3,
        onlineState: json['online_state'] as String? ?? 'offline',
        notificationsEnabled:
            json['notifications_enabled'] as bool? ?? true,
      );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'kyc_status': kycStatus.name,
        'approval_status': approvalStatus.name,
        'rating_avg': ratingAvg,
        'rating_count': ratingCount,
        'acceptance_rate': acceptanceRate,
        'languages': languages,
        'rejection_reason': rejectionReason,
        'document_count': documentCount,
        'required_document_count': requiredDocumentCount,
        'notifications_enabled': notificationsEnabled,
      };
}
