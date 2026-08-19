import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../data/communication_log_model.dart';
import '../data/communication_log_repository.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final communicationLogRepositoryProvider = Provider<CommunicationLogRepository>((ref) {
  return CommunicationLogRepository(ApiClient());
});

// ── Filter / Search State ─────────────────────────────────────────────────────

/// Active channel filter. null = all channels.
final communicationLogChannelFilterProvider = StateProvider<String?>((ref) => null);

/// Search query text.
final communicationLogSearchProvider = StateProvider<String>((ref) => '');

/// Current page for pagination.
final communicationLogPageProvider = StateProvider<int>((ref) => 1);

// ── Data Provider ─────────────────────────────────────────────────────────────

/// Fetches communication logs based on current filter/search/page state.
///
/// Auto-disposes when the screen is unmounted. Watching the filter/search/page
/// providers causes automatic re-fetch when any of them change.
final communicationLogProvider = FutureProvider.autoDispose<CommunicationLogResponse>((ref) {
  final repo = ref.watch(communicationLogRepositoryProvider);
  final channel = ref.watch(communicationLogChannelFilterProvider);
  final search = ref.watch(communicationLogSearchProvider);
  final page = ref.watch(communicationLogPageProvider);

  return repo.getLogs(
    channel: channel,
    search: search.isEmpty ? null : search,
    page: page,
  );
});
