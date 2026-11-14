import 'booking.dart';
import 'location.dart';

enum OfferKind { ride, goods }

/// A dispatch offer pushed to the driver (`docs/04_realtime_protocol.md`).
class DriverOffer {
  const DriverOffer({
    required this.id,
    required this.bookingId,
    required this.expiresAt,
    required this.pickup,
    required this.drop,
    required this.distanceM,
    required this.pickupEtaS,
    required this.farePaise,
    required this.surgeMultiplier,
    required this.serviceCategoryCode,
    required this.serviceCategoryName,
    required this.kind,
    this.goodsType,
    this.weightKg,
    this.needsLoadingHelp = false,
    this.customerFirstName,
    this.devOtpHint,
  });

  final String id;
  final String bookingId;
  final DateTime expiresAt;
  final LocationPoint pickup;
  final LocationPoint drop;
  final int distanceM;
  final int pickupEtaS;
  final int farePaise;
  final double surgeMultiplier;
  final String serviceCategoryCode;
  final String serviceCategoryName;
  final OfferKind kind;
  final String? goodsType;
  final int? weightKg;
  final bool needsLoadingHelp;
  final String? customerFirstName;

  /// DEV-ONLY: mock trips expose the boarding OTP so the single-app demo can
  /// complete verification. Never populated by the real backend.
  final String? devOtpHint;

  /// Inclusive: an offer is expired at its exact expiry instant (the
  /// Windows clock can report equal timestamps).
  bool get isExpired => !DateTime.now().isBefore(expiresAt);

  int get secondsLeft {
    final s = expiresAt.difference(DateTime.now()).inSeconds;
    return s < 0 ? 0 : s;
  }

  factory DriverOffer.fromJson(Map<String, dynamic> json) => DriverOffer(
        id: json['id'] as String,
        bookingId: json['booking_id'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
        pickup: LocationPoint.fromJson(json['pickup'] as Map<String, dynamic>),
        drop: LocationPoint.fromJson(json['drop'] as Map<String, dynamic>),
        distanceM: (json['distance_m'] as num?)?.toInt() ?? 0,
        pickupEtaS: (json['pickup_eta_s'] as num?)?.toInt() ?? 0,
        farePaise: (json['fare_paise'] as num?)?.toInt() ?? 0,
        surgeMultiplier: (json['surge_multiplier'] as num?)?.toDouble() ?? 1,
        serviceCategoryCode: json['service_category_code'] as String? ?? '',
        serviceCategoryName: json['service_category_name'] as String? ?? '',
        kind: (json['kind'] as String?) == 'goods'
            ? OfferKind.goods
            : OfferKind.ride,
        goodsType: json['goods_type'] as String?,
        weightKg: (json['weight_kg'] as num?)?.toInt(),
        needsLoadingHelp: json['needs_loading_help'] as bool? ?? false,
        customerFirstName: json['customer_first_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'booking_id': bookingId,
        'expires_at': expiresAt.toIso8601String(),
        'pickup': pickup.toJson(),
        'drop': drop.toJson(),
        'distance_m': distanceM,
        'pickup_eta_s': pickupEtaS,
        'fare_paise': farePaise,
        'surge_multiplier': surgeMultiplier,
        'service_category_code': serviceCategoryCode,
        'service_category_name': serviceCategoryName,
        'kind': kind == OfferKind.goods ? 'goods' : 'ride',
        'goods_type': goodsType,
        'weight_kg': weightKg,
        'needs_loading_help': needsLoadingHelp,
        'customer_first_name': customerFirstName,
      };
}

/// Active trip as seen by the partner (server-authoritative status).
enum PartnerTripStatus { assigned, arrived, inProgress, completed, cancelled }

class PartnerTrip {
  const PartnerTrip({
    required this.bookingId,
    required this.kind,
    required this.status,
    required this.pickup,
    required this.drop,
    required this.farePaise,
    required this.commissionPaise,
    required this.earningPaise,
    required this.serviceCategoryName,
    this.customerFirstName,
    this.customerPhoneMasked,
    this.paymentMethod = PaymentMethod.cash,
    this.goodsType,
    this.needsLoadingHelp = false,
    this.startedAt,
    this.completedAt,
    this.devOtpHint,
  });

  final String bookingId;
  final OfferKind kind;
  final PartnerTripStatus status;
  final LocationPoint pickup;
  final LocationPoint drop;
  final int farePaise;
  final int commissionPaise;
  final int earningPaise;
  final String serviceCategoryName;
  final String? customerFirstName;
  final String? customerPhoneMasked;
  final PaymentMethod paymentMethod;
  final String? goodsType;
  final bool needsLoadingHelp;
  final DateTime? startedAt;
  final DateTime? completedAt;

  /// DEV-ONLY single-app demo hint (see [DriverOffer.devOtpHint]).
  final String? devOtpHint;

  factory PartnerTrip.fromJson(Map<String, dynamic> json) => PartnerTrip(
        bookingId: json['booking_id'] as String,
        kind: (json['kind'] as String?) == 'goods'
            ? OfferKind.goods
            : OfferKind.ride,
        status: PartnerTripStatus.values
                .asNameMap()[json['status'] as String?] ??
            PartnerTripStatus.assigned,
        pickup: LocationPoint.fromJson(json['pickup'] as Map<String, dynamic>),
        drop: LocationPoint.fromJson(json['drop'] as Map<String, dynamic>),
        farePaise: (json['fare_paise'] as num?)?.toInt() ?? 0,
        commissionPaise: (json['commission_paise'] as num?)?.toInt() ?? 0,
        earningPaise: (json['earning_paise'] as num?)?.toInt() ?? 0,
        serviceCategoryName: json['service_category_name'] as String? ?? '',
        customerFirstName: json['customer_first_name'] as String?,
        customerPhoneMasked: json['customer_phone_masked'] as String?,
        paymentMethod: PaymentMethod.values
                .asNameMap()[json['payment_method'] as String?] ??
            PaymentMethod.cash,
        goodsType: json['goods_type'] as String?,
        needsLoadingHelp: json['needs_loading_help'] as bool? ?? false,
        startedAt: json['started_at'] == null
            ? null
            : DateTime.tryParse(json['started_at'] as String),
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.tryParse(json['completed_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'booking_id': bookingId,
        'kind': kind == OfferKind.goods ? 'goods' : 'ride',
        'status': status.name,
        'pickup': pickup.toJson(),
        'drop': drop.toJson(),
        'fare_paise': farePaise,
        'commission_paise': commissionPaise,
        'earning_paise': earningPaise,
        'service_category_name': serviceCategoryName,
        'customer_first_name': customerFirstName,
        'customer_phone_masked': customerPhoneMasked,
        'payment_method': paymentMethod.name,
        'goods_type': goodsType,
        'needs_loading_help': needsLoadingHelp,
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
      };
}
