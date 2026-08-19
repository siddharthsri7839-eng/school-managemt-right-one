import 'dart:convert';

import 'package:dio/dio.dart';

import '../storage/secure_storage_service.dart';
import 'branding.dart';

/// Fetches the white-label branding and caches the RAW payload locally so the
/// next cold start themes the app before the first frame, fully offline
/// (plan §5.1 Layer B). Total — callers never see an exception from caching.
class BrandingRepository {
  final Dio _dio;
  final SecureStorageService _storage = SecureStorageService();

  BrandingRepository(this._dio);

  /// Which app this binary is, for the per-app brand. Sent as `?app=` so the
  /// staff accent (the FAB) can be tuned without repainting the driver app,
  /// which used to share the same field (see backend
  /// docs/per-app-branding-plan.md).
  static const String _app = 'staff';

  /// GET /branding (public). Optional [schoolId] resolves the per-school brand.
  Future<Branding> fetchAndCache({int? schoolId}) async {
    final response = await _dio.get(
      '/branding',
      queryParameters: {
        'app': _app,
        if (schoolId != null) 'school_id': schoolId,
      },
    );

    final data = response.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      await _storage.saveBrandingRaw(jsonEncode(map));
      return Branding.fromJson(map);
    }
    return const Branding.fallback();
  }

  /// Read the cached branding for instant, offline bootstrap. Returns the
  /// compile-time fallback when nothing is cached or the cache is unreadable.
  Future<Branding> loadCached() async {
    try {
      final raw = await _storage.readBrandingRaw();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return Branding.fromJson(Map<String, dynamic>.from(decoded));
        }
      }
    } catch (_) {
      // Corrupt cache → fallback (plan E5/E6).
    }
    return const Branding.fallback();
  }
}
