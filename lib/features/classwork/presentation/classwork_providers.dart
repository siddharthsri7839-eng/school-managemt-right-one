import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import '../data/classwork_repository.dart';

final classworkRepositoryProvider = Provider((ref) => ClassworkRepository(ref.watch(apiClientProvider)));

final classworkListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(classworkRepositoryProvider).getClassworkList();
});

final classworkDetailsProvider = FutureProvider.family.autoDispose<Map<String, dynamic>, int>((ref, id) {
  return ref.watch(classworkRepositoryProvider).getClassworkDetails(id);
});
