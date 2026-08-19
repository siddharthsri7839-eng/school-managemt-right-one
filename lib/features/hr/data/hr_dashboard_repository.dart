import 'package:dio/dio.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';

class HrDashboardRepository {
  final ApiClient _apiClient;

  HrDashboardRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    try {
      final response = await _apiClient.dio.get('/staff/hr/dashboard');
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: 'Failed to load HR dashboard data: $e');
    }
  }
}
