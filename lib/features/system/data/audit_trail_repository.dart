import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';

class AuditTrailRepository {
  final ApiClient _apiClient;

  AuditTrailRepository(this._apiClient);

  Future<Map<String, dynamic>> fetchAuditLogs({
    int page = 1,
    int perPage = 20,
    String? eventFilter,
    String sortOrder = 'desc',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/staff/system/audit-trail',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          if (eventFilter != null && eventFilter.isNotEmpty) 'event': eventFilter,
          'sort': sortOrder,
        },
      );
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException.server('An unexpected error occurred while fetching audit logs.');
    }
  }
}

final auditTrailRepositoryProvider = Provider<AuditTrailRepository>((ref) {
  return AuditTrailRepository(ref.watch(apiClientProvider));
});
