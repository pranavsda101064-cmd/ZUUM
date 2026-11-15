import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/models.dart';
import '../models/partner_models.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'partner_api_contract.dart';

/// Live partner API client (`docs/06_partner_api.md`).
///
/// Mirrors [ApiClient]: bearer auth, single-flight refresh on 401, multipart
/// uploads for KYC/POD, and the same error envelope mapping.
class ApiPartnerClient implements PartnerApiContract {
  ApiPartnerClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    Dio? dio,
  }) : _storage = tokenStorage {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 45),
          ),
        );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final session = await _storage.readSession();
          if (session != null) {
            options.headers['Authorization'] = 'Bearer ${session.accessToken}';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final retried = error.requestOptions.extra['retried'] == true;
          final wakeRetried =
              error.requestOptions.extra['wake_retried'] == true;
          final waking = status == 502 ||
              status == 503 ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout;
          if (waking && !wakeRetried) {
            await Future<void>.delayed(const Duration(seconds: 2));
            final opts = error.requestOptions..extra['wake_retried'] = true;
            try {
              final response = await _dio.fetch<dynamic>(opts);
              return handler.resolve(response);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          if (status == 401 && !retried) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final opts = error.requestOptions..extra['retried'] = true;
              final session = await _storage.readSession();
              if (session != null) {
                opts.headers['Authorization'] =
                    'Bearer ${session.accessToken}';
              }
              try {
                final response = await _dio.fetch<dynamic>(opts);
                return handler.resolve(response);
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final TokenStorage _storage;
  Future<bool>? _refreshInFlight;
  bool _online = false;

  // --- helpers -----------------------------------------------------------------

  Map<String, dynamic> _json(dynamic data) {
    if (data == null || data == '') return const {};
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      final decoded = jsonDecode(data);
      return decoded is Map<String, dynamic> ? decoded : const {};
    }
    return const {};
  }

  Never _fail(DioException error) {
    final responseData = error.response?.data;
    final map = responseData is Map<String, dynamic> ? responseData : null;
    final status = error.response?.statusCode;
    if (status == 502 ||
        status == 503 ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      throw ApiException(
        message: 'Server is waking up. Tap retry in a moment.',
        statusCode: status,
        code: 'server_waking',
      );
    }
    if (error.response == null) {
      throw const ApiException(
        message: 'No internet connection. Check your network.',
        code: 'network_error',
      );
    }
    throw ApiException(
      message: (map?['message'] as String?) ??
          error.message ??
          'Request failed. Please try again.',
      statusCode: error.response?.statusCode,
      code: map?['code'] as String?,
      details: map?['details'],
    );
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final response = await call();
      return _json(response.data);
    } on DioException catch (e) {
      _fail(e);
    }
  }

  Future<bool> _tryRefresh() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final future = _doRefresh();
    _refreshInFlight = future;
    return future.whenComplete(() => _refreshInFlight = null);
  }

  Future<bool> _doRefresh() async {
    try {
      final session = await _storage.readSession();
      if (session == null) return false;
      final next = await refresh(session.refreshToken);
      await _storage.saveSession(next);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- auth --------------------------------------------------------------------

  @override
  Future<Session> login({required String email, required String password}) async {
    final data = await _request(
      () => _dio.post<dynamic>(
        '/auth/login',
        data: {'email': email, 'password': password},
      ),
    );
    return Session.fromJson(data);
  }

  @override
  Future<Session> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    await _request(
      () => _dio.post<dynamic>(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          if (phone != null) 'phone': phone,
        },
      ),
    );
    // Backend returns `{user}` on register; sign in for the session.
    return login(email: email, password: password);
  }

  @override
  Future<Session> refresh(String refreshToken) async {
    final data = await _request(
      () => _dio.post<dynamic>('/auth/refresh', data: {'refresh': refreshToken}),
    );
    if (data.containsKey('user')) return Session.fromJson(data);
    final stored = await _storage.readSession();
    if (stored == null) {
      throw const ApiException(
        message: 'Session expired',
        statusCode: 401,
        code: 'token_not_valid',
      );
    }
    return Session(
      accessToken: data['access'] as String,
      refreshToken: data['refresh'] as String? ?? refreshToken,
      user: stored.user,
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<dynamic>('/auth/logout', data: {'refresh': refreshToken});
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return;
      _fail(e);
    }
  }

  @override
  Future<ZUser> me() async {
    final data = await _request(() => _dio.get<dynamic>('/auth/me'));
    return ZUser.fromJson(_json(data['user']));
  }

  // --- profile & KYC -----------------------------------------------------------

  @override
  Future<PartnerProfile> profile() async {
    final data = await _request(() => _dio.get<dynamic>('/partner/profile'));
    final profile = PartnerProfile.fromJson(data);
    _online = profile.onlineState != 'offline';
    return profile;
  }

  @override
  Future<PartnerProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    List<String>? languages,
    bool? notificationsEnabled,
  }) async {
    final data = await _request(
      () => _dio.put<dynamic>(
        '/partner/profile',
        data: {
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (phone != null) 'phone': phone,
          if (languages != null) 'languages': languages,
          if (notificationsEnabled != null)
            'notifications_enabled': notificationsEnabled,
        },
      ),
    );
    return PartnerProfile.fromJson(data);
  }

  @override
  Future<void> savePayoutAccount({
    required String holderName,
    required String accountNumber,
    required String ifsc,
  }) async {
    await _request(
      () => _dio.put<dynamic>(
        '/partner/payout-account',
        data: {
          'holder_name': holderName,
          'account_number': accountNumber,
          'ifsc': ifsc,
        },
      ),
    );
  }

  @override
  Future<List<KycDocumentInfo>> documents() async {
    try {
      final response = await _dio.get<dynamic>('/partner/documents');
      final list = response.data as List<dynamic>? ?? const [];
      return [
        for (final row in list)
          KycDocumentInfo.fromJson(row as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<KycDocumentInfo> uploadDocument({
    required KycDocType type,
    String? filePath,
    DateTime? expiresAt,
  }) async {
    if (filePath == null || filePath.isEmpty) {
      throw const ApiException(
        message: 'A document file is required',
        statusCode: 400,
        code: 'validation_error',
      );
    }
    final data = await _request(
      () async => _dio.post<dynamic>(
        '/partner/documents',
        data: FormData.fromMap({
          'type': type.name,
          if (expiresAt != null)
            'expires_at': expiresAt.toIso8601String().split('T').first,
          'file': await MultipartFile.fromFile(filePath),
        }),
      ),
    );
    return KycDocumentInfo.fromJson(data);
  }

  @override
  Future<PartnerProfile> submitKyc() async {
    await _request(() => _dio.post<dynamic>('/partner/kyc/submit'));
    return profile();
  }

  // --- vehicles -----------------------------------------------------------------

  @override
  Future<List<PartnerVehicle>> vehicles() async {
    try {
      final response = await _dio.get<dynamic>('/partner/vehicles');
      final list = response.data as List<dynamic>? ?? const [];
      return [
        for (final row in list)
          PartnerVehicle.fromJson(row as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      _fail(e);
    }
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
    final data = await _request(
      () => _dio.post<dynamic>(
        '/partner/vehicles',
        data: {
          'category': categoryCode,
          'registration_number': registrationNumber,
          'make': make,
          'model': model,
          'color': color,
          if (capacityKg != null) 'capacity_kg': capacityKg,
          if (volumeCuft != null) 'volume_cuft': volumeCuft,
          if (seats != null) 'seats': seats,
        },
      ),
    );
    return PartnerVehicle.fromJson(data);
  }

  @override
  Future<PartnerVehicle> setVehicleAvailability({
    required String vehicleId,
    required bool isActive,
  }) async {
    final data = await _request(
      () => _dio.patch<dynamic>(
        '/partner/vehicles/$vehicleId/availability',
        data: {'is_active': isActive},
      ),
    );
    return PartnerVehicle.fromJson(data);
  }

  // --- availability / location --------------------------------------------------

  @override
  Future<bool> setOnline({required bool online}) async {
    final data = await _request(
      () => _dio.post<dynamic>('/partner/availability', data: {'online': online}),
    );
    _online = (data['online'] as bool?) ?? online;
    return _online;
  }

  @override
  Future<bool> isOnline() async {
    final data = await _request(() => _dio.get<dynamic>('/partner/profile'));
    _online = (data['online_state'] as String? ?? 'offline') != 'offline';
    return _online;
  }

  @override
  Future<void> updateLocation({
    required double lat,
    required double lng,
    double? heading,
    double? speedMps,
    DateTime? recordedAt,
  }) async {
    await _request(
      () => _dio.post<dynamic>(
        '/partner/location',
        data: {
          'lat': lat,
          'lng': lng,
          if (heading != null) 'heading': heading,
          if (speedMps != null) 'speed_mps': speedMps,
          'recorded_at': (recordedAt ?? DateTime.now().toUtc()).toIso8601String(),
        },
      ),
    );
  }

  // --- offers / trips -----------------------------------------------------------

  @override
  Future<List<DriverOffer>> pendingOffers() async {
    try {
      final response = await _dio.get<dynamic>('/partner/offers');
      final list = response.data as List<dynamic>? ?? const [];
      return [
        for (final row in list)
          DriverOffer.fromJson(row as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<PartnerTrip> acceptOffer(String offerId) async {
    final data = await _request(
      () => _dio.post<dynamic>('/partner/offers/$offerId/accept'),
    );
    return PartnerTrip.fromJson(data);
  }

  @override
  Future<void> declineOffer(String offerId, {String? reason}) async {
    await _request(
      () => _dio.post<dynamic>(
        '/partner/offers/$offerId/decline',
        data: {if (reason != null) 'reason': reason},
      ),
    );
  }

  @override
  Future<PartnerTrip?> activeTrip() async {
    final data = await _request(
      () => _dio.get<dynamic>('/partner/bookings/active'),
    );
    final trip = data['trip'];
    if (trip is! Map<String, dynamic>) return null;
    return PartnerTrip.fromJson(trip);
  }

  @override
  Future<RouteInfo> tripRoute(String bookingId, {String leg = 'drop'}) async {
    final data = await _request(
      () => _dio.get<dynamic>(
        '/bookings/$bookingId/route',
        queryParameters: {'leg': leg},
      ),
    );
    return RouteInfo.fromJson(data);
  }

  Future<PartnerTrip> _tripAction(String bookingId, String action) async {
    final data = await _request(
      () => _dio.post<dynamic>('/partner/bookings/$bookingId/$action'),
    );
    return PartnerTrip.fromJson(data);
  }

  @override
  Future<PartnerTrip> arrive(String bookingId) =>
      _tripAction(bookingId, 'arrive');

  @override
  Future<PartnerTrip> verifyOtp({
    required String bookingId,
    required String otp,
  }) async {
    final data = await _request(
      () => _dio.post<dynamic>(
        '/partner/bookings/$bookingId/verify-otp',
        data: {'otp': otp},
      ),
    );
    return PartnerTrip.fromJson(data);
  }

  @override
  Future<PartnerTrip> verifyDeliveryOtp({
    required String bookingId,
    required String otp,
  }) async {
    final data = await _request(
      () => _dio.post<dynamic>(
        '/partner/bookings/$bookingId/verify-delivery-otp',
        data: {'otp': otp},
      ),
    );
    return PartnerTrip.fromJson(data);
  }

  @override
  Future<PartnerTrip> complete(String bookingId) =>
      _tripAction(bookingId, 'complete');

  @override
  Future<void> cancelTrip(String bookingId, {required String reason}) async {
    await _request(
      () => _dio.post<dynamic>(
        '/partner/bookings/$bookingId/cancel',
        data: {'reason': reason},
      ),
    );
  }

  @override
  Future<void> uploadPickupPod({
    required String bookingId,
    required String filePath,
  }) async {
    await _request(
      () async => _dio.post<dynamic>(
        '/partner/bookings/$bookingId/pickup-pod',
        data: FormData.fromMap({
          'photo': await MultipartFile.fromFile(filePath),
        }),
      ),
    );
  }

  @override
  Future<void> uploadDeliveryPod({
    required String bookingId,
    required String receiverName,
    String? photoPath,
    String? signaturePath,
  }) async {
    final form = FormData.fromMap({
      'receiver_name': receiverName,
      if (photoPath != null)
        'photo': await MultipartFile.fromFile(photoPath),
      if (signaturePath != null)
        'signature': await MultipartFile.fromFile(signaturePath),
    });
    await _request(
      () => _dio.post<dynamic>(
        '/partner/bookings/$bookingId/delivery-pod',
        data: form,
      ),
    );
  }

  // --- earnings / payouts -------------------------------------------------------

  @override
  Future<EarningsSummary> earnings(EarningsRange range) async {
    final data = await _request(
      () => _dio.get<dynamic>(
        '/partner/earnings',
        queryParameters: {'range': range.name},
      ),
    );
    return EarningsSummary.fromJson(data);
  }

  @override
  Future<Paged<EarningEntry>> earningTrips({int page = 1}) async {
    final data = await _request(
      () => _dio.get<dynamic>(
        '/partner/earnings/trips',
        queryParameters: {'page': page},
      ),
    );
    final results = (data['results'] as List<dynamic>? ?? const [])
        .map((row) => EarningEntry.fromJson(row as Map<String, dynamic>))
        .toList();
    return Paged(
      results: results,
      count: (data['count'] as num?)?.toInt() ?? results.length,
      next: data['next'] != null,
    );
  }

  @override
  Future<Paged<Payout>> payouts({int page = 1}) async {
    final data = await _request(
      () => _dio.get<dynamic>(
        '/partner/payouts',
        queryParameters: {'page': page},
      ),
    );
    final results = (data['results'] as List<dynamic>? ?? const [])
        .map((row) => Payout.fromJson(row as Map<String, dynamic>))
        .toList();
    return Paged(
      results: results,
      count: (data['count'] as num?)?.toInt() ?? results.length,
      next: data['next'] != null,
    );
  }

  // --- fleet --------------------------------------------------------------------

  @override
  Future<FleetOverview> fleetOverview() async {
    final data = await _request(() => _dio.get<dynamic>('/fleet/overview'));
    return FleetOverview.fromJson(data);
  }

  @override
  Future<List<FleetDriver>> fleetDrivers() async {
    final data = await _request(() => _dio.get<dynamic>('/fleet/drivers'));
    final results = data['results'] as List<dynamic>? ?? const [];
    return [
      for (final row in results)
        FleetDriver.fromJson(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<PartnerVehicle>> fleetVehicles() async {
    try {
      final response = await _dio.get<dynamic>('/fleet/vehicles');
      final list = response.data as List<dynamic>? ?? const [];
      return [
        for (final row in list)
          PartnerVehicle.fromJson(row as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> assignVehicle({
    required String vehicleId,
    required String driverId,
  }) async {
    await _request(
      () => _dio.put<dynamic>(
        '/fleet/vehicles/$vehicleId/assign',
        data: {'driver_id': driverId},
      ),
    );
  }
}
