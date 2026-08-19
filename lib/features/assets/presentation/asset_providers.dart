import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/asset_repository.dart';

final assetDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repository = ref.watch(assetRepositoryProvider);
  return repository.getDashboard();
});
