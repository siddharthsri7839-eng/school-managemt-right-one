import '../../../core/api/api_client.dart';
import 'package:school_erp_staff_app/features/dashboard/domain/calendar_event.dart';

class StaffDashboardRepository {
  final ApiClient _apiClient;
  StaffDashboardRepository(this._apiClient);

  // We only need one method now to get all dashboard data
  Future<Map<String, dynamic>> getDashboardData() async {
    final response = await _apiClient.dio.get('/staff/dashboard');
    final data = response.data['data'];
    
    // Defensive check: handle case where backend returns [] instead of {}
    if (data is List) {
      return {};
    }
    
    return data as Map<String, dynamic>;
  }
  // ✅ ADD THIS NEW METHOD
  Future<List<CalendarEvent>> getCalendarEvents() async {
    final response = await _apiClient.dio.get('/staff/calendar-events');
    final List<dynamic> data = response.data;
    return data.map((item) => CalendarEvent.fromJson(item)).toList();
  }
}