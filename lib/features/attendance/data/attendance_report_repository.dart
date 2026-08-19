import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class AttendanceReportRepository {
  final ApiClient _apiClient;
  AttendanceReportRepository(this._apiClient);

  Future<Map<String, dynamic>> getStudentReport({
    required int classId,
    required int sectionId,
    required int month,
    required int year,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/staff/attendance/reports/student',
        queryParameters: {
          'class_id': classId,
          'section_id': sectionId,
          'month': month,
          'year': year,
        },
      );
      return response.data['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response?.data['message'] ?? 'Failed to load report data.');
      }
      throw Exception('Failed to load report data.');
    }
  }

  Future<String> getExportUrl({
    required int classId,
    required int sectionId,
    required int month,
    required int year,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        '/staff/attendance/reports/student/export-url',
        queryParameters: {
          'class_id': classId,
          'section_id': sectionId,
          'month': month,
          'year': year,
        },
      );
      return response.data['url'] as String;
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response?.data['message'] ?? 'Failed to generate download URL.');
      }
      throw Exception('Failed to generate download URL.');
    }
  }
}
