import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/front_office_repository.dart';

final frontOfficeStatusFilterProvider = StateProvider.autoDispose<String>((ref) => 'All');
final frontOfficeSortProvider = StateProvider.autoDispose<String?>((ref) => null);

final frontOfficeDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(frontOfficeRepositoryProvider);
  final status = ref.watch(frontOfficeStatusFilterProvider);
  final sortFollowup = ref.watch(frontOfficeSortProvider);
  
  return repository.getDashboard(status: status, sortFollowup: sortFollowup);
});
