import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class StudentRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<dynamic>> searchStudents({String query = ''}) async {
    final response = await _apiClient.dio.get(
      '/staff/students',
      queryParameters: {'search': query},
    );
    // API returns paginated data, we just want the list for now
    return response.data['data'];
  }

 Future<Map<String, dynamic>> getStudentProfile({required int studentId}) async {
    final response = await _apiClient.dio.get('/staff/students/$studentId');
    return response.data['data'];
  }

  /// Students (scoped by permission) who have no profile photo yet.
  /// Returns `{students: [...], lastPage, total}`.
  Future<Map<String, dynamic>> getStudentsWithoutPhoto({int page = 1}) async {
    final response = await _apiClient.dio.get(
      '/staff/students/without-photo',
      queryParameters: {'page': page},
    );
    return {
      'students': List<Map<String, dynamic>>.from(response.data['data'] ?? []),
      'lastPage': response.data['meta']?['last_page'] ?? 1,
      'total': response.data['meta']?['total'] ?? 0,
    };
  }

  /// Upload a new profile photo for a student. Returns the fresh photo URL.
  Future<String?> updateStudentPhoto({
    required int studentId,
    required String filePath,
    String? fileName,
  }) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _apiClient.dio.post(
      '/staff/students/$studentId/photo',
      data: form,
    );
    return response.data['photo_url'] as String?;
  }
}
