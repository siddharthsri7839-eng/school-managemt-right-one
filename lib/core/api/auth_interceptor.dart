// ✅ CORRECTED THE IMPORT PATH (package:dio/dio.dart)
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:school_erp_staff_app/main.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../storage/secure_storage_service.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storageService = SecureStorageService();

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (kDebugMode) {
      print('--> ${options.method.toUpperCase()} ${options.uri}');
    }

    final isPublic = options.path == '/login' ||
                     options.path == '/branding' ||
                     options.path.contains('/otp-login/') ||
                     options.path.contains('/demo/');

    if (!isPublic) {
      final token = await _storageService.readToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        // Store for cross-referencing in onError
        options.extra['sent_token'] = token; 
        
        if (kDebugMode) {
          print('🔑 [INTERCEPTOR] Authorization header set! (Token length: ${token.length})');
        }
      } else {
        if (kDebugMode) {
          print('🚨 [INTERCEPTOR] No token FOUND for path: ${options.path}. Rejecting locally.');
        }
        // FAIL FAST: Reject locally instead of sending and triggering a server 401
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'No authentication token found.',
          ),
        );
      }
    }
    
    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (kDebugMode) {
      print('<-- ${err.response?.statusCode} ${err.requestOptions.uri}');
      print('Error Response: ${err.response?.data}');
    }

    if (err.response?.statusCode == 401) {
      final sentToken = err.requestOptions.extra['sent_token'] as String?;
      final currentToken = await _storageService.readToken();

      // ONLY LOGOUT IF: 
      // 1. We sent a token that is now considered invalid.
      // 2. The token we sent is STILL the current one in memory.
      // (This prevents stale requests from clearing a fresh login session)
      if (sentToken != null && sentToken == currentToken) {
        if (err.requestOptions.path != '/login') {
          print('--- Interceptor: 401 VALIDATED (Current session invalid). Logging out... ---');
          await providerContainer.read(authControllerProvider.notifier).logout();
        }
      } else {
        print('--- Interceptor: 401 IGNORED (Stale request or token already changed) ---');
      }
    }
    
    super.onError(err, handler);
  }
}
