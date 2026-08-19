import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_exception.dart';
import 'package:dio/dio.dart';

class PtmRepository {
  final ApiClient _apiClient;

  PtmRepository(this._apiClient);

  Future<Map<String, dynamic>> getDashboard() async {
    try {
      final response = await _apiClient.dio.get('/staff/ptm/dashboard');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 && e.response?.data['error'] == 'module_disabled') {
        throw const ApiException.forbidden('module_disabled');
      }
      throw ApiException.server(e.response?.data['message'] ?? 'Failed to load PTM dashboard data.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getReportMeetings() async {
    try {
      final response = await _apiClient.dio.get('/staff/ptm/reports/meetings');
      return List<Map<String, dynamic>>.from(response.data['meetings']);
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 && e.response?.data is Map && e.response?.data['error'] == 'module_disabled') {
        throw const ApiException.forbidden('module_disabled');
      }
      final msg = e.response?.data is Map ? e.response?.data['message'] : null;
      throw ApiException.server(msg ?? 'Failed to load PTM meetings.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  Future<Map<String, dynamic>> getReportData(int meetingId) async {
    try {
      final response = await _apiClient.dio.get(
        '/staff/ptm/reports/data',
        queryParameters: {'meeting_id': meetingId},
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 && e.response?.data is Map && e.response?.data['error'] == 'module_disabled') {
        throw const ApiException.forbidden('module_disabled');
      }
      final msg = e.response?.data is Map ? e.response?.data['message'] : null;
      throw ApiException.server(msg ?? 'Failed to load PTM report data.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  Future<Map<String, dynamic>> getRecordMeetings({int page = 1}) async {
    try {
      final response = await _apiClient.dio.get('/staff/ptm/record', queryParameters: {'page': page});
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 && e.response?.data is Map && e.response?.data['error'] == 'module_disabled') {
        throw const ApiException.forbidden('module_disabled');
      }
      final msg = e.response?.data is Map ? e.response?.data['message'] : null;
      throw ApiException.server(msg ?? 'Failed to load PTM record meetings.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  Future<Map<String, dynamic>> getRecordRoster(int meetingId) async {
    try {
      final response = await _apiClient.dio.get('/staff/ptm/record/$meetingId');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 && e.response?.data is Map && e.response?.data['error'] == 'module_disabled') {
        throw const ApiException.forbidden('module_disabled');
      }
      final msg = e.response?.data is Map ? e.response?.data['message'] : null;
      throw ApiException.server(msg ?? 'Failed to load PTM roster data.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  Future<Map<String, dynamic>> saveRecord(int meetingId, Map<String, dynamic> data) async {
    try {
      final response = await _apiClient.dio.post('/staff/ptm/record/$meetingId', data: data);
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 && e.response?.data is Map && e.response?.data['error'] == 'module_disabled') {
        throw const ApiException.forbidden('module_disabled');
      }
      final msg = e.response?.data is Map ? e.response?.data['message'] : null;
      throw ApiException.server(msg ?? 'Failed to save PTM records.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }
}

final ptmRepositoryProvider = Provider<PtmRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PtmRepository(apiClient);
});
