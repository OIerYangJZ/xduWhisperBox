class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  final String message;
  final int? statusCode;
  final dynamic data;

  @override
  String toString() {
    final int? code = statusCode;
    if (code == null) {
      return 'ApiException: $message';
    }
    return 'ApiException($code): $message';
  }
}
