import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class FeesDashboardRepository {
  final ApiClient _apiClient;

  FeesDashboardRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> getFeesDashboardData() async {
    try {
      final response = await _apiClient.dio.get('/staff/report/fees-dashboard');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<void> sendFeeReminder(String studentId) async {
    try {
      await _apiClient.dio.post('/staff/report/send-fee-reminder/$studentId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final feesDashboardRepositoryProvider = Provider<FeesDashboardRepository>((ref) {
  return FeesDashboardRepository();
});
