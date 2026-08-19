import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/fees_due_repository.dart';

/// Filter scaffolding: the classes/sections the user may see + the date filters.
final feesDueClassesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(feesDueRepositoryProvider).getClasses();
});
