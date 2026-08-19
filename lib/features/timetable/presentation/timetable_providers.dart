import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:school_erp_staff_app/features/timetable/data/timetable_repository.dart';
import 'package:school_erp_staff_app/features/timetable/domain/timetable_model.dart';

part 'timetable_providers.g.dart';

// ✅ 1. Provide the repository using a simple, standard Provider.
// This is more conventional and robust than using @riverpod for a repository.
final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  return TimetableRepository(ref.watch(apiClientProvider));
});


// ✅ 2. This @riverpod provider now correctly depends on the simple provider above.
// The generator will have no trouble understanding this.
@riverpod
Future<TimetableData> timetable(TimetableRef ref) {
  // Use 'ref.watch' to get the repository instance from the provider we defined above.
  return ref.watch(timetableRepositoryProvider).getMyTimetable();
}