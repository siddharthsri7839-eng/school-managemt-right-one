import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';

class HrRepository {
  final Dio _dio;

  HrRepository(this._dio);

  Future<List<dynamic>> getStaffList() async {
    try {
      final response = await _dio.get('/staff/hr/staff-list');
      return response.data['data'] as List<dynamic>? ?? [];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Map<String, dynamic>> getStaffAttendanceReport({
    required String viewMode,
    required String month,
    String? staffId,
  }) async {
    try {
      final queryParams = {
        'view': viewMode,
        'month': month,
      };

      if (viewMode == 'member' && staffId != null) {
        queryParams['staff_id'] = staffId;
      }

      final response = await _dio.get(
        '/staff/hr/staff-attendance/report',
        queryParameters: queryParams,
      );

      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  return HrRepository(ref.watch(apiClientProvider).dio);
});
