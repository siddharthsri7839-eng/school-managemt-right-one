import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package:school_erp_staff_app/features/dashboard/presentation/dashboard_controller.dart';
import '../data/exam_repository.dart';

final examControllerProvider =
    AsyncNotifierProvider<ExamController, List<dynamic>>(
  ExamController.new,
);

class ExamController extends AsyncNotifier<List<dynamic>> {
  final _repository = ExamRepository();

  @override
  FutureOr<List<dynamic>> build() {
    final selectedChild = ref.watch(dashboardControllerProvider).value?.selectedChild;
    if (selectedChild == null) throw 'No student selected.';

    return _repository.getExamList(studentId: selectedChild['id']);
  }
}