// lib/features/attendance/presentation/attendance_controller.dart

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:intl/intl.dart';
import '../data/attendance_repository.dart';
import '../../../core/api/api_exception.dart';
import 'attendance_providers.dart';
import 'attendance_state.dart';

part 'attendance_controller.g.dart';

@riverpod
class AttendanceController extends _$AttendanceController {
  
  @override
  Future<AttendanceState> build(int sectionId, String date) async {
    final repository = ref.watch(attendanceRepositoryProvider);
    final students = await repository.getStudentsForSection(sectionId, date);
    
    final Map<int, String?> initialMap = {};
    final Set<int> lockedIds = {};

    for (var student in students) {
      final id = student['id'] as int;
      final status = student['status'] as String?;
      initialMap[id] = status;
      
      // If a status already exists from the server, lock it
      if (status != null) {
        lockedIds.add(id);
      }
    }

    // --- UX IMPROVEMENT ---
    // If it's today's date AND no attendance has been marked yet for anyone,
    // then we can safely default everyone to 'Present'.
    final isToday = date == DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (isToday && lockedIds.isEmpty) {
        for (var student in students) {
            initialMap[student['id']] = 'Present';
        }
    }

    return AttendanceState(
      students: students, 
      attendanceMap: initialMap, 
      lockedStudentIds: lockedIds,
    );
  }

  /// Updates a single student's attendance status in the local state.
  void updateStatus(int studentId, String status) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    
    // Safety check: Don't update if locked
    if (currentState.lockedStudentIds.contains(studentId)) return;

    final newMap = Map<int, String?>.from(currentState.attendanceMap);
    newMap[studentId] = status;
    
    state = AsyncValue.data(currentState.copyWith(attendanceMap: newMap));
  }

  /// Submits all attendance records to the server.
  Future<void> submitAttendance() async {
    final currentState = state.valueOrNull;
    if (currentState == null) throw Exception("State is not available to submit.");
    if (currentState.attendanceMap.isEmpty) return;

    // Filter out locked records from the submission payload 
    // (though the backend will also skip them, this reduces data transfer)
    final attendanceData = currentState.attendanceMap.entries
        .where((e) => !currentState.lockedStudentIds.contains(e.key))
        .map((e) {
      return {'student_id': e.key, 'status': e.value ?? 'Absent', 'remarks': ''};
    }).toList();

    if (attendanceData.isEmpty) {
      throw const ApiException(message: 'No new attendance records to submit. Already marked records cannot be edited.');
    }

    final repository = ref.read(attendanceRepositoryProvider);
    await repository.submitAttendance(
      sectionId: sectionId,
      date: date,
      attendances: attendanceData,
    );
  }

  /// A helper method to mark all students as present.
  void markAllAsPresent() {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    
    final newMap = Map<int, String?>.from(currentState.attendanceMap);
    for (var student in currentState.students) {
      final id = student['id'] as int;
      // Skip students who are already locked
      if (!currentState.lockedStudentIds.contains(id)) {
        newMap[id] = 'Present';
      }
    }

    state = AsyncValue.data(currentState.copyWith(attendanceMap: newMap));
  }

  /// Clears the status of every non-locked student (back to "Not Marked").
  void clearAll() {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final newMap = Map<int, String?>.from(currentState.attendanceMap);
    for (var student in currentState.students) {
      final id = student['id'] as int;
      if (!currentState.lockedStudentIds.contains(id)) {
        newMap[id] = null;
      }
    }

    state = AsyncValue.data(currentState.copyWith(attendanceMap: newMap));
  }

  /// Restores a previously captured attendance map (used for Undo).
  void restoreMap(Map<int, String?> snapshot) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(
        attendanceMap: Map<int, String?>.from(snapshot)));
  }
}