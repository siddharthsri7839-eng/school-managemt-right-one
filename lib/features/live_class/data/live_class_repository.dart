import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import 'models/live_class.dart';

/// Form-data payload backing the schedule screen.
class LiveClassFormData {
  final List<NamedOption> classes;
  final List<NamedOption> sections;
  final List<NamedOption> subjects;
  final List<MeetingProviderOption> providers;

  const LiveClassFormData({
    required this.classes,
    required this.sections,
    required this.subjects,
    required this.providers,
  });
}

class LiveClassRepository {
  final ApiClient _apiClient;

  LiveClassRepository(this._apiClient);

  static const _base = '/staff/live-classes';

  Future<({List<LiveClass> upcoming, List<LiveClass> past})> getClasses() async {
    try {
      final response = await _apiClient.dio.get(_base);
      final data = response.data['data'] as Map<String, dynamic>;

      List<LiveClass> parse(String key) =>
          ((data[key] ?? []) as List)
              .map((e) => LiveClass.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();

      return (upcoming: parse('upcoming'), past: parse('past'));
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to load live classes.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  /// Form sources. Pass [schoolClassId] to get that class's sections and
  /// subjects — the backend returns both empty until a class is chosen.
  Future<LiveClassFormData> getFormData({int? schoolClassId}) async {
    try {
      final response = await _apiClient.dio.get(
        '$_base/form-data',
        queryParameters: schoolClassId != null ? {'school_class_id': schoolClassId} : null,
      );
      final data = response.data['data'] as Map<String, dynamic>;

      List<NamedOption> named(String key) => ((data[key] ?? []) as List)
          .map((e) => NamedOption.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      return LiveClassFormData(
        classes: named('classes'),
        sections: named('sections'),
        subjects: named('subjects'),
        providers: ((data['providers'] ?? []) as List)
            .map((e) => MeetingProviderOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to load the schedule form.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  Future<void> create(Map<String, dynamic> payload) async {
    try {
      await _apiClient.dio.post(_base, data: payload);
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to schedule the live class.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  Future<void> update(int id, Map<String, dynamic> payload) async {
    try {
      await _apiClient.dio.put('$_base/$id', data: payload);
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to update the live class.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  Future<void> delete(int id) async {
    try {
      await _apiClient.dio.delete('$_base/$id');
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to delete the live class.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  /// Marks the class live and returns how the host should join.
  Future<JoinContext> start(int id) async {
    try {
      final response = await _apiClient.dio.post('$_base/$id/start');
      return JoinContext.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to start the live class.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  Future<void> end(int id) async {
    try {
      await _apiClient.dio.post('$_base/$id/end');
    } on DioException catch (e) {
      throw _mapError(e, 'Failed to end the live class.');
    } catch (e) {
      throw ApiException.server('An unexpected error occurred: $e');
    }
  }

  /// Surfaces the backend's own message where there is one — provider failures
  /// ("Could not create the meeting with Zoom: ...") are the useful case and a
  /// generic fallback would hide exactly what the teacher needs to see.
  ApiException _mapError(DioException e, String fallback) {
    final data = e.response?.data;

    if (e.response?.statusCode == 403 &&
        data is Map &&
        data['error'] == 'module_disabled') {
      return const ApiException.forbidden('module_disabled');
    }

    final message = data is Map ? data['message'] as String? : null;

    if (e.response?.statusCode == 403) {
      return ApiException.forbidden(message ?? 'You cannot manage this live class.');
    }
    if (e.response?.statusCode == 422) {
      return ApiException(
        message: message ?? fallback,
        statusCode: 422,
        errorCode: 'VALIDATION',
        validationErrors: data is Map && data['errors'] is Map
            ? Map<String, dynamic>.from(data['errors'] as Map)
            : null,
      );
    }

    return ApiException.server(message ?? fallback);
  }
}
