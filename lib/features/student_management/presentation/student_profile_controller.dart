// lib/features/student_management/presentation/student_profile_controller.dart

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../data/student_repository.dart';

// This 'part' directive is required by the code generator.
// It will link to a file that will be created in the next step.
part 'student_profile_controller.g.dart';

// The @riverpod annotation tells the generator what to do.
@riverpod
class StudentProfileController extends _$StudentProfileController {
  
  // This is the main logic of your provider.
  // The 'studentId' is automatically passed because it's a family provider.
  @override
  FutureOr<Map<String, dynamic>> build(int studentId) {
    // This logic was already correct.
    final repository = StudentRepository();
    return repository.getStudentProfile(studentId: studentId);
  }
}