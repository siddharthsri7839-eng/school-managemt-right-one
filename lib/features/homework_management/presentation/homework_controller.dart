import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/homework_repository.dart';

// ✅ THE FIX: Import the file where 'homeworkRepositoryProvider' is defined.
import 'homework_providers.dart';

// This provider is for the controller that handles the 'create' logic.
final createHomeworkControllerProvider = Provider.autoDispose((ref) {
  // This line will now work because of the import above.
  return CreateHomeworkController(ref.read(homeworkRepositoryProvider));
});

class CreateHomeworkController {
  final HomeworkRepository _repository;
  CreateHomeworkController(this._repository);

  Future<void> create({
    required int classId,
    required int sectionId,
    required int subjectId,
    required String title,
    required String dueDate,
    String? description,
    String? filePath,
  }) async {
    await _repository.createHomework(
      classId: classId,
      sectionId: sectionId,
      subjectId: subjectId,
      title: title,
      dueDate: dueDate,
      description: description,
      filePath: filePath,
    );
  }
}