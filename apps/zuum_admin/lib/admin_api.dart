import 'dart:typed_data';

import 'package:dio/dio.dart';

const adminApiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://zuum-api.onrender.com/api/v1',
);

double? _double(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _int(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

class AdminApiException implements Exception {
  const AdminApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;

  String get fullName => '$firstName $lastName'.trim();
  String get initials {
    final value =
        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}';
    return value.isEmpty ? email[0].toUpperCase() : value.toUpperCase();
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: '${json['id'] ?? ''}',
        email: '${json['email'] ?? ''}',
        firstName: '${json['first_name'] ?? ''}',
        lastName: '${json['last_name'] ?? ''}',
        role: '${json['role'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
      };
}

class AdminSession {
  const AdminSession({
    required this.access,
    required this.refresh,
    required this.user,
  });

  final String access;
  final String refresh;
  final AdminUser user;

  factory AdminSession.fromJson(Map<String, dynamic> json) => AdminSession(
        access: '${json['access'] ?? ''}',
        refresh: '${json['refresh'] ?? ''}',
        user: AdminUser.fromJson(
          (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}

class OpsOverview {
  const OpsOverview({
    required this.bookingsToday,
    required this.completedToday,
    required this.onlineDrivers,
    required this.driversTotal,
    required this.pendingKyc,
    required this.revenueTodayPaise,
    required this.commissionTodayPaise,
    required this.openTickets,
    required this.activeSos,
    required this.payoutsPendingPaise,
    required this.activeByStatus,
  });

  final int bookingsToday;
  final int completedToday;
  final int onlineDrivers;
  final int driversTotal;
  final int pendingKyc;
  final int revenueTodayPaise;
  final int commissionTodayPaise;
  final int openTickets;
  final int activeSos;
  final int payoutsPendingPaise;
  final Map<String, int> activeByStatus;

  factory OpsOverview.fromJson(Map<String, dynamic> json) {
    final statuses = <String, int>{};
    final raw = json['active_by_status'];
    if (raw is Map) {
      raw.forEach((key, value) => statuses['$key'] = _int(value));
    }
    return OpsOverview(
      bookingsToday: _int(json['bookings_today']),
      completedToday: _int(json['completed_today']),
      onlineDrivers: _int(json['online_drivers']),
      driversTotal: _int(json['drivers_total']),
      pendingKyc: _int(json['pending_kyc']),
      revenueTodayPaise: _int(json['revenue_today_paise']),
      commissionTodayPaise: _int(json['commission_today_paise']),
      openTickets: _int(json['open_tickets']),
      activeSos: _int(json['active_sos']),
      payoutsPendingPaise: _int(json['payouts_pending_paise']),
      activeByStatus: statuses,
    );
  }

  int status(String key) => activeByStatus[key.toLowerCase()] ?? 0;
}

class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.trips,
    required this.revenuePaise,
    required this.commissionPaise,
  });

  final DateTime date;
  final int trips;
  final int revenuePaise;
  final int commissionPaise;

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
        date: _date(json['date']) ?? DateTime.now(),
        trips: _int(json['trips']),
        revenuePaise: _int(json['revenue_paise']),
        commissionPaise: _int(json['commission_paise']),
      );
}

class CategorySlice {
  const CategorySlice({
    required this.name,
    required this.trips,
    required this.revenuePaise,
  });

  final String name;
  final int trips;
  final int revenuePaise;

  factory CategorySlice.fromJson(Map<String, dynamic> json) => CategorySlice(
        name: '${json['name'] ?? 'Other'}',
        trips: _int(json['trips']),
        revenuePaise: _int(json['revenue_paise']),
      );
}

class OpsAnalytics {
  const OpsAnalytics({
    required this.series,
    required this.trips,
    required this.revenuePaise,
    required this.commissionPaise,
    required this.driverPaise,
    required this.topCategories,
  });

  final List<TrendPoint> series;
  final int trips;
  final int revenuePaise;
  final int commissionPaise;
  final int driverPaise;
  final List<CategorySlice> topCategories;

  factory OpsAnalytics.fromJson(Map<String, dynamic> json) {
    final totals = (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OpsAnalytics(
      series: [
        for (final row in (json['series'] as List? ?? const []))
          TrendPoint.fromJson((row as Map).cast<String, dynamic>()),
      ],
      trips: _int(totals['trips']),
      revenuePaise: _int(totals['revenue_paise']),
      commissionPaise: _int(totals['commission_paise']),
      driverPaise: _int(totals['driver_paise']),
      topCategories: [
        for (final row in (json['top_categories'] as List? ?? const []))
          CategorySlice.fromJson((row as Map).cast<String, dynamic>()),
      ],
    );
  }
}

class OpsBooking {
  const OpsBooking({
    required this.id,
    required this.type,
    required this.status,
    required this.serviceCategory,
    required this.customer,
    required this.driver,
    required this.pickup,
    required this.drop,
    required this.distanceM,
    required this.farePaise,
    required this.paymentState,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String status;
  final String serviceCategory;
  final String customer;
  final String? driver;
  final String pickup;
  final String drop;
  final int distanceM;
  final int farePaise;
  final String paymentState;
  final DateTime? createdAt;

  factory OpsBooking.fromJson(Map<String, dynamic> json) => OpsBooking(
        id: '${json['id'] ?? ''}',
        type: '${json['type'] ?? ''}',
        status: '${json['status'] ?? ''}',
        serviceCategory: '${json['service_category'] ?? ''}',
        customer: '${json['customer'] ?? ''}',
        driver: json['driver'] as String?,
        pickup: '${json['pickup'] ?? ''}',
        drop: '${json['drop'] ?? ''}',
        distanceM: _int(json['distance_m']),
        farePaise: _int(json['fare_paise']),
        paymentState: '${json['payment_state'] ?? ''}',
        createdAt: _date(json['created_at']),
      );
}

class OpsDriver {
  const OpsDriver({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.kycStatus,
    required this.approvalStatus,
    required this.onlineState,
    required this.rating,
    required this.ratingCount,
    required this.vehicles,
    required this.documents,
    required this.fleet,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String kycStatus;
  final String approvalStatus;
  final String onlineState;
  final double rating;
  final int ratingCount;
  final List<String> vehicles;
  final int documents;
  final String? fleet;
  final DateTime? createdAt;

  bool get isPendingKyc => kycStatus == 'submitted';
  bool get isApproved => approvalStatus == 'active';
  bool get isSuspended => approvalStatus == 'suspended';

  factory OpsDriver.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map?)?.cast<String, dynamic>() ?? const {};
    final vehicles = <String>[
      for (final v in (json['vehicles'] as List? ?? const []))
        '${(v as Map)['registration_number'] ?? ''} · ${v['category_name'] ?? ''}',
    ];
    final documents = json['documents'] as List? ?? const [];
    return OpsDriver(
      id: '${json['id'] ?? ''}',
      name: '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim(),
      email: '${user['email'] ?? ''}',
      phone: '${user['phone'] ?? ''}',
      kycStatus: '${json['kyc_status'] ?? ''}',
      approvalStatus: '${json['approval_status'] ?? ''}',
      onlineState: '${json['online_state'] ?? 'offline'}',
      rating: _double(json['rating_avg']) ?? 0,
      ratingCount: _int(json['rating_count']),
      vehicles: vehicles,
      documents: _int(json['document_count'], documents.length),
      fleet: json['fleet'] as String?,
      createdAt: _date(json['created_at']),
    );
  }
}

class OpsDocument {
  const OpsDocument({
    required this.id,
    required this.type,
    required this.status,
    required this.expiresAt,
    required this.reviewedAt,
    required this.reviewNote,
    required this.fileAvailable,
    required this.fileName,
  });

  final String id;
  final String type;
  final String status;
  final DateTime? expiresAt;
  final DateTime? reviewedAt;
  final String reviewNote;
  final bool fileAvailable;
  final String fileName;

  String get label {
    const labels = {
      'licence': 'Driving licence',
      'rc': 'Vehicle RC',
      'insurance': 'Insurance',
      'puc': 'PUC certificate',
      'profile_photo': 'Profile photo',
      'vehicle_photo': 'Vehicle photo',
    };
    return labels[type] ?? _title(type);
  }

  static String _title(String value) => value
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  factory OpsDocument.fromJson(Map<String, dynamic> json) => OpsDocument(
        id: '${json['id'] ?? ''}',
        type: '${json['type'] ?? ''}',
        status: '${json['status'] ?? ''}',
        expiresAt: _date(json['expires_at']),
        reviewedAt: _date(json['reviewed_at']),
        reviewNote: '${json['review_note'] ?? ''}',
        fileAvailable: json['file_available'] == true,
        fileName: '${json['file_name'] ?? ''}',
      );
}

class OpsDriverDetail {
  const OpsDriverDetail({required this.driver, required this.documents});
  final OpsDriver driver;
  final List<OpsDocument> documents;

  bool get documentsVerified =>
      documents.length >= 3 &&
      documents
          .where((doc) =>
              const {'licence', 'rc', 'insurance'}.contains(doc.type))
          .every((doc) => doc.status == 'verified');

  factory OpsDriverDetail.fromJson(Map<String, dynamic> json) =>
      OpsDriverDetail(
        driver: OpsDriver.fromJson(
          (json['driver'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        documents: [
          for (final row in (json['documents'] as List? ?? const []))
            OpsDocument.fromJson((row as Map).cast<String, dynamic>()),
        ],
      );
}

class OpsPayout {
  const OpsPayout({
    required this.id,
    required this.driver,
    required this.driverEmail,
    required this.amountPaise,
    required this.status,
    required this.method,
    required this.batchRef,
    required this.createdAt,
  });

  final String id;
  final String driver;
  final String driverEmail;
  final int amountPaise;
  final String status;
  final String method;
  final String? batchRef;
  final DateTime? createdAt;

  factory OpsPayout.fromJson(Map<String, dynamic> json) => OpsPayout(
        id: '${json['id'] ?? ''}',
        driver: '${json['driver'] ?? ''}',
        driverEmail: '${json['driver_email'] ?? ''}',
        amountPaise: _int(json['amount_paise']),
        status: '${json['status'] ?? ''}',
        method: '${json['method'] ?? ''}',
        batchRef: json['batch_ref'] as String?,
        createdAt: _date(json['created_at']),
      );
}

class OpsTicket {
  const OpsTicket({
    required this.id,
    required this.customer,
    required this.bookingId,
    required this.category,
    required this.subject,
    required this.status,
    required this.priority,
    required this.createdAt,
  });

  final String id;
  final String customer;
  final String? bookingId;
  final String category;
  final String subject;
  final String status;
  final String priority;
  final DateTime? createdAt;

  factory OpsTicket.fromJson(Map<String, dynamic> json) => OpsTicket(
        id: '${json['id'] ?? ''}',
        customer: '${json['customer'] ?? ''}',
        bookingId: json['booking_id'] as String?,
        category: '${json['category'] ?? ''}',
        subject: '${json['subject'] ?? ''}',
        status: '${json['status'] ?? ''}',
        priority: '${json['priority'] ?? ''}',
        createdAt: _date(json['created_at']),
      );
}

class OpsFinance {
  const OpsFinance({
    required this.trips,
    required this.grossPaise,
    required this.commissionPaise,
    required this.driverPaise,
    required this.pendingPaise,
    required this.paidPaise,
  });

  final int trips;
  final int grossPaise;
  final int commissionPaise;
  final int driverPaise;
  final int pendingPaise;
  final int paidPaise;

  factory OpsFinance.fromJson(Map<String, dynamic> json) => OpsFinance(
        trips: _int(json['trips']),
        grossPaise: _int(json['gross_paise']),
        commissionPaise: _int(json['commission_paise']),
        driverPaise: _int(json['driver_paise']),
        pendingPaise: _int(json['payouts_pending_paise']),
        paidPaise: _int(json['payouts_paid_paise']),
      );
}

class OpsPage<T> {
  const OpsPage({required this.count, required this.results});
  final int count;
  final List<T> results;
}

class AdminApi {
  AdminApi({String? token, Dio? dio})
      : _token = token,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: adminApiBase,
                connectTimeout: const Duration(seconds: 25),
                receiveTimeout: const Duration(seconds: 30),
                headers: {'Accept': 'application/json'},
              ),
            );

  final Dio _dio;
  String? _token;
  String? _refreshToken;
  Future<bool>? _refreshing;
  Future<void> Function(String access, String refresh)? onTokens;
  Future<void> Function()? onExpired;

  void setSession({String? access, String? refresh}) {
    _token = access;
    _refreshToken = refresh;
  }

  void setToken(String? token) => _token = token;

  Options _authOptions({ResponseType? responseType}) => Options(
        responseType: responseType,
        headers: {
          if (_token != null && _token!.isNotEmpty)
            'Authorization': 'Bearer $_token',
        },
      );

  Future<Response<T>> _withAuth<T>(
    Future<Response<T>> Function(Options options) send,
  ) async {
    try {
      return await send(_authOptions());
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && await _tryRefresh()) {
        return send(_authOptions());
      }
      rethrow;
    }
  }

  Future<bool> _tryRefresh() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final future = _doRefresh();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) {
      await onExpired?.call();
      return false;
    }
    try {
      final res = await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh': refresh},
      );
      final data = _map(res.data);
      final access = '${data['access'] ?? ''}';
      final nextRefresh = '${data['refresh'] ?? refresh}';
      if (access.isEmpty) {
        await onExpired?.call();
        return false;
      }
      _token = access;
      _refreshToken = nextRefresh;
      await onTokens?.call(access, nextRefresh);
      return true;
    } catch (_) {
      await onExpired?.call();
      return false;
    }
  }

  Future<void> logout() async {
    final refresh = _refreshToken;
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _dio.post<dynamic>(
          '/auth/logout',
          data: {'refresh': refresh},
          options: _authOptions(),
        );
      }
    } catch (_) {
      // Local session is cleared regardless.
    }
    _token = null;
    _refreshToken = null;
  }

  Future<AdminSession> login(String email, String password) async {
    try {
      final res = await _dio.post<dynamic>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      return AdminSession.fromJson(_map(res.data));
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  Future<AdminUser> me() async {
    try {
      final res = await _withAuth<dynamic>(
        (options) => _dio.get<dynamic>('/auth/me', options: options),
      );
      final data = _map(res.data);
      return AdminUser.fromJson(_map(data['user']));
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  Future<OpsOverview> overview() async {
    final data = await _get('/ops/overview');
    return OpsOverview.fromJson(data);
  }

  Future<OpsAnalytics> analytics({String range = 'week'}) async {
    final data = await _get('/ops/analytics', query: {'range': range});
    return OpsAnalytics.fromJson(data);
  }

  Future<OpsPage<OpsBooking>> bookings({
    String? status,
    String search = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _get(
      '/ops/bookings',
      query: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (search.trim().isNotEmpty) 'q': search.trim(),
        'page': page,
        'page_size': pageSize,
      },
    );
    return OpsPage(
      count: _int(data['count']),
      results: [
        for (final row in (data['results'] as List? ?? const []))
          OpsBooking.fromJson(_map(row)),
      ],
    );
  }

  Future<void> cancelBooking(String id, {String reason = 'Cancelled by operations'}) async {
    await _post('/ops/bookings/$id/cancel', data: {'reason': reason});
  }

  Future<OpsPage<OpsDriver>> drivers({
    String? kyc,
    String? approval,
    String search = '',
    int page = 1,
    int pageSize = 25,
  }) async {
    final data = await _get(
      '/ops/drivers',
      query: {
        if (kyc != null && kyc.isNotEmpty) 'kyc': kyc,
        if (approval != null && approval.isNotEmpty) 'approval': approval,
        if (search.trim().isNotEmpty) 'q': search.trim(),
        'page': page,
        'page_size': pageSize,
      },
    );
    return OpsPage(
      count: _int(data['count']),
      results: [
        for (final row in (data['results'] as List? ?? const []))
          OpsDriver.fromJson(_map(row)),
      ],
    );
  }

  Future<void> approveDriver(String id) => _post('/ops/drivers/$id/approve');
  Future<void> rejectDriver(String id, String reason) =>
      _post('/ops/drivers/$id/reject', data: {'reason': reason});
  Future<void> suspendDriver(String id) => _post('/ops/drivers/$id/suspend');

  Future<OpsDriverDetail> driverDetail(String id) async {
    final data = await _get('/ops/drivers/$id');
    return OpsDriverDetail.fromJson(data);
  }

  Future<OpsDocument> reviewDocument({
    required String id,
    required String status,
    String note = '',
  }) async {
    final data = await _post(
      '/ops/documents/$id/review',
      data: {'status': status, 'note': note},
    );
    return OpsDocument.fromJson(data);
  }

  Future<Uint8List?> documentBytes(String id) async {
    try {
      final response = await _withAuth<List<int>>(
        (options) => _dio.get<List<int>>(
          '/ops/documents/$id/file',
          options: options.copyWith(responseType: ResponseType.bytes),
        ),
      );
      final bytes = response.data;
      return bytes == null ? null : Uint8List.fromList(bytes);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw _failure(e);
    }
  }

  Future<OpsFinance> finance({String range = 'today'}) async {
    final data = await _get('/ops/finance/summary', query: {'range': range});
    return OpsFinance.fromJson(data);
  }

  Future<OpsPage<OpsPayout>> payouts({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = await _get(
      '/ops/payouts',
      query: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'page_size': pageSize,
      },
    );
    return OpsPage(
      count: _int(data['count']),
      results: [
        for (final row in (data['results'] as List? ?? const []))
          OpsPayout.fromJson(_map(row)),
      ],
    );
  }

  Future<void> markPayoutPaid(String id) => _post('/ops/payouts/$id/mark-paid');

  Future<OpsPage<OpsTicket>> tickets({String? status, int page = 1}) async {
    final data = await _get(
      '/ops/tickets',
      query: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'page_size': 25,
      },
    );
    return OpsPage(
      count: _int(data['count']),
      results: [
        for (final row in (data['results'] as List? ?? const []))
          OpsTicket.fromJson(_map(row)),
      ],
    );
  }

  Future<Map<String, dynamic>> ticket(String id) => _get('/ops/tickets/$id');
  Future<void> replyTicket(String id, String message, {String? status}) =>
      _post(
        '/ops/tickets/$id',
        data: {
          'message': message,
          if (status != null) 'status': status,
        },
      );

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final res = await _withAuth<dynamic>(
        (options) => _dio.get<dynamic>(
          path,
          queryParameters: query,
          options: options,
        ),
      );
      return _map(res.data);
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final res = await _withAuth<dynamic>(
        (options) => _dio.post<dynamic>(path, data: data, options: options),
      );
      return _map(res.data);
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }

  static AdminApiException _failure(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String message = 'Could not reach Zuum ops';
    if (data is Map) {
      final raw = data['message'] ?? data['detail'];
      if (raw != null) message = '$raw';
    } else if (status == 401 || status == 403) {
      message = 'Your session expired. Sign in again.';
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Ops API timed out. Retry.';
    }
    return AdminApiException(message, statusCode: status);
  }
}
