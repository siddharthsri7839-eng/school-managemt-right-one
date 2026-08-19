import 'package:flutter/foundation.dart';

// This class holds all the data our screen needs.
@immutable
class AttendanceState {
  final List<dynamic> students;
  final Set<int> lockedStudentIds;
  
  // This map is now nullable to handle the "Not Marked" state
  final Map<int, String?> attendanceMap;

  AttendanceState({
    required this.students, 
    required this.attendanceMap, 
    required this.lockedStudentIds,
  });

  AttendanceState copyWith({
    List<dynamic>? students,
    Map<int, String?>? attendanceMap,
    Set<int>? lockedStudentIds,
  }) {
    return AttendanceState(
      students: students ?? this.students,
      attendanceMap: attendanceMap ?? this.attendanceMap,
      lockedStudentIds: lockedStudentIds ?? this.lockedStudentIds,
    );
  }
}