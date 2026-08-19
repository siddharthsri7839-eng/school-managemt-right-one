import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';

class ApiClient {
  final Dio dio;

  // Base URL for public storage files — single source of truth: AppConfig.
  final String storageBaseUrl;

  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            // Covers the request-BODY upload (multipart photos). Without it a
            // stalled upload behind a proxy hangs forever instead of failing.
            sendTimeout: const Duration(seconds: 60),
            headers: {
              'Accept': 'application/json',
            },
          ),
        ),
        storageBaseUrl = AppConfig.storageBaseUrl
  {
    dio.interceptors.add(AuthInterceptor());
  }

  /// Resolve a media path returned by the backend into a loadable URL.
  ///
  /// The backend is inconsistent: some fields come back as a relative storage
  /// path, others as an already-absolute `http(s)://…` URL. Blindly prefixing
  /// [base] onto an absolute URL yields a broken host like
  /// `multischoolv2.projectworlds.comhttps://…` (SocketException: Failed host
  /// lookup). So: pass absolute URLs through untouched, prefix only relatives.
  static String? resolveMedia(String base, String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '$base$path';
  }
}