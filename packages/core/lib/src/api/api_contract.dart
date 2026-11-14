import '../models/models.dart';

/// Frozen consumer API surface (`docs/03_api_contract.md`).
///
/// The app only ever talks to this interface. Live implementation:
/// [ApiClient] (Dio). Dev implementation: `MockApiAdapter` (ENV=mock only).
abstract interface class ApiContract {
  // --- auth ---
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
  Future<void> forgotPassword(String email);
  Future<void> resetPassword({required String token, required String password});
  Future<ZUser> updateProfile({String? firstName, String? lastName, String? phone});

  // --- profile & addresses ---
  Future<List<SavedAddress>> savedAddresses();
  Future<SavedAddress> createSavedAddress({
    required String label,
    required String name,
    required double lat,
    required double lng,
    required String address,
  });
  Future<void> deleteSavedAddress(String id);

  // --- catalog & pricing ---
  Future<List<ServiceCategory>> serviceCategories({
    required String city,
    required ServiceKind kind,
  });
  Future<FareQuote> quote({
    required ServiceKind kind,
    required String serviceCategory,
    required LocationPoint pickup,
    required LocationPoint drop,
    int? weightKg,
    bool needsLoadingHelp = false,
  });

  // --- bookings ---
  Future<Booking> createBooking({
    required String quoteId,
    required String serviceCategory,
    required LocationPoint pickup,
    required LocationPoint drop,
    required PaymentMethod paymentMethod,
    DateTime? scheduledAt,
    String? promoCode,
    String? note,
    String? goodsType,
    int? weightKg,
    double? dimensionsCuft,
    bool needsLoadingHelp,
    String? senderName,
    String? senderPhone,
    String? receiverName,
    String? receiverPhone,
  });
  Future<Paged<Booking>> bookings({int page = 1, String? status});
  Future<Booking> booking(String id);

  /// Routed geometry + turn-by-turn steps for a booking.
  /// [leg] is `drop` (trip route) or `pickup` (driver approach).
  Future<RouteInfo> bookingRoute(String bookingId, {String leg = 'drop'});
  Future<void> cancelBooking(String id, {required String reason});

  /// Trip-start / delivery OTP verification (driver-side in production).
  Future<void> verifyOtp({required String bookingId, required String otp});

  /// Settle a completed trip (upi/wallet/card; cash is settled with driver).
  Future<Booking> payBooking({
    required String bookingId,
    required PaymentMethod method,
    int tipPaise = 0,
  });

  // --- payments & wallet ---
  Future<Wallet> wallet();
  Future<Wallet> topUpWallet({required int amountPaise, required PaymentMethod method});
  Future<Paged<WalletTransaction>> walletTransactions({int page = 1});

  // --- promos & reviews ---
  Future<List<PromoCampaign>> activePromos();
  Future<PromoCampaign> validatePromo({
    required String code,
    required int farePaise,
    required String serviceCategory,
  });
  Future<void> createReview({
    required String bookingId,
    required int rating,
    String? comment,
    List<String>? tags,
  });

  // --- notifications ---
  Future<Paged<ZNotification>> notifications({int page = 1});
  Future<void> markNotificationRead(String id);

  // --- support & safety ---
  Future<List<SupportTopic>> supportTopics();
  Future<Paged<SupportTicket>> supportTickets();
  Future<SupportTicket> createSupportTicket({
    required String subject,
    required String category,
    required String body,
    String? bookingId,
  });
  Future<void> sendSos({required String bookingId, double? lat, double? lng});
}
