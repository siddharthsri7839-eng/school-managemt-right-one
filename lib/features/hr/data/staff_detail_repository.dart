import 'package:dio/dio.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';

class StaffDetailRepository {
  final ApiClient _apiClient;

  StaffDetailRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> fetchStaffDetail(String id) async {
    try {
      final response = await _apiClient.dio.get('/staff/hr/staff-list/$id');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: 'Failed to load staff details: $e');
    }
  }
}
