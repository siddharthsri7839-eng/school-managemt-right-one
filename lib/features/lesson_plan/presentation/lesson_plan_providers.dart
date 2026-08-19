import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/lesson_plan_repository.dart';

final lessonPlanDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(lessonPlanRepositoryProvider);
  return repository.getDashboard();
});
