import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/app_colors.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../data/models/live_class.dart';
import 'live_class_providers.dart';

class LiveClassListScreen extends ConsumerStatefulWidget {
  const LiveClassListScreen({super.key});

  @override
  ConsumerState<LiveClassListScreen> createState() => _LiveClassListScreenState();
}

class _LiveClassListScreenState extends ConsumerState<LiveClassListScreen> {
  bool _busy = false;

  Future<void> _refresh() async {
    ref.invalidate(liveClassesProvider);
    await ref.read(liveClassesProvider.future);
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  /// Start the class, then follow the join context the backend hands back.
  ///
  /// The mode comes from the provider, never from inspecting the URL — Jitsi
  /// embeds, Zoom returns a start_url, external mirrors a pasted link.
  Future<void> _start(LiveClass liveClass) async {
    setState(() => _busy = true);
    try {
      final context = await ref.read(liveClassRepositoryProvider).start(liveClass.id);
      await _openJoinUrl(context);
      ref.invalidate(liveClassesProvider);
    } on ApiException catch (e) {
      _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openJoinUrl(JoinContext joinContext) async {
    final uri = Uri.tryParse(joinContext.url);
    if (uri == null) {
      _snack('The provider returned an invalid meeting link.', isError: true);
      return;
    }

    // Everything hands off externally for now: the provider apps (Zoom, Jitsi)
    // give a far better call than a plain webview, and the browser handles the
    // embed room page fine. An in-app embedded room can replace this branch
    // without touching the API contract.
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      _snack('Could not open the meeting. Is a browser installed?', isError: true);
    }
  }

  Future<void> _end(LiveClass liveClass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this class?'),
        content: const Text(
          'Anyone still in the meeting will be marked as having left now.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End class')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(liveClassRepositoryProvider).end(liveClass.id);
      _snack('Live class ended.');
      ref.invalidate(liveClassesProvider);
    } on ApiException catch (e) {
      _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(LiveClass liveClass) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this class?'),
        content: Text(
          liveClass.isRecurring
              ? 'This removes only this occurrence. The rest of the series stays.'
              : 'The meeting will be cancelled with the provider as well.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(liveClassRepositoryProvider).delete(liveClass.id);
      _snack('Live class deleted.');
      ref.invalidate(liveClassesProvider);
    } on ApiException catch (e) {
      _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(liveClassesProvider);

    return MainScaffold(
      title: 'Live Classes',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/live-classes/schedule'),
        backgroundColor: AppColors.accent,
        // The app theme sets shape: CircleBorder() for FABs, which is right for
        // the circular ones everywhere else but squashes an extended FAB into a
        // circle and clips its label. Override locally rather than changing the
        // theme — this is the only extended FAB in the app.
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Schedule', style: TextStyle(color: Colors.white)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ApiErrorWidget(error: e, onRetry: _refresh),
        data: (data) {
          if (data.upcoming.isEmpty && data.past.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.videocam_off_outlined, size: 56, color: AppColors.textHint),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No live classes yet',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Schedule one and your students will see it in their app.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (data.upcoming.isNotEmpty) ...[
                  const _Heading('Upcoming'),
                  ...data.upcoming.map(
                    (c) => _LiveClassCard(
                      liveClass: c,
                      busy: _busy,
                      onStart: () => _start(c),
                      onEnd: () => _end(c),
                      onEdit: () =>
                          context.push('/dashboard/live-classes/${c.id}/edit', extra: c),
                      onDelete: () => _delete(c),
                    ),
                  ),
                ],
                if (data.past.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _Heading('Past'),
                  ...data.past.map(
                    (c) => _LiveClassCard(
                      liveClass: c,
                      busy: _busy,
                      isPast: true,
                      onDelete: () => _delete(c),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

class _LiveClassCard extends StatelessWidget {
  final LiveClass liveClass;
  final bool busy;
  final bool isPast;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _LiveClassCard({
    required this.liveClass,
    required this.busy,
    this.isPast = false,
    this.onStart,
    this.onEnd,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final start = liveClass.startTime;
    final when = start == null
        ? 'No start time'
        : '${DateFormat('EEE d MMM').format(start)} · ${DateFormat('h:mm a').format(start)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: liveClass.isLive ? AppColors.success : AppColors.border,
          width: liveClass.isLive ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  liveClass.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isPast ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
              ),
              if (liveClass.isLive) const _Pill(text: 'LIVE', color: AppColors.success),
              if (liveClass.isRecurring && !liveClass.isLive)
                const _Pill(text: 'Series', color: AppColors.info),
            ],
          ),
          const SizedBox(height: 8),
          _MetaRow(icon: Icons.schedule, text: '$when · ${liveClass.durationMinutes} min'),
          if (liveClass.whereLabel.isNotEmpty)
            _MetaRow(icon: Icons.groups_outlined, text: liveClass.whereLabel),
          if (liveClass.subjectName != null)
            _MetaRow(icon: Icons.book_outlined, text: liveClass.subjectName!),

          const SizedBox(height: 12),
          Row(
            children: [
              if (!isPast && onStart != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          liveClass.isLive ? AppColors.success : AppColors.accent,
                    ),
                    icon: Icon(
                      liveClass.isLive ? Icons.login : Icons.videocam,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      liveClass.isLive ? 'Rejoin' : 'Start',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              if (!isPast && liveClass.isLive && onEnd != null) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: busy ? null : onEnd,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('End'),
                ),
              ],
              const Spacer(),
              if (!isPast && onEdit != null)
                IconButton(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                  tooltip: 'Edit',
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: busy ? null : onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'Delete',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
        ),
      );
}
