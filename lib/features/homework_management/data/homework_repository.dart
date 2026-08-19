import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class HomeworkRepository {
  final ApiClient _apiClient;
  HomeworkRepository(this._apiClient);

  Future<void> evaluateSubmission({
    required int submissionId,
    required String marks,
    String? remarks,
  }) async {
    try {
      await _apiClient.dio.post(
        '/staff/submissions/$submissionId/evaluate',
        data: {
          'marks': marks,
          'remarks': remarks ?? '',
        },
      );
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response?.data['message'] ?? 'Failed to evaluate submission.');
      }
      throw Exception('Failed to evaluate submission.');
    }
  }

  Future<List<dynamic>> getHomeworkList() async {
    try {
      final response = await _apiClient.dio.get('/staff/homework');
      return response.data['data'] ?? [];
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response?.data['message'] ?? 'Failed to fetch homework list.');
      }
      throw Exception('Failed to fetch homework list.');
    }
  }

  Future<Map<String, dynamic>> getHomeworkDetails(int homeworkId) async {
    try {
      final response = await _apiClient.dio.get('/staff/homework/$homeworkId');
      return response.data['data'] ?? {};
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response?.data['message'] ?? 'Failed to fetch homework details.');
      }
      throw Exception('Failed to fetch homework details.');
    }
  }

  Future<List<dynamic>> getSubjectsForClass(int classId) async {
    try {
      final response = await _apiClient.dio.get('/staff/data/subjects-for-class/$classId');
      return response.data['data'] ?? [];
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response?.data['message'] ?? 'Failed to fetch subjects.');
      }
      throw Exception('Failed to fetch subjects.');
    }
  }

  Future<void> createHomework({
    required int classId,
    required int sectionId,
    required int subjectId,
    required String title,
    required String dueDate,
    String? description,
    String? filePath,
  }) async {
    final formData = FormData.fromMap({
      'school_class_id': classId,
      'section_id': sectionId,
      'subject_id': subjectId,
      'title': title,
      'due_date': dueDate,
      if (description != null) 'description': description,
      if (filePath != null) 'file': await MultipartFile.fromFile(filePath),
    });

    try {
      await _apiClient.dio.post('/staff/homework', data: formData);
    } on DioException catch (e) {
      if (e.response?.data is Map) {
        throw Exception(e.response?.data['message'] ?? 'Failed to create homework.');
      }
      throw Exception('Failed to create homework. Check the attached file format and size.');
    }
  }
}