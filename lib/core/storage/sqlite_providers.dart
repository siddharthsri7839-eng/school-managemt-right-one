import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sqlite_service.dart';

final sqliteServiceProvider = Provider<SqliteService>((ref) {
  return SqliteService.instance;
});

final sqliteSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final service = ref.watch(sqliteServiceProvider);
  return await service.getDatabaseSummary();
});

final sqliteStudentsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(sqliteServiceProvider);
  return await service.getStudents();
});

final sqliteStaffProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(sqliteServiceProvider);
  return await service.getStaff();
});

final sqliteNoticesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(sqliteServiceProvider);
  return await service.getNotices();
});

final sqliteAttendanceProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(sqliteServiceProvider);
  return await service.getAttendanceLogs();
});
