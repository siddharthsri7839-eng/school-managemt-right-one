import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/online_exam_repository.dart';
import '../domain/online_exam_models.dart';

/// Filters on the paper list. Kept in one object so a change to any of them is
/// a single provider invalidation rather than five.
class PaperFilters {
  final String? search;
  final int? classId;
  final int? subjectId;
  final String? kind;
  final String? state;
  final String? window;

  const PaperFilters({
    this.search,
    this.classId,
    this.subjectId,
    this.kind,
    this.state,
    this.window,
  });

  PaperFilters copyWith({
    Object? search = _keep,
    Object? classId = _keep,
    Object? subjectId = _keep,
    Object? kind = _keep,
    Object? state = _keep,
    Object? window = _keep,
  }) {
    // A sentinel rather than null-coalescing: every one of these is nullable and
    // "clear this filter" has to be expressible.
    return PaperFilters(
      search: search == _keep ? this.search : search as String?,
      classId: classId == _keep ? this.classId : classId as int?,
      subjectId: subjectId == _keep ? this.subjectId : subjectId as int?,
      kind: kind == _keep ? this.kind : kind as String?,
      state: state == _keep ? this.state : state as String?,
      window: window == _keep ? this.window : window as String?,
    );
  }

  bool get isEmpty =>
      (search == null || search!.isEmpty) &&
      classId == null &&
      subjectId == null &&
      kind == null &&
      state == null &&
      window == null;

  static const _keep = Object();

  @override
  bool operator ==(Object other) =>
      other is PaperFilters &&
      other.search == search &&
      other.classId == classId &&
      other.subjectId == subjectId &&
      other.kind == kind &&
      other.state == state &&
      other.window == window;

  @override
  int get hashCode => Object.hash(search, classId, subjectId, kind, state, window);
}

/// The module dashboard, already narrowed to the teacher's classes server-side.
final examDashboardProvider = FutureProvider.autoDispose<ExamDashboard>((ref) {
  return ref.watch(onlineExamRepositoryProvider).getDashboard();
});

/// Current filter selection for the paper list.
final paperFiltersProvider =
    StateProvider.autoDispose<PaperFilters>((ref) => const PaperFilters());

/// The paper list for the active filters.
final papersProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final filters = ref.watch(paperFiltersProvider);

  return ref.watch(onlineExamRepositoryProvider).getPapers(
        search: filters.search,
        classId: filters.classId,
        subjectId: filters.subjectId,
        kind: filters.kind,
        state: filters.state,
        window: filters.window,
      );
});

final paperDetailProvider =
    FutureProvider.autoDispose.family<ExamPaperDetail, int>((ref, examId) {
  return ref.watch(onlineExamRepositoryProvider).getPaper(examId);
});

final paperResultsProvider =
    FutureProvider.autoDispose.family<List<ExamAttemptRow>, int>((ref, examId) {
  return ref.watch(onlineExamRepositoryProvider).getResults(examId);
});

final paperAnalyticsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, examId) {
  return ref.watch(onlineExamRepositoryProvider).getAnalytics(examId);
});

/// Everything waiting on a human, across every paper in scope.
final markingQueueProvider =
    FutureProvider.autoDispose<List<MarkingQueueRow>>((ref) {
  return ref.watch(onlineExamRepositoryProvider).getMarkingQueue();
});

/// One attempt open for marking. autoDispose so re-entering after an award
/// refetches rather than showing answers that have already been graded.
final attemptReviewProvider =
    FutureProvider.autoDispose.family<AttemptReview, int>((ref, attemptId) {
  return ref.watch(onlineExamRepositoryProvider).getAttemptReview(attemptId);
});

/// Dropdown scaffolding for the authoring screens.
final builderOptionsProvider = FutureProvider.autoDispose<BuilderOptions>((ref) {
  return ref.watch(onlineExamRepositoryProvider).getBuilderOptions();
});

/// The paper being authored.
final examBuilderProvider =
    FutureProvider.autoDispose.family<ExamBuilderState, int>((ref, examId) {
  return ref.watch(onlineExamRepositoryProvider).getBuilder(examId);
});

/// Filters on the question picker.
class PoolFilters {
  final String? search;
  final String? type;
  final String? difficulty;
  final int? topicId;

  const PoolFilters({this.search, this.type, this.difficulty, this.topicId});

  @override
  bool operator ==(Object other) =>
      other is PoolFilters &&
      other.search == search &&
      other.type == type &&
      other.difficulty == difficulty &&
      other.topicId == topicId;

  @override
  int get hashCode => Object.hash(search, type, difficulty, topicId);
}

/// The bank minus what is already on this paper.
final questionPoolProvider = FutureProvider.autoDispose
    .family<List<PoolQuestion>, ({int examId, PoolFilters filters})>((ref, args) {
  return ref.watch(onlineExamRepositoryProvider).getQuestionPool(
        args.examId,
        search: args.filters.search,
        type: args.filters.type,
        difficulty: args.filters.difficulty,
        topicId: args.filters.topicId,
      );
});
