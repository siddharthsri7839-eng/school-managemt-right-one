import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/features/attendance/data/attendance_repository.dart';
import '../data/homework_repository.dart';

// ✅ 1. IMPORT the original provider, DO NOT redefine it here.
import '../../../core/api/api_providers.dart';

import 'homework_evaluation_controller.dart';

// ✅ 2. REMOVE this duplicate line. It's already defined in core/api/api_providers.dart
// final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// This provider now correctly injects the single, central ApiClient provider.
final classRepositoryProvider = Provider((ref) => AttendanceRepository(ref.watch(apiClientProvider)));

// This provider was already correct
final homeworkRepositoryProvider = Provider((ref) => HomeworkRepository(ref.watch(apiClientProvider)));

// Provider to fetch classes for the homework screen
final homeworkClassesProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(classRepositoryProvider).getClassesWithSections();
});

// Provider to fetch subjects for a given class ID
final subjectsProvider = FutureProvider.autoDispose.family<List<dynamic>, int>((ref, classId) {
  return ref.watch(homeworkRepositoryProvider).getSubjectsForClass(classId);
});

// Provider to fetch the list of homework
final homeworkListProvider = AutoDisposeFutureProvider<List<dynamic>>((ref) {
  return ref.watch(homeworkRepositoryProvider).getHomeworkList();
});

// Provider to fetch the details of a single homework assignment
final homeworkDetailsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, homeworkId) {
  return ref.watch(homeworkRepositoryProvider).getHomeworkDetails(homeworkId);
});

// Provider for the evaluation logic controller
final homeworkEvaluationControllerProvider = Provider.autoDispose((ref) {
  return HomeworkEvaluationController(ref.read(homeworkRepositoryProvider));
});