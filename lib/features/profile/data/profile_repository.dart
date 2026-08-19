import '../../../core/api/api_client.dart';

class ProfileRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> getStudentProfile({required int studentId}) async {
    final response = await _apiClient.dio.get(
      '/parent/profile',
      queryParameters: {'student_id': studentId},
    );
    return response.data['data'];
  }
}