// lib/features/online_exam/presentation/marking_queue_screen.dart
//
// Everything waiting on a human, across every paper the teacher can see.
//
// This is the screen that justifies the module being on a phone at all: a
// written answer parks the WHOLE attempt in `submitted_pending_review`, so
// until someone marks it that student has no result. Marking is a queue of
// small, self-contained tasks — the one exam workflow that suits five spare
// minutes on a bus.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../domain/online_exam_models.dart';
import 'online_exam_providers.dart';
import 'online_exam_widgets.dart';

class MarkingQueueScreen extends ConsumerWidget {
  const MarkingQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(markingQueueProvider);

    return MainScaffold(
      title: 'Marking',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(markingQueueProvider.future),
        child: state.when(
          loading: () => SkeletonLoaders.cardList(),
          error: (err, _) {
            if (err is ApiException && err.message == 'module_disabled') {
              return const OnlineExamModuleDisabled();
            }
            return ListView(
              children: [
                const SizedBox(height: 100),
                ApiErrorWidget(
                  error: err,
                  onRetry: () => ref.invalidate(markingQueueProvider),
                ),
              ],
            );
          },
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  ExamEmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Nothing to mark',
                    message: 'Every written answer on your papers has been graded.',
                  ),
                ],
              );
            }

            final total = rows.fold<int>(0, (sum, r) => sum + r.pending);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  '$total ${total == 1 ? 'answer' : 'answers'} across '
                  '${rows.length} ${rows.length == 1 ? 'paper' : 'papers'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                ...rows.map((row) => _QueuePaperCard(row: row)),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One paper, expandable into the students waiting on it.
class _QueuePaperCard extends StatelessWidget {
  final MarkingQueueRow row;
  const _QueuePaperCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        // Open by default: the point of the screen is to start marking, not to
        // browse a list of papers.
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          row.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${row.subject} · ${row.className}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFD98A00).withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${row.pending}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Color(0xFFD98A00),
            ),
          ),
        ),
        children: row.attempts
            .map(
              (attempt) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    attempt.student.isEmpty ? '?' : attempt.student.characters.first,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                title: Text(attempt.student, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${attempt.pending} ${attempt.pending == 1 ? 'answer' : 'answers'} to mark',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(
                  '/dashboard/online-exams/marking/${attempt.attemptId}',
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
