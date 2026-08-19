import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import 'attendance_providers.dart';
import '../data/attendance_report_repository.dart';

final attendanceReportRepositoryProvider = Provider<AttendanceReportRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AttendanceReportRepository(apiClient);
});

final selectedReportClassProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final selectedReportSectionProvider = StateProvider<Map<String, dynamic>?>((ref) => null);
final selectedReportMonthProvider = StateProvider<int>((ref) => DateTime.now().month);
final selectedReportYearProvider = StateProvider<int>((ref) => DateTime.now().year);

final studentAttendanceReportProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final classId = ref.watch(selectedReportClassProvider)?['id'];
  final sectionId = ref.watch(selectedReportSectionProvider)?['id'];
  final month = ref.watch(selectedReportMonthProvider);
  final year = ref.watch(selectedReportYearProvider);

  if (classId == null || sectionId == null) {
    return null;
  }

  final repository = ref.watch(attendanceReportRepositoryProvider);
  return await repository.getStudentReport(
    classId: classId,
    sectionId: sectionId,
    month: month,
    year: year,
  );
});
