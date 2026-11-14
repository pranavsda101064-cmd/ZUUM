class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final dynamic details;

  bool get isNetwork => statusCode == null && code == 'network_error';
  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => statusCode == 400 || statusCode == 422;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
