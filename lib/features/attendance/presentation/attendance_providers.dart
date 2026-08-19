import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../data/attendance_repository.dart';

// These providers are still needed.
final apiClientProvider = Provider((ref) => ApiClient());
final attendanceRepositoryProvider = Provider((ref) => AttendanceRepository(ref.watch(apiClientProvider)));

// Provider to fetch the teacher's/admin's classes for the selection screen.
final classesProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(attendanceRepositoryProvider).getClassesWithSections();
});

// The old 'studentListProvider' is now replaced by the generated 'attendanceControllerProvider'.