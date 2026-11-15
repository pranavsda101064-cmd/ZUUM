import '../models/models.dart';
import '../models/partner_models.dart';

/// Partner API surface (`docs/06_partner_api.md`).
///
/// The app only talks to this interface. Live implementation ships with the
/// Phase 2 backend; `MockPartnerApi` (ENV=mock only) powers the demo build.
abstract interface class PartnerApiContract {
  // --- auth (shared JWT flow, driver role) ---
  Future<Session> login({required String email, required String password});
  Future<Session> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  });
  Future<Session> refresh(String refreshToken);
  Future<void> logout(String refreshToken);
  Future<ZUser> me();

  // --- profile & KYC ---
  Future<PartnerProfile> profile();
  Future<PartnerProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    List<String>? languages,
  });
  Future<List<KycDocumentInfo>> documents();
  Future<KycDocumentInfo> uploadDocument({
    required KycDocType type,
    String? filePath,
    DateTime? expiresAt,
  });
  Future<PartnerProfile> submitKyc();

  // --- vehicles ---
  Future<List<PartnerVehicle>> vehicles();
  Future<PartnerVehicle> createVehicle({
    required String categoryCode,
    required String registrationNumber,
    required String make,
    required String model,
    required String color,
    int? capacityKg,
    double? volumeCuft,
    int? seats,
    DateTime? insuranceExpiresAt,
  });
  Future<PartnerVehicle> setVehicleAvailability({
    required String vehicleId,
    required bool isActive,
  });

  // --- availability ---
  Future<bool> setOnline({required bool online});
  Future<bool> isOnline();

  /// REST location fallback (WS preferred when available).
  Future<void> updateLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speedMps,
    DateTime? recordedAt,
  });

  /// Goods POD evidence uploads.
  Future<void> uploadPickupPod({
    required String bookingId,
    required String filePath,
  });
  Future<void> uploadDeliveryPod({
    required String bookingId,
    required String receiverName,
    String? photoPath,
    String? signaturePath,
  });

  // --- offers ---
  Future<List<DriverOffer>> pendingOffers();
  Future<PartnerTrip> acceptOffer(String offerId);
  Future<void> declineOffer(String offerId, {String? reason});

  // --- trip lifecycle ---
  Future<PartnerTrip?> activeTrip();

  /// Route for navigation: `drop` (trip) or `pickup` (approach).
  Future<RouteInfo> tripRoute(String bookingId, {String leg = 'drop'});
  Future<PartnerTrip> arrive(String bookingId);
  Future<PartnerTrip> verifyOtp({required String bookingId, required String otp});
  Future<PartnerTrip> verifyDeliveryOtp({
    required String bookingId,
    required String otp,
  });
  Future<PartnerTrip> complete(String bookingId);
  Future<void> cancelTrip(String bookingId, {required String reason});

  // --- earnings ---
  Future<EarningsSummary> earnings(EarningsRange range);
  Future<Paged<EarningEntry>> earningTrips({int page = 1});
  Future<Paged<Payout>> payouts({int page = 1});

  // --- fleet ---
  Future<FleetOverview> fleetOverview();
  Future<List<FleetDriver>> fleetDrivers();
  Future<List<PartnerVehicle>> fleetVehicles();
  Future<void> assignVehicle({
    required String vehicleId,
    required String driverId,
  });
}
