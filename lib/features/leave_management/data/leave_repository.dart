import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

class LeaveRepository {
  final ApiClient _apiClient;
  LeaveRepository(this._apiClient);

  // Fetches the leave history for the logged-in staff member
  Future<List<dynamic>> getMyLeaveRequests() async {
    try {
      final response = await _apiClient.dio.get('/staff/leave/my-requests');
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: 'Failed to load leave requests.');
    }
  }

  Future<List<dynamic>> getLeaveTypes() async {
    try {
      final response = await _apiClient.dio.get('/staff/leave/types');
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: 'Failed to load leave types.');
    }
  }

  Future<void> applyForLeave({
    required int leaveTypeId,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      await _apiClient.dio.post(
        '/staff/leave/apply',
        data: {
          'leave_type_id': leaveTypeId,
          'start_date': startDate,
          'end_date': endDate,
          'reason': reason,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: 'Failed to apply for leave.');
    }
  }

  // Admin: Fetch all leave requests
  Future<List<dynamic>> getAllLeaveRequests() async {
    try {
      final response = await _apiClient.dio.get('/staff/leave/all-requests');
      if (response.data is Map<String, dynamic> && response.data.containsKey('data')) {
        return response.data['data'];
      }
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: 'Failed to load all leave requests.');
    }
  }

  // Admin: Update leave status
  Future<void> updateLeaveStatus({
    required int leaveId,
    required String status,
    String? remarks,
  }) async {
    try {
      await _apiClient.dio.patch(
        '/staff/leave/requests/$leaveId',
        data: {
          'status': status,
          if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    } catch (e) {
      throw ApiException(message: 'Failed to update leave status.');
    }
  }
}
