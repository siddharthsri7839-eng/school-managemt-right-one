import 'package:dio/dio.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/features/timetable/domain/timetable_model.dart';

class TimetableRepository {
  final ApiClient _apiClient;
  TimetableRepository(this._apiClient);

  Future<TimetableData> getMyTimetable() async {
    try {
      final response = await _apiClient.dio.get('/staff/my-timetable');
      final dynamic rawData = response.data['data'];

      final TimetableData timetable = {};

      if (rawData is Map) {
        rawData.forEach((day, periodsJson) {
          final List<dynamic> periodList = periodsJson;
          timetable[day.toString()] =
              periodList.map((json) => Period.fromJson(json)).toList();
        });
      }

      return timetable;
    } on DioException catch (e) {
      throw e.response?.data['message'] ?? 'Failed to load timetable.';
    } catch (e) {
      throw 'An unexpected error occurred.';
    }
  }
}