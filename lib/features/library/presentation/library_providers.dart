import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/library_repository.dart';

final libraryDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(libraryRepositoryProvider);
  return repository.getDashboard();
});
