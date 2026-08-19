import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_providers.dart';
import '../data/chat_models.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});

/// Whether chat is enabled for this school + user. Gates the dashboard entry
/// point; never throws (the repository maps failures to `disabled`).
final chatConfigProvider = FutureProvider.autoDispose<ChatConfig>((ref) {
  return ref.watch(chatRepositoryProvider).getConfig();
});

/// The signed-in teacher's conversation inbox.
final chatInboxProvider = FutureProvider.autoDispose<ChatInbox>((ref) {
  return ref.watch(chatRepositoryProvider).getThreads();
});

/// My sections → students, for starting a new conversation.
final chatContactsProvider =
    FutureProvider.autoDispose<List<ChatSectionContacts>>((ref) {
  return ref.watch(chatRepositoryProvider).getContacts();
});
