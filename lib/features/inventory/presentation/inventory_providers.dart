import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/inventory_repository.dart';

final inventoryDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.getDashboard();
});
