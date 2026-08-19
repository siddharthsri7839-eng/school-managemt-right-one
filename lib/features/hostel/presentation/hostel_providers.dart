import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/hostel_repository.dart';

final hostelDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(hostelRepositoryProvider);
  return repository.getDashboard();
});
