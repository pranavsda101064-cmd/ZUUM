import '../../models/models.dart';
import '../../realtime/realtime_service.dart';
import '../../places/place_search.dart';
import '../api_contract.dart';
import '../api_exception.dart';
import 'mock_data.dart';
import 'mock_route.dart';

/// ============================================================
/// DEV-ONLY MOCK API — reachable only when `ENV=mock`.
/// Never used in production builds. All data is fabricated
/// development data, clearly labeled, for UI work before the
/// Django backend (Phase 2) exists.
/// ============================================================
class MockApiAdapter implements ApiContract {
  MockApiAdapter({this.latency = const Duration(milliseconds: 350)});

  /// Artificial latency so loading states are real during UI development.
  /// Widget tests pass `Duration.zero` to resolve in microtasks.
  final Duration latency;

  final _users = <String, ZUser>{}; // email → user
  final _passwords = <String, String>{};
  final _accessToEmail = <String, String>{};
  final _refreshToEmail = <String, String>{};
  final _addresses = <String, List<SavedAddress>>{}; // user id → addresses
  final _gst = <String, GstDetails>{}; // user id → GST details
  final _trusted = <String, List<TrustedContact>>{}; // user id → contacts
  final _bookings = <String, List<Booking>>{}; // user id → bookings
  final _wallets = <String, Wallet>{}; // user id → wallet
  final _walletTx = <String, List<WalletTransaction>>{};
  final _notifications = <String, List<ZNotification>>{};
  final _tickets = <String, List<SupportTicket>>{};
  final _reviews = <String, Map<String, int>>{}; // booking id → rating
  final _sosLog = <String, List<String>>{};
  var _seq = 0;

  String _nextId(String prefix) => '$prefix-${++_seq}';

  Future<void> _wait() =>
      latency == Duration.zero ? Future<void>.value() : Future<void>.delayed(latency);

  ZUser _requireUser() {
    // Mock has no header parsing; current user is the last issued session.
    final email = _currentEmail;
    if (email == null) {
      throw const ApiException(message: 'Not authenticated', statusCode: 401, code: 'unauthenticated');
    }
    final user = _users[email];
    if (user == null) {
      throw const ApiException(message: 'Not authenticated', statusCode: 401, code: 'unauthenticated');
    }
    return user;
  }

  String? _currentEmail;

  Session _issue(ZUser user) {
    final access = 'mock-access-${user.id}-${_seq++}';
    final refresh = 'mock-refresh-${user.id}-${_seq++}';
    _accessToEmail[access] = user.email;
    _refreshToEmail[refresh] = user.email;
    _currentEmail = user.email;
    _addresses.putIfAbsent(user.id, () => MockData.defaultAddresses(user.id));
    _bookings.putIfAbsent(user.id, () => MockData.seedBookings(user.id));
    _wallets.putIfAbsent(
      user.id,
      () => const Wallet(balancePaise: 15000), // ₹150 demo balance
    );
    _walletTx.putIfAbsent(
      user.id,
      () => [
        WalletTransaction(
          id: _nextId('wtx'),
          type: WalletTxType.topup,
          amountPaise: 15000,
          balanceAfterPaise: 15000,
          note: 'Welcome bonus',
          createdAt: DateTime.now().toUtc(),
        ),
      ],
    );
    _notifications.putIfAbsent(user.id, () => MockData.seedNotifications(_nextId));
    return Session(accessToken: access, refreshToken: refresh, user: user);
  }

  // --- auth -----------------------------------------------------------------

  @override
  Future<Session> login({required String email, required String password}) async {
    await _wait();
    final normalized = email.trim().toLowerCase();
    if (!normalized.contains('@')) {
      throw const ApiException(
        message: 'Enter a valid email address',
        statusCode: 400,
        code: 'validation_error',
        details: {'email': ['Enter a valid email address']},
      );
    }
    if (password.length < 6) {
      throw const ApiException(
        message: 'Password must be at least 6 characters',
        statusCode: 400,
        code: 'validation_error',
        details: {'password': ['Password must be at least 6 characters']},
      );
    }
    final existing = _users[normalized];
    if (existing == null) {
      throw const ApiException(
        message: 'No account found for this email',
        statusCode: 401,
        code: 'invalid_credentials',
      );
    }
    if (_passwords[normalized] != password) {
      throw const ApiException(
        message: 'Incorrect password',
        statusCode: 401,
        code: 'invalid_credentials',
      );
    }
    return _issue(existing);
  }

  @override
  Future<Session> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    await _wait();
    final normalized = email.trim().toLowerCase();
    if (!normalized.contains('@')) {
      throw const ApiException(
        message: 'Enter a valid email address',
        statusCode: 400,
        code: 'validation_error',
        details: {'email': ['Enter a valid email address']},
      );
    }
    if (password.length < 6) {
      throw const ApiException(
        message: 'Password must be at least 6 characters',
        statusCode: 400,
        code: 'validation_error',
        details: {'password': ['Use at least 6 characters']},
      );
    }
    if (firstName.trim().isEmpty || lastName.trim().isEmpty) {
      throw const ApiException(
        message: 'Name is required',
        statusCode: 400,
        code: 'validation_error',
      );
    }
    if (_users.containsKey(normalized)) {
      throw const ApiException(
        message: 'An account with this email already exists',
        statusCode: 409,
        code: 'already_exists',
        details: {'email': ['An account with this email already exists']},
      );
    }
    final user = ZUser(
      id: _nextId('user'),
      email: normalized,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      phoneVerified: false,
      role: UserRole.customer,
      createdAt: DateTime.now().toUtc(),
    );
    _users[normalized] = user;
    _passwords[normalized] = password;
    return _issue(user);
  }

  @override
  Future<Session> refresh(String refreshToken) async {
    await _wait();
    final email = _refreshToEmail[refreshToken];
    if (email == null || !_users.containsKey(email)) {
      throw const ApiException(
        message: 'Session expired',
        statusCode: 401,
        code: 'token_not_valid',
      );
    }
    return _issue(_users[email]!);
  }

  @override
  Future<void> logout(String refreshToken) async {
    await _wait();
    _refreshToEmail.remove(refreshToken);
  }

  @override
  Future<ZUser> me() async {
    await _wait();
    return _requireUser();
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _wait();
    // Always succeeds (no account enumeration), matches contract.
  }

  @override
  Future<void> resetPassword({required String token, required String password}) async {
    await _wait();
    if (password.length < 6) {
      throw const ApiException(
        message: 'Password must be at least 6 characters',
        statusCode: 400,
        code: 'validation_error',
      );
    }
  }

  // --- addresses ---------------------------------------------------------------

  @override
  Future<List<SavedAddress>> savedAddresses() async {
    await _wait();
    final user = _requireUser();
    return List.unmodifiable(_addresses[user.id] ?? const []);
  }

  @override
  Future<SavedAddress> createSavedAddress({
    required String label,
    required String name,
    required double lat,
    required double lng,
    required String address,
  }) async {
    await _wait();
    final user = _requireUser();
    final saved = SavedAddress(
      id: _nextId('addr'),
      label: label,
      name: name,
      lat: lat,
      lng: lng,
      address: address,
    );
    _addresses[user.id] = [...?_addresses[user.id], saved];
    return saved;
  }

  @override
  Future<void> deleteSavedAddress(String id) async {
    await _wait();
    final user = _requireUser();
    _addresses[user.id]?.removeWhere((a) => a.id == id);
  }

  // --- catalog & pricing --------------------------------------------------------

  @override
  Future<List<ServiceCategory>> serviceCategories({
    required String city,
    required ServiceKind kind,
  }) async {
    await _wait();
    if (city != 'blr') return const [];
    return MockData.serviceCategories.where((c) => c.kind == kind).toList();
  }

  @override
  Future<FareQuote> quote({
    required ServiceKind kind,
    required String serviceCategory,
    required LocationPoint pickup,
    required LocationPoint drop,
    int? weightKg,
    bool needsLoadingHelp = false,
  }) async {
    await _wait();
    _requireUser();
    final rates = MockData.rates[serviceCategory];
    if (rates == null) {
      throw const ApiException(
        message: 'Unknown service category',
        statusCode: 400,
        code: 'validation_error',
      );
    }
    final route = mockCurvedRoute(pickup, drop);
    final distanceM = route.distanceM;
    final durationS = route.durationS;
    final km = distanceM / 1000.0;
    final minutes = durationS / 60.0;

    final base = rates.basePaise;
    final distance = (km * rates.perKmPaise).round();
    final time = (minutes * rates.perMinPaise).round();
    final surge = 0;
    final toll = 0;
    final waiting = needsLoadingHelp ? 5000 : 0;
    var discount = 0;
    if (weightKg != null && weightKg > 500) discount += 1000; // mock goods promo
    final total = [base + distance + time + surge + toll + waiting - discount, 0]
        .reduce((a, b) => a > b ? a : b);

    return FareQuote(
      id: _nextId('quote'),
      serviceCategory: serviceCategory,
      distanceM: distanceM.round(),
      durationS: durationS,
      route: route,
      breakdown: FareBreakdown(
        basePaise: base,
        distancePaise: distance,
        timePaise: time,
        surgePaise: surge,
        tollPaise: toll,
        waitingPaise: waiting,
        discountPaise: discount,
        totalPaise: total,
      ),
      validUntil: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );
  }

  // --- bookings -----------------------------------------------------------------

  @override
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
    bool needsLoadingHelp = false,
    String? senderName,
    String? senderPhone,
    String? receiverName,
    String? receiverPhone,
  }) async {
    await _wait();
    _requireUser();
    final category = MockData.serviceCategories
        .where((c) => c.code == serviceCategory)
        .firstOrNull;
    if (category == null) {
      throw const ApiException(
        message: 'Unknown service category',
        statusCode: 400,
        code: 'validation_error',
      );
    }
    final rates = MockData.rates[serviceCategory];
    if (rates == null) {
      throw const ApiException(
        message: 'Unknown service category',
        statusCode: 400,
        code: 'validation_error',
      );
    }
    final route = mockCurvedRoute(pickup, drop);
    final distanceM = route.distanceM;
    final durationS = route.durationS;
    final km = distanceM / 1000.0;
    final minutes = durationS / 60.0;
    final base = rates.basePaise;
    final distance = (km * rates.perKmPaise).round();
    final time = (minutes * rates.perMinPaise).round();
    final loading = needsLoadingHelp ? 5000 : 0;
    var total = base + distance + time + loading;

    // Apply promo if provided (server-side truth).
    if (promoCode != null && promoCode.isNotEmpty) {
      final promo = MockData.promos
          .where((p) => p.code.toLowerCase() == promoCode.toLowerCase())
          .firstOrNull;
      if (promo != null) {
        total -= promo.discountFor(total);
      }
    }

    final booking = Booking(
      id: _nextId('bk'),
      type: category.kind == ServiceKind.goods ? BookingType.goods : BookingType.ride,
      status: BookingStatus.searching,
      serviceCategoryCode: category.code,
      serviceCategoryName: category.name,
      pickupAddress: pickup.address ?? 'Pickup',
      dropAddress: drop.address ?? 'Drop',
      quotedFarePaise: total,
      paymentMethod: paymentMethod,
      paymentState: PaymentState.unpaid,
      scheduledAt: scheduledAt?.toUtc(),
      createdAt: DateTime.now().toUtc(),
      pickupLat: pickup.lat,
      pickupLng: pickup.lng,
      dropLat: drop.lat,
      dropLng: drop.lng,
      // Deterministic dev OTP for goods delivery; production generates a
      // random OTP per trip and sends it to the receiver.
      otp: category.kind == ServiceKind.goods ? '4321' : null,
      goodsType: goodsType,
      weightKg: weightKg,
      dimensionsCuft: dimensionsCuft,
      needsLoadingHelp: needsLoadingHelp,
      senderName: senderName,
      senderPhone: senderPhone,
      receiverName: receiverName,
      receiverPhone: receiverPhone,
      route: route,
    );
    _bookings[_requireUser().id] = [...?_bookings[_requireUser().id], booking];
    return booking;
  }

  @override
  Future<Paged<Booking>> bookings({int page = 1, String? status}) async {
    await _wait();
    final user = _requireUser();
    var list = _bookings[user.id] ?? const <Booking>[];
    if (status != null) {
      list = list.where((b) => b.status.apiValue == status).toList();
    }
    return Paged(results: list.reversed.toList(), count: list.length, next: false);
  }

  @override
  Future<Booking> booking(String id) async {
    await _wait();
    final user = _requireUser();
    final found = (_bookings[user.id] ?? const <Booking>[])
        .where((b) => b.id == id)
        .firstOrNull;
    if (found == null) {
      throw const ApiException(message: 'Booking not found', statusCode: 404, code: 'not_found');
    }
    return found;
  }

  @override
  Future<DriverLocation?> bookingLocation(String bookingId) async {
    await _wait();
    _requireUser();
    return null; // the mock realtime service plays the driver side
  }

  @override
  Future<void> submitPod({
    required String bookingId,
    required String receiverName,
    required String otp,
    String? photoPath,
    String? signaturePath,
  }) async {
    await _wait();
    final user = _requireUser();
    final booking = _find(user.id, bookingId);
    if (booking.type != BookingType.goods) {
      throw const ApiException(
        message: 'POD applies to goods deliveries only',
        statusCode: 409,
        code: 'illegal_transition',
      );
    }
    if (booking.otp != null && otp != booking.otp) {
      throw const ApiException(
        message: 'Incorrect delivery OTP',
        statusCode: 400,
        code: 'otp_invalid',
      );
    }
  }

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    required double lat,
    required double lng,
    int limit = 8,
  }) =>
      MockPlaceSearch().search(
        query,
        proximityLat: lat,
        proximityLng: lng,
        limit: limit,
      );

  @override
  Future<PlaceSuggestion?> reversePlace({
    required double lat,
    required double lng,
  }) async =>
      null;

  @override
  Future<RouteInfo> bookingRoute(String bookingId, {String leg = 'drop'}) async {
    await _wait();
    final user = _requireUser();
    final booking = (_bookings[user.id] ?? const <Booking>[])
        .where((b) => b.id == bookingId)
        .firstOrNull;
    if (booking == null) {
      throw const ApiException(
        message: 'Booking not found',
        statusCode: 404,
        code: 'not_found',
      );
    }
    final pickup = LocationPoint(
      lat: booking.pickupLat ?? 12.9352,
      lng: booking.pickupLng ?? 77.6245,
      address: booking.pickupAddress,
    );
    final drop = LocationPoint(
      lat: booking.dropLat ?? 12.9716,
      lng: booking.dropLng ?? 77.5946,
      address: booking.dropAddress,
    );
    if (leg == 'pickup') {
      const current = LocationPoint(
        lat: 12.9352,
        lng: 77.6245,
        address: 'Koramangala',
      );
      return mockCurvedRoute(current, pickup).copyWith(leg: 'pickup');
    }
    return booking.route ?? mockCurvedRoute(pickup, drop);
  }

  @override
  Future<void> cancelBooking(String id, {required String reason}) async {
    await _wait();
    final user = _requireUser();
    final list = _bookings[user.id];
    final index = list?.indexWhere((b) => b.id == id) ?? -1;
    if (index < 0 || list == null) {
      throw const ApiException(message: 'Booking not found', statusCode: 404, code: 'not_found');
    }
    final current = list[index];
    if (current.status == BookingStatus.completed ||
        current.status == BookingStatus.cancelled) {
      throw const ApiException(
        message: 'This booking can no longer be cancelled',
        statusCode: 409,
        code: 'illegal_transition',
      );
    }
    list[index] = Booking(
      id: current.id,
      type: current.type,
      status: BookingStatus.cancelled,
      serviceCategoryCode: current.serviceCategoryCode,
      serviceCategoryName: current.serviceCategoryName,
      pickupAddress: current.pickupAddress,
      dropAddress: current.dropAddress,
      quotedFarePaise: current.quotedFarePaise,
      finalFarePaise: current.finalFarePaise,
      paymentMethod: current.paymentMethod,
      paymentState: current.paymentState,
      scheduledAt: current.scheduledAt,
      createdAt: current.createdAt,
      driver: current.driver,
      vehicle: current.vehicle,
    );
  }

  // --- profile -----------------------------------------------------------------

  @override
  Future<GstDetails> gstDetails() async {
    await _wait();
    final user = _requireUser();
    return _gst[user.id] ?? const GstDetails();
  }

  @override
  Future<GstDetails> saveGstDetails({
    required String gstin,
    required String businessName,
  }) async {
    await _wait();
    final user = _requireUser();
    final details = GstDetails(
      gstin: gstin.trim().isEmpty ? null : gstin.trim(),
      businessName: businessName.trim().isEmpty ? null : businessName.trim(),
    );
    _gst[user.id] = details;
    return details;
  }

  @override
  Future<List<TrustedContact>> trustedContacts() async {
    await _wait();
    final user = _requireUser();
    return List.unmodifiable(_trusted[user.id] ?? const []);
  }

  @override
  Future<TrustedContact> addTrustedContact({
    required String name,
    required String phone,
  }) async {
    await _wait();
    final user = _requireUser();
    final contact = TrustedContact(
      id: _nextId('contact'),
      name: name.trim(),
      phone: phone.trim(),
    );
    _trusted[user.id] = [...?_trusted[user.id], contact];
    return contact;
  }

  @override
  Future<void> deleteTrustedContact(String id) async {
    await _wait();
    final user = _requireUser();
    _trusted[user.id]?.removeWhere((c) => c.id == id);
  }

  @override
  Future<ZUser> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    await _wait();
    final user = _requireUser();
    final updated = user.copyWith(
      firstName: firstName?.trim(),
      lastName: lastName?.trim(),
      phone: phone?.trim(),
    );
    _users[updated.email] = updated;
    _currentEmail = updated.email;
    return updated;
  }

  // --- trip lifecycle ------------------------------------------------------------

  @override
  Future<void> verifyOtp({required String bookingId, required String otp}) async {
    await _wait();
    final user = _requireUser();
    final booking = _find(user.id, bookingId);
    if (booking.otp != null && booking.otp != otp) {
      throw const ApiException(
        message: 'Incorrect OTP',
        statusCode: 400,
        code: 'invalid_otp',
      );
    }
  }

  @override
  Future<Booking> payBooking({
    required String bookingId,
    required PaymentMethod method,
    int tipPaise = 0,
  }) async {
    await _wait();
    final user = _requireUser();
    final booking = _find(user.id, bookingId);
    if (booking.status != BookingStatus.completed) {
      throw const ApiException(
        message: 'Trip is not completed yet',
        statusCode: 409,
        code: 'illegal_transition',
      );
    }
    final total = booking.quotedFarePaise + tipPaise;

    if (method == PaymentMethod.wallet) {
      final wallet = _wallets[user.id] ?? const Wallet(balancePaise: 0);
      if (wallet.balancePaise < total) {
        throw const ApiException(
          message: 'Insufficient wallet balance',
          statusCode: 400,
          code: 'insufficient_balance',
        );
      }
      _wallets[user.id] = Wallet(balancePaise: wallet.balancePaise - total);
      _walletTx[user.id] = [
        ...?_walletTx[user.id],
        WalletTransaction(
          id: _nextId('wtx'),
          type: WalletTxType.debit,
          amountPaise: total,
          balanceAfterPaise: wallet.balancePaise - total,
          note: 'Trip payment · ${booking.serviceCategoryName}',
          referenceId: booking.id,
          createdAt: DateTime.now().toUtc(),
        ),
      ];
    }

    _replace(
      user.id,
      booking.copyWith(
        finalFarePaise: total,
        paymentState: PaymentState.paid,
        paymentMethod: method,
      ),
    );
    return _find(user.id, bookingId);
  }

  void _replace(String userId, Booking booking) {
    final list = _bookings[userId];
    if (list == null) return;
    final i = list.indexWhere((b) => b.id == booking.id);
    if (i >= 0) list[i] = booking;
  }

  Booking _find(String userId, String bookingId) {
    final found = (_bookings[userId] ?? const <Booking>[])
        .where((b) => b.id == bookingId)
        .firstOrNull;
    if (found == null) {
      throw const ApiException(
        message: 'Booking not found',
        statusCode: 404,
        code: 'not_found',
      );
    }
    return found;
  }

  // --- wallet -------------------------------------------------------------------

  @override
  Future<Wallet> wallet() async {
    await _wait();
    final user = _requireUser();
    return _wallets[user.id] ?? const Wallet(balancePaise: 0);
  }

  @override
  Future<Wallet> topUpWallet({
    required int amountPaise,
    required PaymentMethod method,
  }) async {
    await _wait();
    final user = _requireUser();
    if (amountPaise < 1000) {
      throw const ApiException(
        message: 'Minimum top-up is ₹10',
        statusCode: 400,
        code: 'validation_error',
      );
    }
    final wallet = _wallets[user.id] ?? const Wallet(balancePaise: 0);
    final updated = Wallet(balancePaise: wallet.balancePaise + amountPaise);
    _wallets[user.id] = updated;
    _walletTx[user.id] = [
      ...?_walletTx[user.id],
      WalletTransaction(
        id: _nextId('wtx'),
        type: WalletTxType.topup,
        amountPaise: amountPaise,
        balanceAfterPaise: updated.balancePaise,
        note: method == PaymentMethod.upi ? 'UPI top-up' : 'Top-up',
        createdAt: DateTime.now().toUtc(),
      ),
    ];
    return updated;
  }

  @override
  Future<Paged<WalletTransaction>> walletTransactions({int page = 1}) async {
    await _wait();
    final user = _requireUser();
    final list = (_walletTx[user.id] ?? const <WalletTransaction>[])
        .reversed
        .toList();
    return Paged(results: list, count: list.length, next: false);
  }

  // --- promos & reviews ---------------------------------------------------------

  @override
  Future<List<PromoCampaign>> activePromos() async {
    await _wait();
    _requireUser();
    return MockData.promos;
  }

  @override
  Future<PromoCampaign> validatePromo({
    required String code,
    required int farePaise,
    required String serviceCategory,
  }) async {
    await _wait();
    _requireUser();
    final promo = MockData.promos
        .where((p) => p.code.toLowerCase() == code.trim().toLowerCase())
        .firstOrNull;
    if (promo == null) {
      throw const ApiException(
        message: 'This promo code is not valid',
        statusCode: 400,
        code: 'invalid_promo',
      );
    }
    if (farePaise < promo.minFarePaise) {
      throw ApiException(
        message: 'Minimum fare ₹${promo.minFarePaise ~/ 100} required',
        statusCode: 400,
        code: 'promo_min_fare',
      );
    }
    return promo;
  }

  @override
  Future<void> createReview({
    required String bookingId,
    required int rating,
    String? comment,
    List<String>? tags,
  }) async {
    await _wait();
    final user = _requireUser();
    _find(user.id, bookingId);
    if (rating < 1 || rating > 5) {
      throw const ApiException(
        message: 'Rating must be between 1 and 5',
        statusCode: 400,
        code: 'validation_error',
      );
    }
    _reviews[bookingId] = {'rating': rating};
  }

  // --- notifications -------------------------------------------------------------

  @override
  Future<Paged<ZNotification>> notifications({int page = 1}) async {
    await _wait();
    final user = _requireUser();
    final list = (_notifications[user.id] ?? const <ZNotification>[])
        .reversed
        .toList();
    return Paged(results: list, count: list.length, next: false);
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _wait();
    final user = _requireUser();
    final list = _notifications[user.id];
    if (list == null) return;
    final i = list.indexWhere((n) => n.id == id);
    if (i < 0) return;
    final n = list[i];
    list[i] = ZNotification(
      id: n.id,
      title: n.title,
      body: n.body,
      type: n.type,
      createdAt: n.createdAt,
      readAt: DateTime.now().toUtc(),
      data: n.data,
    );
  }

  // --- support & safety ----------------------------------------------------------

  @override
  Future<List<SupportTopic>> supportTopics() async {
    await _wait();
    return MockData.supportTopics;
  }

  @override
  Future<Paged<SupportTicket>> supportTickets() async {
    await _wait();
    final user = _requireUser();
    final list = (_tickets[user.id] ?? const <SupportTicket>[])
        .reversed
        .toList();
    return Paged(results: list, count: list.length, next: false);
  }

  @override
  Future<SupportTicket> createSupportTicket({
    required String subject,
    required String category,
    required String body,
    String? bookingId,
  }) async {
    await _wait();
    final user = _requireUser();
    final ticket = SupportTicket(
      id: _nextId('tkt'),
      subject: subject,
      category: category,
      status: 'open',
      createdAt: DateTime.now().toUtc(),
      bookingId: bookingId,
      messages: [
        SupportMessage(
          id: _nextId('msg'),
          author: 'you',
          body: body,
          createdAt: DateTime.now().toUtc(),
        ),
      ],
    );
    _tickets[user.id] = [...?_tickets[user.id], ticket];
    return ticket;
  }

  @override
  Future<void> sendSos({required String bookingId, double? lat, double? lng}) async {
    await _wait();
    final user = _requireUser();
    _find(user.id, bookingId);
    _sosLog[user.id] = [
      ...?_sosLog[user.id],
      'SOS ${DateTime.now().toUtc().toIso8601String()} @ $lat,$lng',
    ];
  }

  /// Mirror a realtime dispatch event into the stored booking (used by
  /// MockRealtimeService in `ENV=mock` so history stays accurate).
  void applyRealtimeEvent(RealtimeEvent event) {
    for (final list in _bookings.values) {
      final i = list.indexWhere((b) => b.id == event.bookingId);
      if (i < 0) continue;
      list[i] = list[i].copyWith(
        status: event.status,
        driver: event.driver,
        vehicle: event.vehicle,
        otp: event.otp,
        finalFarePaise: event.finalFarePaise,
      );
      return;
    }
  }
}
