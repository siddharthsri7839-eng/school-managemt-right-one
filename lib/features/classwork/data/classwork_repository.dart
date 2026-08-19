import 'dart:io';
import 'package:dio/dio.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';

class ClassworkRepository {
  final ApiClient _apiClient;

  ClassworkRepository(this._apiClient);

  Future<List<dynamic>> getClassworkList() async {
    try {
      final response = await _apiClient.dio.get('/staff/study-center/classwork');
      if (response.data['success'] == true) {
        return response.data['data']['data'] as List<dynamic>;
      }
      throw Exception(response.data['message'] ?? 'Failed to load classwork');
    } on DioException catch (e) {
      throw Exception(_extractDioMessage(e, 'Failed to load classwork'));
    }
  }

  Future<Map<String, dynamic>> getClassworkDetails(int id) async {
    try {
      final response = await _apiClient.dio.get('/staff/study-center/classwork/$id');
      if (response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception(response.data['message'] ?? 'Failed to load classwork details');
    } on DioException catch (e) {
      throw Exception(_extractDioMessage(e, 'Failed to load classwork details'));
    }
  }

  Future<Map<String, dynamic>> createClasswork(Map<String, dynamic> data, {File? file}) async {
    try {
      FormData formData = FormData.fromMap(data);
      if (file != null) {
        formData.files.add(
          MapEntry(
            'file',
            await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
          ),
        );
      }

      final response = await _apiClient.dio.post(
        '/staff/study-center/classwork',
        data: formData,
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception(response.data['message'] ?? 'Failed to create classwork');
    } on DioException catch (e) {
      throw Exception(_extractDioMessage(e, 'Failed to create entry'));
    }
  }

  Future<Map<String, dynamic>> updateClasswork(int id, Map<String, dynamic> data, {File? file}) async {
    try {
      // In Laravel, PUT with multipart/form-data requires POST with _method=PUT
      data['_method'] = 'PUT';
      FormData formData = FormData.fromMap(data);
      if (file != null) {
        formData.files.add(
          MapEntry(
            'file',
            await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
          ),
        );
      }

      final response = await _apiClient.dio.post(
        '/staff/study-center/classwork/$id',
        data: formData,
      );

      if (response.data['success'] == true) {
        return response.data['data'];
      }
      throw Exception(response.data['message'] ?? 'Failed to update classwork');
    } on DioException catch (e) {
      throw Exception(_extractDioMessage(e, 'Failed to update entry'));
    }
  }

  Future<void> deleteClasswork(int id) async {
    try {
      final response = await _apiClient.dio.delete('/staff/study-center/classwork/$id');
      if (response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Failed to delete classwork');
      }
    } on DioException catch (e) {
      throw Exception(_extractDioMessage(e, 'Failed to delete entry'));
    }
  }

  /// Extracts a clean, user-readable error message from a [DioException].
  /// Handles Laravel validation errors (422) by joining field error messages.
  String _extractDioMessage(DioException e, String fallback) {
    final responseData = e.response?.data;
    if (responseData is Map<String, dynamic>) {
      // Laravel 422 validation errors: { "message": "...", "errors": { "field": ["msg1"] } }
      if (e.response?.statusCode == 422 && responseData.containsKey('errors')) {
        final errors = responseData['errors'] as Map<String, dynamic>;
        final messages = errors.values
            .expand((fieldErrors) => fieldErrors is List ? fieldErrors : [fieldErrors])
            .join('. ');
        if (messages.isNotEmpty) return messages;
      }
      // Standard { "message": "..." } response
      final msg = responseData['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    // Network / timeout / unknown errors
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Server took too long to respond. Please try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Could not connect to the server. Please check your internet connection.';
    }
    return e.message ?? fallback;
  }
}
