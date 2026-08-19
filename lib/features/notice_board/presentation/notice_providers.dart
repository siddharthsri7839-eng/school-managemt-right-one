import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../attendance/presentation/attendance_providers.dart';
import '../data/notice_repository.dart';

// ✅ THE FIX: Import the controller file.
import 'create_notice_controller.dart';

// A provider for the repository itself
final noticeRepositoryProvider = Provider<NoticeRepository>((ref) {
  return NoticeRepository(ref.watch(apiClientProvider));
});

// Filters State
final noticeSearchQueryProvider = StateProvider<String>((ref) => '');
final noticeRecipientTypeFilterProvider = StateProvider<String>((ref) => 'all_types');
final noticeSortOrderProvider = StateProvider<String>((ref) => 'desc');

// A provider to fetch the list of notices
final noticeListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  final search = ref.watch(noticeSearchQueryProvider);
  final recipientType = ref.watch(noticeRecipientTypeFilterProvider);
  final sort = ref.watch(noticeSortOrderProvider);

  return ref.watch(noticeRepositoryProvider).getNotices(
    search: search,
    recipientType: recipientType,
    sort: sort,
  );
});

// A provider for our new controller
final createNoticeControllerProvider = Provider.autoDispose((ref) {
  // This line will now work correctly because of the import above.
  return CreateNoticeController(ref.read(noticeRepositoryProvider));
});