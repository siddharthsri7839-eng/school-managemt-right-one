import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/api_exception.dart';
import '../domain/online_exam_models.dart';

/// All HTTP for the teacher's side of Online Exams. Mirrors the staff API
/// (Api\V1\Staff\OnlineExamController + OnlineExamBuilderController) 1:1.
///
/// The module-disabled 403 is surfaced as a forbidden ApiException so screens
/// can show the "module off" state, identical to Assessment and PTM.
class OnlineExamRepository {
  final ApiClient _apiClient;
  OnlineExamRepository(this._apiClient);

  static const _base = '/staff/online-exams';

  // ── read ──────────────────────────────────────────────────────────

  Future<ExamDashboard> getDashboard() async {
    final data = await _get('$_base/dashboard');
    return ExamDashboard.fromJson((data['data'] as Map).cast<String, dynamic>());
  }

  Future<Map<String, dynamic>> getPapers({
    String? search,
    int? classId,
    int? subjectId,
    String? kind,
    String? state,
    String? window,
    int page = 1,
  }) async {
    final data = await _get(_base, query: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (classId != null) 'school_class_id': classId,
      if (subjectId != null) 'subject_id': subjectId,
      if (kind != null && kind.isNotEmpty) 'kind': kind,
      if (state != null && state.isNotEmpty) 'state': state,
      if (window != null && window.isNotEmpty) 'window': window,
      'page': page,
    });

    return {
      'items': ((data['data'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => ExamPaper.fromJson(e.cast<String, dynamic>()))
          .toList(),
      'meta': (data['meta'] as Map?)?.cast<String, dynamic>() ?? const {},
    };
  }

  Future<ExamPaperDetail> getPaper(int examId) async {
    final data = await _get('$_base/$examId');
    return ExamPaperDetail.fromJson((data['data'] as Map).cast<String, dynamic>());
  }

  Future<List<ExamAttemptRow>> getResults(int examId) async {
    final data = await _get('$_base/$examId/results');
    return ((data['data'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => ExamAttemptRow.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> getAnalytics(int examId) async {
    final data = await _get('$_base/$examId/analytics');
    return (data['data'] as Map).cast<String, dynamic>();
  }

  // ── marking ───────────────────────────────────────────────────────

  Future<List<MarkingQueueRow>> getMarkingQueue() async {
    final data = await _get('$_base/review-queue');
    return ((data['data'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => MarkingQueueRow.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<AttemptReview> getAttemptReview(int attemptId) async {
    final data = await _get('$_base/attempts/$attemptId/review');
    return AttemptReview.fromJson((data['data'] as Map).cast<String, dynamic>());
  }

  /// Award marks to one answer.
  ///
  /// The server clamps to the question's value on this paper, so an over-typed
  /// number comes back corrected rather than rejected — the outcome is the
  /// truth, not what was sent.
  Future<AwardOutcome> award(
    int attemptId, {
    required int answerId,
    required double marks,
    String? comment,
  }) async {
    final data = await _post('$_base/attempts/$attemptId/award', {
      'answer_id': answerId,
      'marks': marks,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });

    return AwardOutcome.fromJson(data);
  }

  // ── authoring ─────────────────────────────────────────────────────

  Future<BuilderOptions> getBuilderOptions() async {
    final data = await _get('$_base/builder/options');
    return BuilderOptions.fromJson((data['data'] as Map).cast<String, dynamic>());
  }

  /// Scaffold a draft. Returns the new paper's id.
  Future<int> createDraft(Map<String, dynamic> body) async {
    final data = await _post(_base, body);
    return ((data['data'] as Map)['exam_id'] as num).toInt();
  }

  Future<ExamBuilderState> getBuilder(int examId) async {
    final data = await _get('$_base/$examId/builder');
    return ExamBuilderState.fromJson((data['data'] as Map).cast<String, dynamic>());
  }

  Future<String> updateDetails(int examId, Map<String, dynamic> body) async {
    final data = await _request('PUT', '$_base/$examId/details', body);
    return '${data['message'] ?? 'Details saved.'}';
  }

  Future<String> updateSettings(int examId, Map<String, dynamic> body) async {
    final data = await _request('PUT', '$_base/$examId/settings', body);
    return '${data['message'] ?? 'Settings saved.'}';
  }

  Future<String> addSection(int examId, Map<String, dynamic> body) async {
    final data = await _post('$_base/$examId/sections', body);
    return '${data['message'] ?? 'Section added.'}';
  }

  Future<String> updateSection(int examId, int sectionId, Map<String, dynamic> body) async {
    final data = await _request('PUT', '$_base/$examId/sections/$sectionId', body);
    return '${data['message'] ?? 'Section updated.'}';
  }

  Future<String> deleteSection(int examId, int sectionId) async {
    final data = await _request('DELETE', '$_base/$examId/sections/$sectionId', null);
    return '${data['message'] ?? 'Section removed.'}';
  }

  Future<List<PoolQuestion>> getQuestionPool(
    int examId, {
    String? search,
    int? subjectId,
    String? type,
    String? difficulty,
    int? topicId,
  }) async {
    final data = await _get('$_base/$examId/question-pool', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (subjectId != null) 'subject_id': subjectId,
      if (type != null && type.isNotEmpty) 'question_type': type,
      if (difficulty != null && difficulty.isNotEmpty) 'difficulty': difficulty,
      if (topicId != null) 'question_topic_id': topicId,
    });

    return ((data['data'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => PoolQuestion.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<String> attachQuestions(int examId, int sectionId, List<int> questionIds) async {
    final data = await _post('$_base/$examId/questions', {
      'online_exam_section_id': sectionId,
      'questions': questionIds,
    });
    return '${data['message'] ?? 'Questions added.'}';
  }

  /// `rowId` is the pivot row, not the bank question id.
  Future<String> detachQuestion(int examId, int rowId) async {
    final data = await _request('DELETE', '$_base/$examId/questions/$rowId', null);
    return '${data['message'] ?? 'Question removed.'}';
  }

  Future<String> addSchedule(int examId, Map<String, dynamic> body) async {
    final data = await _post('$_base/$examId/schedules', body);
    return '${data['message'] ?? 'Schedule added.'}';
  }

  Future<String> updateSchedule(int examId, int scheduleId, Map<String, dynamic> body) async {
    final data = await _request('PUT', '$_base/$examId/schedules/$scheduleId', body);
    return '${data['message'] ?? 'Schedule updated.'}';
  }

  Future<String> deleteSchedule(int examId, int scheduleId) async {
    final data = await _request('DELETE', '$_base/$examId/schedules/$scheduleId', null);
    return '${data['message'] ?? 'Schedule removed.'}';
  }

  /// Publish or unpublish. The server refuses a paper with no questions or no
  /// active schedule — the same rule the web builder applies, so the two cannot
  /// disagree about what is publishable.
  Future<String> publish(int examId, {bool publish = true}) async {
    final data = await _post('$_base/$examId/publish', {
      'state': publish ? 'published' : 'draft',
    });
    return '${data['message'] ?? 'Saved.'}';
  }

  // ── HTTP plumbing ─────────────────────────────────────────────────

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

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
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
    // 422s carry the server's own refusal text ("A paper must keep at least one
    // section", "Students have already sat this schedule") — those are the
    // message a teacher needs, so they must survive to the snackbar.
    return ApiException.fromDioException(e);
  }
}

final onlineExamRepositoryProvider = Provider<OnlineExamRepository>((ref) {
  return OnlineExamRepository(ref.watch(apiClientProvider));
});
