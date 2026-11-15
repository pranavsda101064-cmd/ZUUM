import 'package:dio/dio.dart';

import '../models/models.dart';
import '../places/place_search.dart';
import '../realtime/realtime_service.dart';
import '../storage/token_storage.dart';
import 'api_contract.dart';
import 'api_exception.dart';

/// Live API implementation. Talks to `/api/v1` per `docs/03_api_contract.md`.
///
/// - Attaches `Authorization: Bearer` when a session is stored.
/// - Single-flight refresh on 401 (`token_not_valid`), then retries once.
class ApiClient implements ApiContract {
  ApiClient({required String baseUrl, required TokenStorage tokenStorage})
      : _storage = tokenStorage {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    )..interceptors.add(
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
            if (status == 401 && !retried) {
              final refreshed = await _tryRefresh();
              if (refreshed) {
                final opts = error.requestOptions
                  ..extra['retried'] = true;
                final session = await _storage.readSession();
                if (session != null) {
                  opts.headers['Authorization'] = 'Bearer ${session.accessToken}';
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

  // --- helpers ---------------------------------------------------------------

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
      await _storage.clear();
      return false;
    }
  }

  Never _fail(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      throw ApiException(
        message: data['message'] as String? ?? 'Request failed',
        statusCode: error.response?.statusCode,
        code: data['code'] as String?,
        details: data['details'],
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.receiveTimeout) {
      throw const ApiException(message: 'No internet connection', code: 'network_error');
    }
    throw ApiException(
      message: error.message ?? 'Request failed',
      statusCode: error.response?.statusCode,
      code: 'unknown',
    );
  }

  Map<String, dynamic> _json(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const ApiException(message: 'Malformed server response', code: 'bad_response');
  }

  // --- auth ------------------------------------------------------------------

  @override
  Future<Session> login({required String email, required String password}) async {
    try {
      final res = await _dio.post<dynamic>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return Session.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<Session> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );
      return Session.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<Session> refresh(String refreshToken) async {
    try {
      final res = await _dio.post<dynamic>('/auth/refresh', data: {'refresh': refreshToken});
      final json = _json(res.data);
      // Server may omit `user` on refresh — keep the stored one.
      if (json.containsKey('user')) return Session.fromJson(json);
      final stored = await _storage.readSession();
      return Session(
        accessToken: json['access'] as String,
        refreshToken: json['refresh'] as String? ?? refreshToken,
        user: stored!.user,
      );
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<dynamic>('/auth/logout', data: {'refresh': refreshToken});
    } on DioException catch (e) {
      // Logout is best-effort; local session is cleared by the caller.
      if (e.response?.statusCode == 401) return;
      _fail(e);
    }
  }

  @override
  Future<ZUser> me() async {
    try {
      final res = await _dio.get<dynamic>('/auth/me');
      return ZUser.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _dio.post<dynamic>('/auth/password/forgot', data: {'email': email});
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> resetPassword({required String token, required String password}) async {
    try {
      await _dio.post<dynamic>(
        '/auth/password/reset',
        data: {'token': token, 'password': password},
      );
    } on DioException catch (e) {
      _fail(e);
    }
  }

  // --- profile & addresses ----------------------------------------------------

  @override
  Future<List<SavedAddress>> savedAddresses() async {
    try {
      final res = await _dio.get<dynamic>('/customers/me/addresses');
      return _asListOfMaps(res.data)
          .map(SavedAddress.fromJson)
          .toList();
    } on DioException catch (e) {
      _fail(e);
    }
  }

  /// Accepts either a bare JSON list or a DRF paged envelope `{results: [...]}`.
  List<Map<String, dynamic>> _asListOfMaps(Object? data) {
    if (data is List) {
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    if (data is Map<String, dynamic> && data['results'] is List) {
      return (data['results'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    return const [];
  }

  @override
  Future<SavedAddress> createSavedAddress({
    required String label,
    required String name,
    required double lat,
    required double lng,
    required String address,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/customers/me/addresses',
        data: {'label': label, 'name': name, 'lat': lat, 'lng': lng, 'address': address},
      );
      return SavedAddress.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> deleteSavedAddress(String id) async {
    try {
      await _dio.delete<dynamic>('/customers/me/addresses/$id');
    } on DioException catch (e) {
      _fail(e);
    }
  }

  // --- catalog & pricing -------------------------------------------------------

  @override
  Future<List<ServiceCategory>> serviceCategories({
    required String city,
    required ServiceKind kind,
  }) async {
    try {
      final res = await _dio.get<dynamic>(
        '/service-categories',
        queryParameters: {'city': city, 'kind': kind == ServiceKind.goods ? 'goods' : 'ride'},
      );
      return _asListOfMaps(res.data).map(ServiceCategory.fromJson).toList();
    } on DioException catch (e) {
      _fail(e);
    }
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
    try {
      final res = await _dio.post<dynamic>(
        '/pricing/quote',
        data: {
          'kind': kind == ServiceKind.goods ? 'goods' : 'ride',
          'service_category': serviceCategory,
          'pickup': {'lat': pickup.lat, 'lng': pickup.lng},
          'drop': {'lat': drop.lat, 'lng': drop.lng},
          if (weightKg != null) 'weight_kg': weightKg,
          'needs_loading_help': needsLoadingHelp,
        },
      );
      return FareQuote.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
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
    try {
      final res = await _dio.post<dynamic>(
        '/bookings',
        data: {
          'quote_id': quoteId,
          'service_category': serviceCategory,
          'pickup': {'lat': pickup.lat, 'lng': pickup.lng, 'address': pickup.address},
          'drop': {'lat': drop.lat, 'lng': drop.lng, 'address': drop.address},
          'payment_method': paymentMethod.name,
          if (scheduledAt != null) 'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
          if (note != null && note.isNotEmpty) 'note': note,
          if (goodsType != null) 'goods_type': goodsType,
          if (weightKg != null) 'weight_kg': weightKg,
          if (dimensionsCuft != null) 'dimensions_cuft': dimensionsCuft,
          'needs_loading_help': needsLoadingHelp,
          if (senderName != null) 'sender_name': senderName,
          if (senderPhone != null) 'sender_phone': senderPhone,
          if (receiverName != null) 'receiver_name': receiverName,
          if (receiverPhone != null) 'receiver_phone': receiverPhone,
        },
      );
      return Booking.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<Paged<Booking>> bookings({int page = 1, String? status}) async {
    try {
      final res = await _dio.get<dynamic>(
        '/bookings',
        queryParameters: {
          'page': page,
          if (status != null) 'status': status,
        },
      );
      return Paged.fromJson(_json(res.data), Booking.fromJson);
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<Booking> booking(String id) async {
    try {
      final res = await _dio.get<dynamic>('/bookings/$id');
      return Booking.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<DriverLocation?> bookingLocation(String bookingId) async {
    try {
      final res = await _dio.get<dynamic>('/bookings/$bookingId/location');
      final json = _json(res.data);
      return DriverLocation(
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0,
        heading: (json['heading'] as num?)?.toDouble() ?? 0,
        recordedAt: DateTime.tryParse(json['recorded_at'] as String? ?? '') ??
            DateTime.now(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 409) {
        return null;
      }
      _fail(e);
    }
  }

  @override
  Future<void> submitPod({
    required String bookingId,
    required String receiverName,
    required String otp,
    String? photoPath,
    String? signaturePath,
  }) async {
    final form = FormData.fromMap({
      'receiver_name': receiverName,
      'otp': otp,
      if (photoPath != null)
        'photo': await MultipartFile.fromFile(
          photoPath,
          contentType: DioMediaType('image', 'jpeg'),
        ),
      if (signaturePath != null)
        'signature': await MultipartFile.fromFile(
          signaturePath,
          contentType: DioMediaType('image', 'png'),
        ),
    });
    try {
      await _dio.post<dynamic>('/bookings/$bookingId/pod', data: form);
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    required double lat,
    required double lng,
    int limit = 8,
  }) async {
    try {
      final res = await _dio.get<dynamic>(
        '/places/search',
        queryParameters: {
          'q': query,
          'lat': lat,
          'lng': lng,
          'limit': limit,
        },
      );
      final rows = (_json(res.data)['results'] as List<dynamic>?) ?? const [];
      return [
        for (final row in rows)
          PlaceSuggestion.fromJson(row as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<PlaceSuggestion?> reversePlace({
    required double lat,
    required double lng,
  }) async {
    try {
      final res = await _dio.get<dynamic>(
        '/places/reverse',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      return PlaceSuggestion.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<RouteInfo> bookingRoute(String bookingId, {String leg = 'drop'}) async {
    try {
      final res = await _dio.get<dynamic>(
        '/bookings/$bookingId/route',
        queryParameters: {'leg': leg},
      );
      return RouteInfo.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> cancelBooking(String id, {required String reason}) async {
    try {
      await _dio.post<dynamic>('/bookings/$id/cancel', data: {'reason': reason});
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> verifyOtp({required String bookingId, required String otp}) async {
    try {
      await _dio.post<dynamic>(
        '/bookings/$bookingId/otp/verify',
        data: {'otp': otp},
      );
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<Booking> payBooking({
    required String bookingId,
    required PaymentMethod method,
    int tipPaise = 0,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/bookings/$bookingId/pay',
        data: {'payment_method': method.name, 'tip_paise': tipPaise},
      );
      return Booking.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  // --- payments & wallet ----------------------------------------------------------

  @override
  Future<Wallet> wallet() async {
    try {
      final res = await _dio.get<dynamic>('/wallet');
      return Wallet.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<Wallet> topUpWallet({
    required int amountPaise,
    required PaymentMethod method,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/wallet/topup',
        data: {'amount_paise': amountPaise, 'payment_method': method.name},
      );
      return Wallet.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<Paged<WalletTransaction>> walletTransactions({int page = 1}) async {
    try {
      final res = await _dio.get<dynamic>(
        '/wallet/transactions',
        queryParameters: {'page': page},
      );
      return Paged.fromJson(_json(res.data), WalletTransaction.fromJson);
    } on DioException catch (e) {
      _fail(e);
    }
  }

  // --- promos & reviews -----------------------------------------------------------

  @override
  Future<List<PromoCampaign>> activePromos() async {
    try {
      final res = await _dio.get<dynamic>('/promos/active');
      return _asListOfMaps(res.data).map(PromoCampaign.fromJson).toList();
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<PromoCampaign> validatePromo({
    required String code,
    required int farePaise,
    required String serviceCategory,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/promos/validate',
        data: {
          'code': code,
          'fare_paise': farePaise,
          'service_category': serviceCategory,
        },
      );
      return PromoCampaign.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> createReview({
    required String bookingId,
    required int rating,
    String? comment,
    List<String>? tags,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/bookings/$bookingId/rate',
        data: {
          'rating': rating,
          if (comment != null) 'comment': comment,
          if (tags != null) 'tags': tags,
        },
      );
    } on DioException catch (e) {
      _fail(e);
    }
  }

  // --- notifications ----------------------------------------------------------------

  @override
  Future<Paged<ZNotification>> notifications({int page = 1}) async {
    try {
      final res = await _dio.get<dynamic>(
        '/notifications',
        queryParameters: {'page': page},
      );
      return Paged.fromJson(_json(res.data), ZNotification.fromJson);
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> markNotificationRead(String id) async {
    try {
      await _dio.post<dynamic>('/notifications/$id/read');
    } on DioException catch (e) {
      _fail(e);
    }
  }

  // --- support & safety ---------------------------------------------------------------

  @override
  Future<List<SupportTopic>> supportTopics() async {
    try {
      final res = await _dio.get<dynamic>('/support/topics');
      return _asListOfMaps(res.data).map(SupportTopic.fromJson).toList();
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<Paged<SupportTicket>> supportTickets() async {
    try {
      final res = await _dio.get<dynamic>('/support/tickets');
      return Paged.fromJson(_json(res.data), SupportTicket.fromJson);
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<SupportTicket> createSupportTicket({
    required String subject,
    required String category,
    required String body,
    String? bookingId,
  }) async {
    try {
      final res = await _dio.post<dynamic>(
        '/support/tickets',
        data: {
          'subject': subject,
          'category': category,
          'body': body,
          if (bookingId != null) 'booking_id': bookingId,
        },
      );
      return SupportTicket.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<void> sendSos({
    required String bookingId,
    double? lat,
    double? lng,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/safety/sos',
        data: {
          'booking_id': bookingId,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        },
      );
    } on DioException catch (e) {
      _fail(e);
    }
  }

  @override
  Future<ZUser> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      final res = await _dio.put<dynamic>(
        '/customers/me',
        data: {
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (phone != null) 'phone': phone,
        },
      );
      return ZUser.fromJson(_json(res.data));
    } on DioException catch (e) {
      _fail(e);
    }
  }
}
