import 'package:dio/dio.dart';

/// Structured exception for API errors.
///
/// Replaces raw `throw 'some string'` and `errorStr.contains('403')` patterns
/// with a typed exception that UI code can switch on cleanly.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final Map<String, dynamic>? validationErrors;

  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.validationErrors,
  });

  /// Convenience constructors for common error types.
  const ApiException.forbidden([String message = 'You do not have permission to access this resource.'])
      : this(message: message, statusCode: 403, errorCode: 'FORBIDDEN');

  const ApiException.unauthorized([String message = 'Your session has expired. Please log in again.'])
      : this(message: message, statusCode: 401, errorCode: 'UNAUTHORIZED');

  const ApiException.notFound([String message = 'The requested resource was not found.'])
      : this(message: message, statusCode: 404, errorCode: 'NOT_FOUND');

  const ApiException.network([String message = 'Could not connect to the server. Please check your network connection.'])
      : this(message: message, statusCode: null, errorCode: 'NETWORK_ERROR');

  const ApiException.server([String message = 'An unexpected server error occurred. Please try again later.'])
      : this(message: message, statusCode: 500, errorCode: 'SERVER_ERROR');

  // ── Type checks ──────────────────────────────────────────

  bool get isForbidden => statusCode == 403;
  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 422;
  bool get isServerError => statusCode != null && statusCode! >= 500;
  bool get isNetworkError => errorCode == 'NETWORK_ERROR';

  // ── Universal normaliser ─────────────────────────────────

  /// Normalise ANY caught object into a friendly [ApiException].
  ///
  /// Use this in catch blocks and UI error branches so a raw [DioException],
  /// `SocketException`, or a stray `e.toString()` string never reaches the
  /// user. Crucially it also re-cleans an [ApiException] whose `message` is a
  /// raw transport dump (some older repos build `message: e.toString()`), which
  /// is exactly what a weak/slow network used to surface.
  factory ApiException.from(Object error) {
    if (error is ApiException) {
      return _looksLikeRawDump(error.message) ? _friendlyFromText(error.message) : error;
    }
    if (error is DioException) return ApiException.fromDioException(error);
    return _friendlyFromText(error.toString());
  }

  static bool _looksLikeRawDump(String s) {
    return s.contains('DioException') ||
        s.contains('SocketException') ||
        s.contains('HandshakeException') ||
        s.contains('Connection closed') ||
        s.contains('Connection reset') ||
        s.contains('Software caused connection abort') ||
        s.contains('errno =') ||
        s.contains('#0 ');
  }

  /// Map a free-text error into a friendly typed message. Network-ish text
  /// becomes a connection error; anything else becomes a neutral retry message
  /// (never the raw string).
  static ApiException _friendlyFromText(String s) {
    final lower = s.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('connection') ||
        lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('network') ||
        lower.contains('handshake') ||
        lower.contains('unreachable') ||
        lower.contains('failed host lookup')) {
      return const ApiException.network();
    }
    return const ApiException.server('Something went wrong. Please try again.');
  }

  // ── Factory from DioException ────────────────────────────

  /// Convert a [DioException] into a structured [ApiException].
  /// This is the primary entry point — call this in repository catch blocks.
  factory ApiException.fromDioException(DioException e) {
    final response = e.response;
    final data = response?.data;
    final statusCode = response?.statusCode;

    // Network-level errors (no response received)
    if (response == null) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return const ApiException.network('Connection timed out. Please try again.');
      }
      if (e.type == DioExceptionType.connectionError) {
        return const ApiException.network();
      }
      return ApiException(
        message: e.message ?? 'An unknown network error occurred.',
        errorCode: 'NETWORK_ERROR',
      );
    }

    // Extract message from various Laravel response formats
    String message = 'An unexpected error occurred.';
    Map<String, dynamic>? validationErrors;

    if (data is Map) {
      // Laravel validation errors: { "errors": { "field": ["message"] } }
      if (data.containsKey('errors') && data['errors'] is Map) {
        validationErrors = Map<String, dynamic>.from(data['errors']);
        // Use the first validation error as the main message
        final firstErrors = validationErrors.values.first;
        if (firstErrors is List && firstErrors.isNotEmpty) {
          message = firstErrors.first.toString();
        }
      }
      // Standard Laravel error: { "message": "..." }
      else if (data.containsKey('message')) {
        message = data['message'].toString();
      }
      // Simple error: { "error": "..." }
      else if (data.containsKey('error')) {
        message = data['error'].toString();
      }
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      errorCode: statusCode == 403
          ? 'FORBIDDEN'
          : statusCode == 401
              ? 'UNAUTHORIZED'
              : statusCode == 404
                  ? 'NOT_FOUND'
                  : statusCode == 422
                      ? 'VALIDATION_ERROR'
                      : 'SERVER_ERROR',
      validationErrors: validationErrors,
    );
  }

  @override
  String toString() => message;
}
