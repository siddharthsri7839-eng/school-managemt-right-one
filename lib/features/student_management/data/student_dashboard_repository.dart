import 'package:dio/dio.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';

class StudentDashboardRepository {
  final ApiClient _apiClient;

  StudentDashboardRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    try {
      final response = await _apiClient.dio.get('/staff/student-dashboard');
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: 'Failed to load dashboard data: $e');
    }
  }
}
