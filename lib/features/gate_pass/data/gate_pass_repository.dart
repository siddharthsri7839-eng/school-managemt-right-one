import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../domain/gate_models.dart';

/// Talks to `Api/V1/Staff/GatePassController`.
///
/// Note the difference from the attendance scanner: a **denial is not an error**
/// here. The gate always answers 200 with `decision: allow|deny`, because "do not
/// let this person out" is the answer, not a failure. Only transport problems and
/// permission/module errors raise.
class GatePassRepository {
  final ApiClient _apiClient;
  GatePassRepository(this._apiClient);

  static const _base = '/staff/gate-pass';

  Future<GateConfig> config() async {
    try {
      final res = await _apiClient.dio.get('$_base/config');
      final data = (res.data as Map)['data'];
      return GateConfig.fromJson((data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _map(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Decide, without recording anything.
  Future<GateDecision> verify({
    required String code,
    String? gate,
    String? deviceUuid,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool isMocked = false,
  }) =>
      _decide('verify',
          code: code,
          gate: gate,
          deviceUuid: deviceUuid,
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          isMocked: isMocked);

  /// Decide and, if allowed, record the crossing.
  ///
  /// The raw scanned code is replayed rather than a pass id: the server must
  /// re-derive the decision, so a tampered phone cannot open a gate by asserting
  /// one.
  Future<GateDecision> commit({
    required String code,
    String? gate,
    String? deviceUuid,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool isMocked = false,
  }) =>
      _decide('commit',
          code: code,
          gate: gate,
          deviceUuid: deviceUuid,
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          isMocked: isMocked);

  Future<List<GateOutEntry>> outNow() async {
    try {
      final res = await _apiClient.dio.get('$_base/out-now');
      final list = ((res.data as Map)['data'] as List?) ?? const [];
      return list
          .map((e) => GateOutEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _map(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<GateDecision> _decide(
    String endpoint, {
    required String code,
    String? gate,
    String? deviceUuid,
    double? latitude,
    double? longitude,
    double? accuracy,
    bool isMocked = false,
  }) async {
    try {
      final res = await _apiClient.dio.post('$_base/$endpoint', data: {
        'code': code,
        if (gate != null) 'gate': gate,
        if (deviceUuid != null) 'device_uuid': deviceUuid,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        'is_mocked': isMocked,
      });
      final body = (res.data as Map).cast<String, dynamic>();
      return GateDecision.fromJson((body['data'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw _map(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  ApiException _map(DioException e) {
    final data = e.response?.data;
    if (e.response?.statusCode == 403 &&
        data is Map &&
        data['error'] == 'module_disabled') {
      return const ApiException.forbidden('module_disabled');
    }
    return ApiException.fromDioException(e);
  }
}

final gatePassRepositoryProvider = Provider<GatePassRepository>((ref) {
  return GatePassRepository(ref.watch(apiClientProvider));
});
