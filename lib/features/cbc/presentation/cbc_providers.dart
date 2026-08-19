import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/cbc_repository.dart';

final cbcDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(cbcRepositoryProvider);
  return repository.getDashboard();
});
