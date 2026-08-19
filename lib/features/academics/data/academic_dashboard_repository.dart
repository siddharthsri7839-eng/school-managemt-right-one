import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class AcademicDashboardRepository {
  final ApiClient _apiClient;

  AcademicDashboardRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getAcademicDashboardData() async {
    try {
      final response = await _apiClient.dio.get('/staff/academics/dashboard');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final academicDashboardRepositoryProvider = Provider<AcademicDashboardRepository>((ref) {
  return AcademicDashboardRepository();
});
