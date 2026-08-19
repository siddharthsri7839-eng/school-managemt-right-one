import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';

class TransportRepository {
  final ApiClient _apiClient;

  TransportRepository(this._apiClient);

  Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final response = await _apiClient.dio.get('/staff/transport/dashboard');
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException.server('An unexpected error occurred while fetching transport data.');
    }
  }
}

final transportRepositoryProvider = Provider<TransportRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return TransportRepository(apiClient);
});
