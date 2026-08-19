import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_exception.dart';
import '../domain/qr_models.dart';

/// Talks to `Api/V1/Staff/QrAttendanceController`. The server owns every security
/// decision (scope, self-mark block, staff-perm, geofence, scanned_at) — this
/// repository only shuttles JSON and lifts a business denial (422 `status:false`)
/// into a typed [QrScanException] carrying the machine `reason`.
class QrAttendanceRepository {
  final ApiClient _apiClient;
  QrAttendanceRepository(this._apiClient);

  static const _base = '/staff/qr-attendance';

  Future<QrScannerConfig> config() async {
    try {
      final res = await _apiClient.dio.get('$_base/config');
      final data = (res.data as Map)['data'];
      return QrScannerConfig.fromJson((data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _map(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<QrScanProfile> resolve(String code) async {
    try {
      final res = await _apiClient.dio.post('$_base/resolve', data: {'code': code});
      final body = (res.data as Map).cast<String, dynamic>();
      return QrScanProfile.fromJson((body['data'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _mapBusiness(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<QrPunchResult> punch({
    required String type,
    required int id,
    String? status,
    DateTime? scannedAt,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool isMocked = false,
    String? deviceUuid,
  }) async {
    try {
      final res = await _apiClient.dio.post('$_base/punch', data: {
        'type': type,
        'id': id,
        if (status != null) 'status': status,
        if (scannedAt != null) 'scanned_at': scannedAt.toIso8601String(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        'is_mocked': isMocked,
        if (deviceUuid != null) 'device_uuid': deviceUuid,
      });
      final body = (res.data as Map).cast<String, dynamic>();
      return QrPunchResult.fromJson((body['data'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _mapBusiness(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// A 422 with `{status:false, reason, message}` is a business denial (wrong
  /// school, out of scope, off campus, self-mark, …) — surface it typed so the
  /// result sheet can colour it. Anything else falls back to the generic mapper.
  Object _mapBusiness(DioException e) {
    final data = e.response?.data;
    if (e.response?.statusCode == 422 && data is Map && data['status'] == false) {
      return QrScanException(
        '${data['reason'] ?? 'error'}',
        '${data['message'] ?? 'This scan could not be processed.'}',
      );
    }
    return _map(e);
  }

  ApiException _map(DioException e) {
    final data = e.response?.data;
    if (e.response?.statusCode == 403 && data is Map && data['error'] == 'module_disabled') {
      return const ApiException.forbidden('module_disabled');
    }
    return ApiException.fromDioException(e);
  }
}

final qrAttendanceRepositoryProvider = Provider<QrAttendanceRepository>((ref) {
  return QrAttendanceRepository(ref.watch(apiClientProvider));
});
