import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/assessment_repository.dart';
import '../domain/assessment_models.dart';

/// Dashboard KPIs + recents + capabilities.
final assessmentDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(assessmentRepositoryProvider).getDashboard();
});

/// Dropdown scaffolding for the create/edit form.
final assessmentFormOptionsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(assessmentRepositoryProvider).getFormOptions();
});

/// Full assessment detail (header + sittings).
final assessmentDetailProvider =
    FutureProvider.autoDispose.family<AssessmentDetail, int>((ref, id) async {
  return ref.watch(assessmentRepositoryProvider).getDetail(id);
});

/// Mark-entry grid for one sitting.
final markGridProvider =
    FutureProvider.autoDispose.family<MarkGrid, int>((ref, occurrenceId) async {
  return ref.watch(assessmentRepositoryProvider).getGrid(occurrenceId);
});

/// Report filter scaffolding (classes/types, + subjects for a chosen class).
final reportFiltersProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int?>((ref, classId) async {
  return ref.watch(assessmentRepositoryProvider).reportFilters(classId: classId);
});
