import '../../models/models.dart';
import '../../models/partner_models.dart';
import '../api_exception.dart';
import '../partner_api_contract.dart';
import 'mock_data.dart';
import 'mock_route.dart';

/// ============================================================
/// DEV-ONLY MOCK PARTNER API — `ENV=mock` only.
///
/// Implements the partner contract in memory with a self-driving offer
/// simulator so the partner app is demoable before the Django backend
/// (Phase 2). All data is fabricated. Any deviation from
/// `docs/06_partner_api.md` is a bug.
/// ============================================================
class MockPartnerApi implements PartnerApiContract {
  MockPartnerApi({
    this.latency = const Duration(milliseconds: 350),
    this.offerExpiry = const Duration(seconds: 15),
    this.kycReviewDelay = const Duration(seconds: 3),
    this.commissionPercent = 20,
  });

  final Duration latency;
  final Duration offerExpiry;

  /// Mock KYC review window — the profile flips to approved this long after
  /// submission (no timers; purely time-based).
  final Duration kycReviewDelay;
  final double commissionPercent;

  static const _goodsCodes = {
    'goods_2w',
    'goods_3w',
    'ace',
    'pickup',
    'van',
    'tempo',
  };

  static const _places = <(String, String, double, double)>[
    ('Indiranagar', '100 Feet Rd, Indiranagar', 12.9784, 77.6408),
    ('MG Road', 'MG Road Metro, Ashok Nagar', 12.9756, 77.6068),
    ('Koramangala', '80 Feet Rd, Koramangala 4th Block', 12.9352, 77.6245),
    ('Whitefield', 'Whitefield Main Rd, Bengaluru', 12.9698, 77.7500),
    ('Jayanagar', '4th Block, Jayanagar', 12.9250, 77.5938),
    ('HSR Layout', 'Sector 2, HSR Layout', 12.9116, 77.6389),
    ('Hebbal', 'Hebbal Flyover, Bengaluru', 13.0358, 77.5970),
    ('Malleshwaram', 'Sampige Rd, Malleshwaram', 13.0055, 77.5692),
  ];

  static const _customers = ['Ravi', 'Asha', 'Nikhil', 'Meera', 'Vishwanath'];
  static const _goodsTypes = [
    'Documents',
    'Furniture',
    'Electronics',
    'Groceries & perishables',
  ];

  final _users = <String, ZUser>{};
  final _passwords = <String, String>{};
  final _accessToEmail = <String, String>{};
  final _refreshToEmail = <String, String>{};
  final _kycSubmittedAt = <String, DateTime>{};
  final _docs = <String, List<KycDocumentInfo>>{};
  final _vehicles = <String, List<PartnerVehicle>>{};
  final _online = <String, bool>{};
  final _onlineSince = <String, DateTime>{};
  final _offers = <String, List<DriverOffer>>{};
  final _activeTrips = <String, PartnerTrip>{};
  final _otps = <String, String>{};
  final _deliveryOtpOk = <String, bool>{};
  final _ledger = <String, List<EarningEntry>>{};
  final _payouts = <String, List<Payout>>{};
  final _offersSeen = <String, int>{};
  final _offersAccepted = <String, int>{};
  final _tripsCancelled = <String, int>{};
  var _seq = 0;
  String? _currentEmail;

  // Fleet seed (mock org; the demo partner acts as fleet owner).
  var _fleetDrivers = <FleetDriver>[
    const FleetDriver(
      id: 'fdrv-1',
      name: 'Suresh Babu',
      phoneMasked: '+91 98450 •••21',
      online: true,
      ratingAvg: 4.8,
      tripsToday: 7,
      earningsTodayPaise: 128600,
      vehicleRegistration: 'KA 03 MK 8890',
    ),
    const FleetDriver(
      id: 'fdrv-2',
      name: 'Manjunath H',
      phoneMasked: '+91 98450 •••44',
      online: true,
      ratingAvg: 4.6,
      tripsToday: 4,
      earningsTodayPaise: 74200,
      vehicleRegistration: 'KA 51 MN 4477',
    ),
    const FleetDriver(
      id: 'fdrv-3',
      name: 'Lakshmi R',
      phoneMasked: '+91 98450 •••09',
      online: false,
      ratingAvg: 4.9,
      tripsToday: 0,
      earningsTodayPaise: 0,
    ),
  ];
  final _assignment = <String, String>{}; // vehicleId -> fleet driver id

  String _nextId(String prefix) => '$prefix-${++_seq}';

  Future<void> _wait() =>
      latency == Duration.zero ? Future<void>.value() : Future<void>.delayed(latency);

  DateTime get _now => DateTime.now();

  String _requireEmail() {
    final email = _currentEmail;
    if (email == null || !_users.containsKey(email)) {
      throw const ApiException(
        message: 'Not authenticated',
        statusCode: 401,
        code: 'unauthenticated',
      );
    }
    return email;
  }

  ZUser _requireUser() => _users[_requireEmail()]!;

  Session _issue(ZUser user) {
    final access = 'mock-p-access-${user.id}-${_seq++}';
    final refresh = 'mock-p-refresh-${user.id}-${_seq++}';
    _accessToEmail[access] = user.email;
    _refreshToEmail[refresh] = user.email;
    _currentEmail = user.email;
    _seedDriver(user);
    return Session(accessToken: access, refreshToken: refresh, user: user);
  }

  void _seedDriver(ZUser user) {
    final id = user.id;
    _docs.putIfAbsent(id, () => []);
    _vehicles.putIfAbsent(id, () => []);
    _offers.putIfAbsent(id, () => []);
    _offersSeen.putIfAbsent(id, () => 0);
    _offersAccepted.putIfAbsent(id, () => 0);
    _tripsCancelled.putIfAbsent(id, () => 0);
    _online.putIfAbsent(id, () => false);
    _ledger.putIfAbsent(id, () {
      final now = _now;
      return [
        _seedEntry(now, 'Auto', false, 14200),
        _seedEntry(now.subtract(const Duration(hours: 3)), 'Bike', false, 8600),
        _seedEntry(now.subtract(const Duration(days: 1)), 'Sedan', false, 23500),
        _seedEntry(now.subtract(const Duration(days: 3)), 'Tata Ace', true, 31200),
        _seedEntry(now.subtract(const Duration(days: 6)), 'Auto', false, 17100),
      ];
    });
    _payouts.putIfAbsent(
      id,
      () => [
        Payout(
          id: _nextId('payout'),
          amountPaise: 432000,
          status: PayoutStatus.paid,
          method: 'bank',
          paidAt: _now.subtract(const Duration(days: 7)),
          batchRef: 'BLR-W42',
        ),
        Payout(
          id: _nextId('payout'),
          amountPaise: 185000,
          status: PayoutStatus.pending,
          method: 'bank',
        ),
      ],
    );
  }

  EarningEntry _seedEntry(DateTime at, String category, bool goods, int fare) {
    final commission = (fare * commissionPercent / 100).round();
    return EarningEntry(
      bookingId: _nextId('seed-bk'),
      at: at,
      categoryName: category,
      isGoods: goods,
      farePaise: fare,
      commissionPaise: commission,
      earningPaise: fare - commission,
      paymentMethod: 'cash',
    );
  }

  // --- auth -------------------------------------------------------------------

  @override
  Future<Session> login({required String email, required String password}) async {
    await _wait();
    final normalized = email.trim().toLowerCase();
    final user = _users[normalized];
    if (user == null || _passwords[normalized] != password) {
      throw const ApiException(
        message: 'Incorrect email or password',
        statusCode: 401,
        code: 'invalid_credentials',
      );
    }
    return _issue(user);
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
      );
    }
    if (password.length < 6) {
      throw const ApiException(
        message: 'Password must be at least 6 characters',
        statusCode: 400,
        code: 'validation_error',
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
      );
    }
    final user = ZUser(
      id: _nextId('driver'),
      email: normalized,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      phone: (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
      phoneVerified: false,
      role: UserRole.driver,
      createdAt: _now.toUtc(),
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

  // --- profile & KYC ------------------------------------------------------------

  KycStatus _kycStatusFor(String email) {
    final submittedAt = _kycSubmittedAt[email];
    if (submittedAt == null) return KycStatus.draft;
    if (kycReviewDelay == Duration.zero) return KycStatus.approved;
    return _now.difference(submittedAt) >= kycReviewDelay
        ? KycStatus.approved
        : KycStatus.submitted;
  }

  PartnerProfile _profileFor(ZUser user) {
    final kyc = _kycStatusFor(user.email);
    final docs = _docs[user.id] ?? const <KycDocumentInfo>[];
    return PartnerProfile(
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
      phone: user.phone,
      kycStatus: kyc,
      approvalStatus: kyc == KycStatus.approved
          ? ApprovalStatus.active
          : ApprovalStatus.pending,
      ratingAvg: 4.82,
      ratingCount: 214,
      acceptanceRate: _acceptanceRate(user.id),
      documentCount: docs.length,
    );
  }

  double _acceptanceRate(String id) {
    final seen = _offersSeen[id] ?? 0;
    final accepted = _offersAccepted[id] ?? 0;
    return seen == 0 ? 92 : (accepted / seen * 100).clamp(0, 100);
  }

  @override
  Future<PartnerProfile> profile() async {
    await _wait();
    return _profileFor(_requireUser());
  }

  @override
  Future<PartnerProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    List<String>? languages,
  }) async {
    await _wait();
    final user = _requireUser();
    final updated = user.copyWith(
      firstName: firstName?.trim(),
      lastName: lastName?.trim(),
      phone: phone?.trim(),
    );
    _users[updated.email] = updated;
    return _profileFor(updated);
  }

  @override
  Future<List<KycDocumentInfo>> documents() async {
    await _wait();
    final user = _requireUser();
    return List.unmodifiable(_docs[user.id] ?? const []);
  }

  @override
  Future<KycDocumentInfo> uploadDocument({
    required KycDocType type,
    String? filePath,
    DateTime? expiresAt,
  }) async {
    await _wait();
    final user = _requireUser();
    final list = _docs[user.id]!;
    list.removeWhere((d) => d.type == type); // re-upload replaces
    final doc = KycDocumentInfo(
      id: _nextId('doc'),
      type: type,
      expiresAt: expiresAt,
      filePath: filePath,
      status: KycStatus.submitted,
    );
    list.add(doc);
    return doc;
  }

  @override
  Future<PartnerProfile> submitKyc() async {
    await _wait();
    final user = _requireUser();
    final docs = _docs[user.id] ?? const <KycDocumentInfo>[];
    const required = [
      KycDocType.licence,
      KycDocType.rc,
      KycDocType.insurance,
    ];
    final missing = [
      for (final t in required)
        if (!docs.any((d) => d.type == t)) t.name,
    ];
    if (missing.isNotEmpty) {
      throw ApiException(
        message: 'Upload the remaining documents to submit KYC',
        statusCode: 400,
        code: 'kyc_incomplete',
        details: {'missing': missing},
      );
    }
    _kycSubmittedAt[user.email] ??= _now;
    return _profileFor(user);
  }

  // --- vehicles -----------------------------------------------------------------

  @override
  Future<List<PartnerVehicle>> vehicles() async {
    await _wait();
    final user = _requireUser();
    return List.unmodifiable(_vehicles[user.id] ?? const []);
  }

  @override
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
  }) async {
    await _wait();
    final user = _requireUser();
    final category = MockData.serviceCategories
        .where((c) => c.code == categoryCode)
        .firstOrNull;
    if (category == null) {
      throw const ApiException(
        message: 'Unknown vehicle category',
        statusCode: 400,
        code: 'validation_error',
      );
    }
    final plate = registrationNumber.replaceAll(' ', '').toUpperCase();
    if (plate.isEmpty) {
      throw const ApiException(
        message: 'Registration number is required',
        statusCode: 400,
        code: 'validation_error',
      );
    }
    final list = _vehicles[user.id]!;
    if (list.any((v) => v.registrationNumber.replaceAll(' ', '') == plate)) {
      throw const ApiException(
        message: 'A vehicle with this registration already exists',
        statusCode: 409,
        code: 'already_exists',
      );
    }
    final vehicle = PartnerVehicle(
      id: _nextId('veh'),
      categoryCode: category.code,
      categoryName: category.name,
      registrationNumber: plate,
      make: make.trim(),
      model: model.trim(),
      color: color.trim(),
      capacityKg: capacityKg ?? category.capacityKg,
      volumeCuft: volumeCuft ?? category.volumeCuft,
      seats: seats ?? category.seats,
      insuranceExpiresAt: insuranceExpiresAt,
    );
    list.add(vehicle);
    return vehicle;
  }

  @override
  Future<PartnerVehicle> setVehicleAvailability({
    required String vehicleId,
    required bool isActive,
  }) async {
    await _wait();
    final user = _requireUser();
    final list = _vehicles[user.id]!;
    final i = list.indexWhere((v) => v.id == vehicleId);
    if (i < 0) {
      throw const ApiException(
        message: 'Vehicle not found',
        statusCode: 404,
        code: 'not_found',
      );
    }
    list[i] = list[i].copyWith(isActive: isActive);
    return list[i];
  }

  // --- availability -----------------------------------------------------------------

  @override
  Future<bool> setOnline({required bool online}) async {
    await _wait();
    final user = _requireUser();
    if (online) {
      final profile = _profileFor(user);
      if (!profile.isApproved) {
        throw const ApiException(
          message: 'Your account is pending approval',
          statusCode: 409,
          code: 'not_approved',
        );
      }
      final active = (_vehicles[user.id] ?? const [])
          .where((v) => v.isActive)
          .toList();
      if (active.isEmpty) {
        throw const ApiException(
          message: 'Add an active vehicle before going online',
          statusCode: 409,
          code: 'vehicle_inactive',
        );
      }
      _online[user.id] = true;
      _onlineSince[user.id] ??= _now;
    } else {
      _online[user.id] = false;
      _onlineSince.remove(user.id);
    }
    return online;
  }

  @override
  Future<void> updateLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speedMps,
    DateTime? recordedAt,
  }) async {
    await _wait();
    _requireUser();
  }

  @override
  Future<void> uploadPickupPod({
    required String bookingId,
    required String filePath,
  }) async {
    await _wait();
    final trip = _requireTrip(bookingId);
    if (trip.kind != OfferKind.goods) {
      throw const ApiException(
        message: 'Pickup POD applies to goods trips only',
        statusCode: 409,
        code: 'illegal_transition',
      );
    }
  }

  @override
  Future<void> uploadDeliveryPod({
    required String bookingId,
    required String receiverName,
    String? photoPath,
    String? signaturePath,
  }) async {
    await _wait();
    final trip = _requireTrip(bookingId);
    if (trip.kind != OfferKind.goods) {
      throw const ApiException(
        message: 'Delivery POD applies to goods trips only',
        statusCode: 409,
        code: 'illegal_transition',
      );
    }
  }

  @override
  Future<bool> isOnline() async {
    await _wait();
    return _online[_requireUser().id] ?? false;
  }

  /// Live flag for the offer simulator (no latency, no auth round-trip).
  bool get onlineNow {
    final email = _currentEmail;
    if (email == null) return false;
    final user = _users[email];
    return user != null && (_online[user.id] ?? false);
  }

  // --- offers -------------------------------------------------------------------------

  @override
  Future<List<DriverOffer>> pendingOffers() async {
    await _wait();
    final user = _requireUser();
    final list = _offers[user.id]!;
    list.removeWhere((o) => o.isExpired);
    return List.unmodifiable(list);
  }

  /// DEV-ONLY: creates a fabricated incoming offer (used by the simulator).
  DriverOffer createSimulatedOffer() {
    final user = _requireUser();
    if (!(_online[user.id] ?? false)) {
      throw const ApiException(
        message: 'Go online to receive offers',
        statusCode: 409,
        code: 'not_online',
      );
    }
    if ((_activeTrips[user.id]) != null) {
      throw const ApiException(
        message: 'Finish your active trip first',
        statusCode: 409,
        code: 'illegal_transition',
      );
    }
    final vehicles = (_vehicles[user.id] ?? const <PartnerVehicle>[])
        .where((v) => v.isActive)
        .toList();
    if (vehicles.isEmpty) {
      throw const ApiException(
        message: 'Add an active vehicle before receiving offers',
        statusCode: 409,
        code: 'vehicle_inactive',
      );
    }
    final vehicle = vehicles[_seq % vehicles.length];
    final pickup = _places[_seq % _places.length];
    var drop = _places[(_seq + 3) % _places.length];
    if (drop.$1 == pickup.$1) drop = _places[(_seq + 4) % _places.length];

    final distanceM = 2400 + (_seq % 7) * 950;
    final durationS = (distanceM / 22 * 3.6).round();
    final rate = MockData.rates[vehicle.categoryCode];
    final base = rate?.basePaise ?? 4000;
    final perKm = rate?.perKmPaise ?? 1100;
    final perMin = rate?.perMinPaise ?? 120;
    final surge = _seq % 3 == 0 ? 1.2 : 1.0;
    final fare = (((base + perKm * (distanceM / 1000) + perMin * (durationS / 60)) *
                surge)
            .round());

    final isGoods = _goodsCodes.contains(vehicle.categoryCode);
    final offer = DriverOffer(
      id: _nextId('offer'),
      bookingId: _nextId('bk'),
      expiresAt: _now.add(offerExpiry),
      pickup: LocationPoint(
        lat: pickup.$3,
        lng: pickup.$4,
        address: '${pickup.$1} · ${pickup.$2}',
      ),
      drop: LocationPoint(
        lat: drop.$3,
        lng: drop.$4,
        address: '${drop.$1} · ${drop.$2}',
      ),
      distanceM: distanceM,
      pickupEtaS: 240 + (_seq % 5) * 60,
      farePaise: fare,
      surgeMultiplier: surge,
      serviceCategoryCode: vehicle.categoryCode,
      serviceCategoryName: vehicle.categoryName,
      kind: isGoods ? OfferKind.goods : OfferKind.ride,
      goodsType: isGoods ? _goodsTypes[_seq % _goodsTypes.length] : null,
      weightKg: isGoods ? 10 + (_seq % 9) * 15 : null,
      needsLoadingHelp: isGoods && _seq % 4 == 0,
      customerFirstName: _customers[_seq % _customers.length],
      devOtpHint: '${1000 + (_seq * 137) % 9000}',
    );
    _offers[user.id]!.add(offer);
    _offersSeen[user.id] = (_offersSeen[user.id] ?? 0) + 1;
    return offer;
  }

  @override
  Future<PartnerTrip> acceptOffer(String offerId) async {
    await _wait();
    final user = _requireUser();
    final list = _offers[user.id]!;
    final offer = list.where((o) => o.id == offerId).firstOrNull;
    if (offer == null) {
      throw const ApiException(
        message: 'This offer is no longer available',
        statusCode: 404,
        code: 'not_found',
      );
    }
    list.remove(offer);
    if (offer.isExpired) {
      throw const ApiException(
        message: 'Offer expired',
        statusCode: 409,
        code: 'offer_expired',
      );
    }
    _offersAccepted[user.id] = (_offersAccepted[user.id] ?? 0) + 1;
    final commission = (offer.farePaise * commissionPercent / 100).round();
    final trip = PartnerTrip(
      bookingId: offer.bookingId,
      kind: offer.kind,
      status: PartnerTripStatus.assigned,
      pickup: offer.pickup,
      drop: offer.drop,
      farePaise: offer.farePaise,
      commissionPaise: commission,
      earningPaise: offer.farePaise - commission,
      serviceCategoryName: offer.serviceCategoryName,
      customerFirstName: offer.customerFirstName,
      customerPhoneMasked: '+91 98450 •••${(offer.bookingId.hashCode % 90 + 10)}',
      goodsType: offer.goodsType,
      needsLoadingHelp: offer.needsLoadingHelp,
      devOtpHint: offer.devOtpHint,
      route: mockCurvedRoute(offer.pickup, offer.drop),
    );
    _activeTrips[user.id] = trip;
    _otps[user.id] = offer.devOtpHint!;
    _deliveryOtpOk[user.id] = false;
    return trip;
  }

  @override
  Future<void> declineOffer(String offerId, {String? reason}) async {
    await _wait();
    final user = _requireUser();
    _offers[user.id]!.removeWhere((o) => o.id == offerId);
  }

  // --- trip lifecycle -------------------------------------------------------------------

  @override
  Future<PartnerTrip?> activeTrip() async {
    await _wait();
    return _activeTrips[_requireUser().id];
  }

  @override
  Future<RouteInfo> tripRoute(String bookingId, {String leg = 'drop'}) async {
    await _wait();
    final trip = _activeTrips[_requireUser().id];
    if (trip == null || trip.bookingId != bookingId) {
      throw const ApiException(
        message: 'Trip not found',
        statusCode: 404,
        code: 'not_found',
      );
    }
    const current = LocationPoint(lat: 12.9352, lng: 77.6245, address: 'Koramangala');
    final origin = leg == 'pickup' ? current : trip.pickup;
    final target = leg == 'pickup' ? trip.pickup : trip.drop;
    return mockCurvedRoute(origin, target).copyWith(leg: leg);
  }

  PartnerTrip _requireTrip(String bookingId) {
    final user = _requireUser();
    final trip = _activeTrips[user.id];
    if (trip == null || trip.bookingId != bookingId) {
      throw const ApiException(
        message: 'Trip not found',
        statusCode: 404,
        code: 'not_found',
      );
    }
    return trip;
  }

  void _requireStatus(PartnerTrip trip, PartnerTripStatus expected) {
    if (trip.status != expected) {
      throw const ApiException(
        message: 'This action is not valid for the current trip stage',
        statusCode: 409,
        code: 'illegal_transition',
      );
    }
  }

  PartnerTrip _copyTrip(
    PartnerTrip t, {
    PartnerTripStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
  }) =>
      PartnerTrip(
        bookingId: t.bookingId,
        kind: t.kind,
        status: status ?? t.status,
        pickup: t.pickup,
        drop: t.drop,
        farePaise: t.farePaise,
        commissionPaise: t.commissionPaise,
        earningPaise: t.earningPaise,
        serviceCategoryName: t.serviceCategoryName,
        customerFirstName: t.customerFirstName,
        customerPhoneMasked: t.customerPhoneMasked,
        paymentMethod: t.paymentMethod,
        goodsType: t.goodsType,
        needsLoadingHelp: t.needsLoadingHelp,
        startedAt: startedAt ?? t.startedAt,
        completedAt: completedAt ?? t.completedAt,
      );

  @override
  Future<PartnerTrip> arrive(String bookingId) async {
    await _wait();
    final user = _requireUser();
    final trip = _requireTrip(bookingId);
    _requireStatus(trip, PartnerTripStatus.assigned);
    final next = _copyTrip(trip, status: PartnerTripStatus.arrived);
    _activeTrips[user.id] = next;
    return next;
  }

  @override
  Future<PartnerTrip> verifyOtp({
    required String bookingId,
    required String otp,
  }) async {
    await _wait();
    final user = _requireUser();
    final trip = _requireTrip(bookingId);
    _requireStatus(trip, PartnerTripStatus.arrived);
    if (_otps[user.id] != otp.trim()) {
      throw const ApiException(
        message: 'Incorrect OTP',
        statusCode: 400,
        code: 'otp_invalid',
      );
    }
    final next = _copyTrip(
      trip,
      status: PartnerTripStatus.inProgress,
      startedAt: _now,
    );
    _activeTrips[user.id] = next;
    return next;
  }

  @override
  Future<PartnerTrip> verifyDeliveryOtp({
    required String bookingId,
    required String otp,
  }) async {
    await _wait();
    final user = _requireUser();
    final trip = _requireTrip(bookingId);
    _requireStatus(trip, PartnerTripStatus.inProgress);
    if (trip.kind != OfferKind.goods) {
      throw const ApiException(
        message: 'Delivery OTP applies to goods trips only',
        statusCode: 409,
        code: 'illegal_transition',
      );
    }
    if (_otps[user.id] != otp.trim()) {
      throw const ApiException(
        message: 'Incorrect delivery OTP',
        statusCode: 400,
        code: 'otp_invalid',
      );
    }
    _deliveryOtpOk[user.id] = true;
    return trip;
  }

  @override
  Future<PartnerTrip> complete(String bookingId) async {
    await _wait();
    final user = _requireUser();
    final trip = _requireTrip(bookingId);
    _requireStatus(trip, PartnerTripStatus.inProgress);
    if (trip.kind == OfferKind.goods && !(_deliveryOtpOk[user.id] ?? false)) {
      throw const ApiException(
        message: 'Verify the delivery OTP first',
        statusCode: 409,
        code: 'pod_missing',
      );
    }
    final next = _copyTrip(
      trip,
      status: PartnerTripStatus.completed,
      completedAt: _now,
    );
    _ledger[user.id]!.add(
      EarningEntry(
        bookingId: trip.bookingId,
        at: _now,
        categoryName: trip.serviceCategoryName,
        isGoods: trip.kind == OfferKind.goods,
        farePaise: trip.farePaise,
        commissionPaise: trip.commissionPaise,
        earningPaise: trip.earningPaise,
        paymentMethod: trip.paymentMethod.name,
      ),
    );
    _activeTrips.remove(user.id);
    _otps.remove(user.id);
    _deliveryOtpOk.remove(user.id);
    return next;
  }

  @override
  Future<void> cancelTrip(String bookingId, {required String reason}) async {
    await _wait();
    final user = _requireUser();
    _requireTrip(bookingId);
    _tripsCancelled[user.id] = (_tripsCancelled[user.id] ?? 0) + 1;
    _activeTrips.remove(user.id);
    _otps.remove(user.id);
    _deliveryOtpOk.remove(user.id);
  }

  // --- earnings ---------------------------------------------------------------------------

  @override
  Future<EarningsSummary> earnings(EarningsRange range) async {
    await _wait();
    final user = _requireUser();
    final now = _now;
    final start = switch (range) {
      EarningsRange.today => DateTime(now.year, now.month, now.day),
      EarningsRange.week => now.subtract(const Duration(days: 7)),
      EarningsRange.month => now.subtract(const Duration(days: 30)),
    };
    final entries =
        _ledger[user.id]!.where((e) => e.at.isAfter(start)).toList();
    final gross = entries.fold<int>(0, (s, e) => s + e.farePaise);
    final commission = entries.fold<int>(0, (s, e) => s + e.commissionPaise);
    final net = entries.fold<int>(0, (s, e) => s + e.earningPaise);
    final onlineMinutes = _online[user.id] == true
        ? _now.difference(_onlineSince[user.id] ?? _now).inMinutes
        : 0;
    final cancelled = _tripsCancelled[user.id] ?? 0;
    final completedAll = _ledger[user.id]!.length;
    return EarningsSummary(
      grossPaise: gross,
      commissionPaise: commission,
      netPaise: net,
      trips: entries.length,
      onlineMinutes: onlineMinutes,
      acceptanceRate: _acceptanceRate(user.id),
      cancellationRate: completedAll + cancelled == 0
          ? 0
          : cancelled / (completedAll + cancelled) * 100,
    );
  }

  @override
  Future<Paged<EarningEntry>> earningTrips({int page = 1}) async {
    await _wait();
    final user = _requireUser();
    final list = _ledger[user.id]!.reversed.toList();
    return Paged(results: list, count: list.length, next: false);
  }

  @override
  Future<Paged<Payout>> payouts({int page = 1}) async {
    await _wait();
    final user = _requireUser();
    final list = _payouts[user.id]!.reversed.toList();
    return Paged(results: list, count: list.length, next: false);
  }

  // --- fleet --------------------------------------------------------------------------------

  @override
  Future<FleetOverview> fleetOverview() async {
    await _wait();
    final user = _requireUser();
    final myVehicles = _vehicles[user.id] ?? const <PartnerVehicle>[];
    final online = _fleetDrivers.where((d) => d.online).length;
    final onTrip = _fleetDrivers.where((d) => d.tripsToday > 0).length;
    return FleetOverview(
      driversActive: online,
      driversTotal: _fleetDrivers.length,
      vehiclesActive: myVehicles.where((v) => v.isActive).length,
      vehiclesTotal: myVehicles.length,
      earningsTodayPaise:
          _fleetDrivers.fold<int>(0, (s, d) => s + d.earningsTodayPaise),
      utilisation: online == 0 ? 0 : onTrip / online,
    );
  }

  @override
  Future<List<FleetDriver>> fleetDrivers() async {
    await _wait();
    _requireUser();
    return List.unmodifiable(_fleetDrivers);
  }

  @override
  Future<List<PartnerVehicle>> fleetVehicles() async {
    await _wait();
    final user = _requireUser();
    return List.unmodifiable(_vehicles[user.id] ?? const []);
  }

  @override
  Future<void> assignVehicle({
    required String vehicleId,
    required String driverId,
  }) async {
    await _wait();
    final user = _requireUser();
    final vehicle = (_vehicles[user.id] ?? const <PartnerVehicle>[])
        .where((v) => v.id == vehicleId)
        .firstOrNull;
    if (vehicle == null) {
      throw const ApiException(
        message: 'Vehicle not found',
        statusCode: 404,
        code: 'not_found',
      );
    }
    final i = _fleetDrivers.indexWhere((d) => d.id == driverId);
    if (i < 0) {
      throw const ApiException(
        message: 'Driver not found',
        statusCode: 404,
        code: 'not_found',
      );
    }
    _assignment[vehicleId] = driverId;
    _fleetDrivers[i] = FleetDriver(
      id: _fleetDrivers[i].id,
      name: _fleetDrivers[i].name,
      phoneMasked: _fleetDrivers[i].phoneMasked,
      online: _fleetDrivers[i].online,
      ratingAvg: _fleetDrivers[i].ratingAvg,
      tripsToday: _fleetDrivers[i].tripsToday,
      earningsTodayPaise: _fleetDrivers[i].earningsTodayPaise,
      vehicleRegistration: vehicle.registrationNumber,
      isVerified: _fleetDrivers[i].isVerified,
    );
  }
}
