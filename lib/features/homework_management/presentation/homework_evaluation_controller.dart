import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/homework_repository.dart';

class HomeworkEvaluationController {
  final HomeworkRepository _repository;
  HomeworkEvaluationController(this._repository);

  Future<void> submitEvaluation({
    required int submissionId,
    required String marks,
    String? remarks,
  }) async {
    await _repository.evaluateSubmission(
      submissionId: submissionId,
      marks: marks,
      remarks: remarks,
    );
  }
}