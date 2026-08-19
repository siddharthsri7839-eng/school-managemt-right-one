import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';

/// Guards the friendly-error normaliser that keeps raw transport dumps off the
/// screen on slow / weak networks.
void main() {
  final dummyReq = RequestOptions(path: '/x');

  group('ApiException.from', () {
    test('connection timeout becomes a friendly network error', () {
      final e = DioException(
        requestOptions: dummyReq,
        type: DioExceptionType.receiveTimeout,
      );
      final result = ApiException.from(e);
      expect(result.isNetworkError, isTrue);
      expect(result.message.toLowerCase(), contains('connect'));
      expect(result.message, isNot(contains('DioException')));
    });

    test('connection error becomes a network error', () {
      final e = DioException(
        requestOptions: dummyReq,
        type: DioExceptionType.connectionError,
      );
      expect(ApiException.from(e).isNetworkError, isTrue);
    });

    test('re-cleans an ApiException whose message is a raw Dio dump', () {
      // This is the exact shape some older repos produced: message: e.toString()
      final poisoned = ApiException(
        message: 'DioException [receive timeout]: The request connection took '
            'longer than 0:00:30.000000 and it was aborted.',
        statusCode: 500,
      );
      final cleaned = ApiException.from(poisoned);
      expect(cleaned.message, isNot(contains('DioException')));
      expect(cleaned.isNetworkError, isTrue);
    });

    test('passes through a clean ApiException unchanged', () {
      const clean = ApiException.forbidden('module_disabled');
      expect(identical(ApiException.from(clean), clean), isTrue);
    });

    test('a raw socket string becomes a network error, never the raw text', () {
      final result = ApiException.from(
        'SocketException: Failed host lookup: "api.example.com"',
      );
      expect(result.isNetworkError, isTrue);
      expect(result.message, isNot(contains('SocketException')));
    });

    test('an unknown stray string becomes a neutral retry message', () {
      final result = ApiException.from('weird internal cast TypeError');
      expect(result.message, isNot(contains('TypeError')));
      expect(result.message.toLowerCase(), contains('try again'));
    });
  });
}
