import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../data/chat_models.dart';
import 'chat_providers.dart';

/// The teacher's conversation inbox.
class ChatThreadsScreen extends ConsumerWidget {
  const ChatThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxState = ref.watch(chatInboxProvider);

    return MainScaffold(
      title: 'Messages',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/chat/new'),
        // The app theme forces CircleBorder on FABs, which clips extended
        // labels — restore the pill shape for this one.
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New chat'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(chatInboxProvider.future),
        child: inboxState.when(
          loading: () => SkeletonLoaders.listTile(),
          error: (err, _) => _ErrorView(
            message: err.toString(),
            onRetry: () => ref.invalidate(chatInboxProvider),
          ),
          data: (inbox) {
            if (inbox.threads.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.forum_outlined, size: 56, color: Colors.grey),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No conversations yet.\nStart one with "New chat".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: inbox.threads.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _ThreadTile(thread: inbox.threads[index]),
            );
          },
        ),
      ),
    );
  }
}

class _ThreadTile extends ConsumerWidget {
  final ChatThreadSummary thread;
  const _ThreadTile({required this.thread});

  String _when(DateTime? at) {
    if (at == null) return '';
    final now = DateTime.now();
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return DateFormat('h:mm a').format(at);
    }
    return DateFormat('d MMM').format(at);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isParent = thread.type == 'teacher_parent';
    final primary = Theme.of(context).colorScheme.primary;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (isParent ? Colors.orange : primary).withAlpha(30),
        child: Icon(
          isParent ? Icons.family_restroom : Icons.school_outlined,
          color: isParent ? Colors.orange : primary,
        ),
      ),
      title: Text(
        thread.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight:
              thread.unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          if (thread.isFrozen)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.lock_outline, size: 14, color: Colors.grey),
            ),
          Expanded(
            child: Text(
              thread.lastMessagePreview ?? 'Say hello 👋',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _when(thread.lastMessageAt),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          if (thread.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${thread.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
      onTap: () async {
        await context.push(
          '/dashboard/chat/thread/${thread.id}',
          extra: {'title': thread.title, 'frozen': thread.isFrozen},
        );
        // Coming back: refresh unread badges.
        ref.invalidate(chatInboxProvider);
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        Center(child: Text(message, textAlign: TextAlign.center)),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
