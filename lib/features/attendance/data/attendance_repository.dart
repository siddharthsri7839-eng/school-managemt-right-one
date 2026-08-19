import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class AttendanceRepository {
  final ApiClient _apiClient;
  AttendanceRepository(this._apiClient);

  Future<List<dynamic>> getClassesWithSections() async {
    try {
      final response = await _apiClient.dio.get('/staff/data/classes-with-sections');
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException.server('Could not fetch classes and sections.');
    }
  }

  Future<List<dynamic>> getStudentsForSection(int sectionId, String date) async {
    try {
      final response = await _apiClient.dio.get(
        '/staff/sections/$sectionId/students',
        queryParameters: {'date': date},
      );
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException.server('Could not fetch students for this section.');
    }
  }

  Future<void> submitAttendance({
    required int sectionId,
    required String date,
    required List<Map<String, dynamic>> attendances,
  }) async {
    try {
      await _apiClient.dio.post(
        '/staff/attendance',
        data: {
          'section_id': sectionId,
          'date': date,
          'attendances': attendances,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw const ApiException.server('Could not submit attendance.');
    }
  }
}