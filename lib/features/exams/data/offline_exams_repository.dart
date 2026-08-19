import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import 'package:dio/dio.dart';

class OfflineExamsRepository {
  final ApiClient _apiClient;

  OfflineExamsRepository(this._apiClient);

  Future<Map<String, dynamic>> fetchDashboardData() async {
    try {
      final response = await _apiClient.dio.get('/staff/offline-exams/dashboard');
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException.server('An unexpected error occurred while fetching offline exams data.');
    }
  }
}

final offlineExamsRepositoryProvider = Provider<OfflineExamsRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OfflineExamsRepository(apiClient);
});
