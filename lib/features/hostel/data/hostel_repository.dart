import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_exception.dart';
import 'package:dio/dio.dart';

class HostelRepository {
  final ApiClient _apiClient;

  HostelRepository(this._apiClient);

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await _apiClient.dio.get('/staff/hostel/dashboard');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 && e.response?.data['error'] == 'module_disabled') {
        throw const ApiException.forbidden('module_disabled');
      }
      throw ApiException.server(e.response?.data['message'] ?? 'Failed to load hostel data.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }
}

final hostelRepositoryProvider = Provider<HostelRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return HostelRepository(apiClient);
});
