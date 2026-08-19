// lib/features/exam_marks/presentation/marks_controller.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import '../data/marks_repository.dart';
import '../domain/marks_models.dart';

part 'marks_controller.g.dart';

// Provider for the repository
@riverpod
MarksRepository marksRepository(MarksRepositoryRef ref) {
  return MarksRepository(ref.watch(apiClientProvider));
}

// Manages the state for the selection screen dropdowns
@riverpod
class MarksSelection extends _$MarksSelection {
  @override
  Future<Map<String, dynamic>> build() async {
    return ref.watch(marksRepositoryProvider).getOptions();
  }

  // ✅ ADD THIS METHOD to fetch classes dynamically
  Future<List<SchoolClass>> getClassesForExam(int examId) {
    return ref.read(marksRepositoryProvider).getClassesForExam(examId);
  }  

  Future<List<Section>> getSections(int classId) {
    return ref.read(marksRepositoryProvider).getSections(classId);
  }
}

// The main controller for the marks entry data
@riverpod
class MarksEntryController extends _$MarksEntryController {
  
  @override
  Future<Map<String, dynamic>> build({
    required int examId, required int classId, required int sectionId
  }) {
    return ref.watch(marksRepositoryProvider).getStudentsAndStructure(
      examId: examId, classId: classId, sectionId: sectionId
    );
  }

  // Method to update marks in the local state
  void updateMark(int studentId, int distributionId, String? marks) {
    state.whenData((value) {
      final student = value['students'].firstWhere((s) => s.id == studentId);
      final mark = student.marks.firstWhere((m) => m.distributionId == distributionId);
      mark.marksObtained = (marks == null || marks.isEmpty) ? null : double.tryParse(marks);
      state = AsyncData(Map.from(value)); // Trigger a rebuild
    });
  }

  // Method to update attendance in the local state
  void updateAttendance(int studentId, int distributionId, bool isAbsent) {
    state.whenData((value) {
      final student = value['students'].firstWhere((s) => s.id == studentId);
      final mark = student.marks.firstWhere((m) => m.distributionId == distributionId);
      mark.attendanceStatus = isAbsent ? 'absent' : 'present';
      if(isAbsent) mark.marksObtained = null; // Clear marks if absent
      state = AsyncData(Map.from(value)); // Trigger a rebuild
    });
  }

  // Autosave a subset of cells (one row, one bulk batch) WITHOUT refetching,
  // so in-progress local edits are preserved. Local model is already updated
  // by updateMark/updateAttendance before this is called.
  Future<String> saveCells(List<Map<String, dynamic>> cells) async {
    if (cells.isEmpty) return 'Nothing to save.';
    return ref.read(marksRepositoryProvider).saveMarks(cells);
  }

  // Method to save all marks to the server
  Future<String> saveAllMarks() async {
    if (!state.hasValue) throw 'No data to save.';
    
    final List<StudentMarksEntry> students = state.value!['students'];
    final List<Map<String, dynamic>> payload = [];

    for (var student in students) {
      for (var mark in student.marks) {
        payload.add({
          'student_id': student.id,
          'distribution_id': mark.distributionId,
          'marks_obtained': mark.marksObtained,
          'attendance_status': mark.attendanceStatus,
        });
      }
    }
    
    final message = await ref.read(marksRepositoryProvider).saveMarks(payload);
    // Invalidate the provider to refetch data if needed, or just return success
    ref.invalidateSelf(); 
    return message;
  }
}