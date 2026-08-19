import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_exception.dart';
import '../domain/assessment_models.dart';

/// All HTTP for the Continuous Assessment module. Mirrors the web controllers
/// 1:1 (dashboard, CRUD, mark entry, publish, reports). The module-disabled
/// 403 is surfaced as a forbidden ApiException so screens can show the
/// "module off" state, identical to the PTM module.
class AssessmentRepository {
  final ApiClient _apiClient;
  AssessmentRepository(this._apiClient);

  static const _base = '/staff/assessments';

  // ── Dashboard & browse ────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboard() async {
    final data = await _get('$_base/dashboard');
    final d = (data['data'] as Map).cast<String, dynamic>();
    return {
      'stats': (d['stats'] as Map).cast<String, dynamic>(),
      'recent': ((d['recent'] as List?) ?? [])
          .map((e) => AssessmentSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      'can': AssessmentCapabilities.fromJson((d['can'] as Map?)?.cast<String, dynamic>()),
    };
  }

  Future<Map<String, dynamic>> getList({
    String? type,
    int? subjectId,
    int? classId,
    String? from,
    String? to,
    int page = 1,
  }) async {
    final data = await _get(_base, query: {
      if (type != null && type.isNotEmpty) 'type': type,
      if (subjectId != null) 'subject_id': subjectId,
      if (classId != null) 'class_id': classId,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      'page': page,
    });
    return {
      'items': ((data['data'] as List?) ?? [])
          .map((e) => AssessmentSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      'meta': (data['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
    };
  }

  // ── Create / edit form data ───────────────────────────────────────

  Future<Map<String, dynamic>> getFormOptions() async {
    final data = await _get('$_base/form-options');
    final d = (data['data'] as Map).cast<String, dynamic>();
    return {
      'types': _enumList(d['types']),
      'frequencies': _enumList(d['frequencies']),
      'conducted_via': _enumList(d['conducted_via']),
      'classes': _namedList(d['classes']),
    };
  }

  Future<Map<String, List<NamedOption>>> getClassOptions(int classId) async {
    final data = await _get('$_base/options', query: {'class_id': classId});
    final d = (data['data'] as Map).cast<String, dynamic>();
    return {
      'subjects': _namedList(d['subjects']),
      'sections': _namedList(d['sections']),
    };
  }

  // ── Assessment CRUD ───────────────────────────────────────────────

  Future<AssessmentDetail> getDetail(int id) async {
    final data = await _get('$_base/$id');
    return AssessmentDetail.fromJson((data['data'] as Map).cast<String, dynamic>());
  }

  Future<AssessmentDetail> create(Map<String, dynamic> body) async {
    final data = await _post(_base, body);
    return AssessmentDetail.fromJson((data['data'] as Map).cast<String, dynamic>());
  }

  Future<AssessmentDetail> update(int id, Map<String, dynamic> body) async {
    final data = await _request('PUT', '$_base/$id', body);
    return AssessmentDetail.fromJson((data['data'] as Map).cast<String, dynamic>());
  }

  Future<String> delete(int id) async {
    final data = await _request('DELETE', '$_base/$id', null);
    return '${data['message'] ?? 'Assessment deleted.'}';
  }

  // ── Mark entry ────────────────────────────────────────────────────

  Future<MarkGrid> getGrid(int occurrenceId) async {
    final data = await _get('$_base/occurrences/$occurrenceId/grid');
    return MarkGrid.fromJson((data['data'] as Map).cast<String, dynamic>());
  }

  Future<double?> saveMark(int occurrenceId, {
    required int studentId,
    double? marks,
    required String attendance,
  }) async {
    final data = await _post('$_base/occurrences/$occurrenceId/marks', {
      'student_id': studentId,
      'marks_obtained': marks,
      'attendance': attendance,
    });
    final pct = data['percentage'];
    return pct == null ? null : (pct as num).toDouble();
  }

  Future<String> bulk(int occurrenceId, String action) async {
    final data = await _post('$_base/occurrences/$occurrenceId/bulk', {'action': action});
    return '${data['message'] ?? 'Done.'}';
  }

  Future<String> publish(int occurrenceId) async {
    final data = await _post('$_base/occurrences/$occurrenceId/publish', {});
    return '${data['message'] ?? 'Results published.'}';
  }

  Future<String> reopen(int occurrenceId) async {
    final data = await _post('$_base/occurrences/$occurrenceId/reopen', {});
    return '${data['message'] ?? 'Sitting reopened.'}';
  }

  // ── Reports ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> reportFilters({int? classId}) async {
    final data = await _get('$_base/reports/filters', query: {
      if (classId != null) 'class_id': classId,
    });
    final d = (data['data'] as Map).cast<String, dynamic>();
    return {
      'classes': _namedList(d['classes']),
      'subjects': _namedList(d['subjects']),
      'types': _enumList(d['types']),
    };
  }

  Future<Map<String, dynamic>> reportOverview(Map<String, dynamic> filters) async {
    final data = await _get('$_base/reports/overview', query: filters);
    return (data['data'] as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> reportStudent(Map<String, dynamic> filters) async {
    final data = await _get('$_base/reports/student', query: filters);
    return (data['data'] as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> reportRanking(Map<String, dynamic> filters) async {
    final data = await _get('$_base/reports/ranking', query: filters);
    return (data['data'] as Map).cast<String, dynamic>();
  }

  /// Build a URL (relative to the dio baseUrl) for a streamed export. The
  /// SecurePdfViewerScreen / CSV downloader attaches the bearer token.
  String exportPath(String kind, Map<String, dynamic> filters) {
    final query = filters.entries
        .where((e) => e.value != null && '${e.value}'.isNotEmpty)
        .map((e) => '${e.key}=${Uri.encodeQueryComponent('${e.value}')}')
        .join('&');
    final path = switch (kind) {
      'pdf' => '$_base/reports/export/pdf',
      'csv' => '$_base/reports/export/csv',
      'student_pdf' => '$_base/reports/student/pdf',
      'ranking_pdf' => '$_base/reports/ranking/pdf',
      'marksheet' => '$_base/occurrences/${filters['occurrence_id']}/marksheet',
      _ => '$_base/reports/export/pdf',
    };
    return query.isEmpty ? path : '$path?$query';
  }

  // ── HTTP plumbing ─────────────────────────────────────────────────

  List<EnumOption> _enumList(dynamic raw) => ((raw as List?) ?? [])
      .map((e) => EnumOption.fromJson((e as Map).cast<String, dynamic>()))
      .toList();

  List<NamedOption> _namedList(dynamic raw) => ((raw as List?) ?? [])
      .map((e) => NamedOption.fromJson((e as Map).cast<String, dynamic>()))
      .toList();

  Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _apiClient.dio.get(path, queryParameters: query);
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic>? body) =>
      _request('POST', path, body);

  Future<Map<String, dynamic>> _request(String method, String path, Map<String, dynamic>? body) async {
    try {
      final res = await _apiClient.dio.request(
        path,
        data: body,
        options: Options(method: method),
      );
      final data = res.data;
      return data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  ApiException _map(DioException e) {
    final data = e.response?.data;
    if (e.response?.statusCode == 403 && data is Map && data['error'] == 'module_disabled') {
      return const ApiException.forbidden('module_disabled');
    }
    // Preserve validation errors + server messages for forms / snackbars.
    return ApiException.fromDioException(e);
  }
}

final assessmentRepositoryProvider = Provider<AssessmentRepository>((ref) {
  return AssessmentRepository(ref.watch(apiClientProvider));
});
