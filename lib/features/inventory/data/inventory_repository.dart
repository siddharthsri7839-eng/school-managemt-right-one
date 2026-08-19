import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_exception.dart';
import 'package:dio/dio.dart';

class InventoryRepository {
  final ApiClient _apiClient;

  InventoryRepository(this._apiClient);

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await _apiClient.dio.get('/staff/inventory/dashboard');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 && e.response?.data['error'] == 'module_disabled') {
        throw const ApiException.forbidden('module_disabled');
      }
      throw ApiException.server(e.response?.data['message'] ?? 'Failed to load inventory data.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }
}

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return InventoryRepository(apiClient);
});
