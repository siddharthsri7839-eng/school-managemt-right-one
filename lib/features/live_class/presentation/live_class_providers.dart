import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../data/live_class_repository.dart';
import '../data/models/live_class.dart';

final liveClassRepositoryProvider = Provider<LiveClassRepository>(
  (ref) => LiveClassRepository(ref.watch(apiClientProvider)),
);

/// Upcoming + past classes for the list screen.
final liveClassesProvider =
    FutureProvider.autoDispose<({List<LiveClass> upcoming, List<LiveClass> past})>(
  (ref) => ref.watch(liveClassRepositoryProvider).getClasses(),
);

/// Form sources for the schedule screen, re-fetched per selected class so the
/// section and subject lists follow the cascade.
final liveClassFormDataProvider =
    FutureProvider.autoDispose.family<LiveClassFormData, int?>(
  (ref, schoolClassId) =>
      ref.watch(liveClassRepositoryProvider).getFormData(schoolClassId: schoolClassId),
);
