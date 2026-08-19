import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/ptm_repository.dart';

final ptmDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(ptmRepositoryProvider);
  return repository.getDashboard();
});

final ptmReportMeetingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(ptmRepositoryProvider);
  return repository.getReportMeetings();
});

final selectedPtmMeetingIdProvider = StateProvider.autoDispose<int?>((ref) => null);

final ptmReportDataProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final meetingId = ref.watch(selectedPtmMeetingIdProvider);
  if (meetingId == null) {
    return null;
  }
  final repository = ref.watch(ptmRepositoryProvider);
  return repository.getReportData(meetingId);
});

final ptmRecordMeetingsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, page) async {
  final repository = ref.watch(ptmRepositoryProvider);
  return repository.getRecordMeetings(page: page);
});

final ptmRecordRosterProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, meetingId) async {
  final repository = ref.watch(ptmRepositoryProvider);
  return repository.getRecordRoster(meetingId);
});

