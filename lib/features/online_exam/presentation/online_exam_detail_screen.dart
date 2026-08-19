// lib/features/online_exam/presentation/online_exam_detail_screen.dart
//
// One paper: its structure, who sat it, and how the questions behaved.
//
// Three tabs rather than one long scroll, because the three answer different
// questions — "what is this paper", "how did they do", "which items are wrong".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../domain/online_exam_models.dart';
import 'online_exam_providers.dart';
import 'online_exam_widgets.dart';

class OnlineExamDetailScreen extends ConsumerWidget {
  final int examId;
  const OnlineExamDetailScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperDetailProvider(examId));

    return DefaultTabController(
      length: 3,
      child: MainScaffold(
        title: 'Paper',
        actions: [
          IconButton(
            tooltip: 'Edit paper',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/dashboard/online-exams/$examId/builder'),
          ),
        ],
        body: state.when(
          loading: () => SkeletonLoaders.cardList(),
          error: (err, _) => ListView(
            children: [
              const SizedBox(height: 100),
              ApiErrorWidget(
                error: err,
                onRetry: () => ref.invalidate(paperDetailProvider(examId)),
              ),
            ],
          ),
          data: (detail) => Column(
            children: [
              _PaperHeader(detail: detail, examId: examId),
              const ExamTabBar(tabs: ['Structure', 'Results', 'Analytics']),
              Expanded(
                child: TabBarView(
                  children: [
                    _StructureTab(detail: detail),
                    _ResultsTab(examId: examId),
                    _AnalyticsTab(examId: examId),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperHeader extends StatelessWidget {
  final ExamPaperDetail detail;
  final int examId;

  const _PaperHeader({required this.detail, required this.examId});

  @override
  Widget build(BuildContext context) {
    final paper = detail.paper;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExamKindBadge(type: paper.type),
              const SizedBox(width: 6),
              ExamStateChip(paper: paper),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            paper.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 2),
          Text(
            '${paper.subject} · ${paper.className}'
            '${paper.section != null ? ' ${paper.section}' : ''} · '
            '${paper.questionCount} questions · '
            '${paper.totalMarks.toStringAsFixed(paper.totalMarks % 1 == 0 ? 0 : 1)} marks',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          // Marking is the only thing on this screen anyone is blocked on.
          if (detail.pendingReview > 0) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => context.push('/dashboard/online-exams/marking'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD98A00).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.rate_review_outlined,
                        size: 15, color: Color(0xFFD98A00)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${detail.pendingReview} '
                        '${detail.pendingReview == 1 ? 'answer needs' : 'answers need'} marking',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD98A00),
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        size: 18, color: Color(0xFFD98A00)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StructureTab extends StatelessWidget {
  final ExamPaperDetail detail;
  const _StructureTab({required this.detail});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _TabHeading('Sections'),
        ...detail.sections.map(
          (section) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.layers_outlined, size: 18),
            title: Text(section.name, style: const TextStyle(fontSize: 13)),
            trailing: Text(
              '${section.questionCount} '
              '${section.questionCount == 1 ? 'question' : 'questions'}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _TabHeading('Schedules'),
        if (detail.schedules.isEmpty)
          Text(
            // A paper with no schedule falls back to its own class/section and
            // dates — legacy, but still sittable, so say so rather than
            // implying it is broken.
            'No schedule rows — this paper uses its own class and dates.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          )
        else
          ...detail.schedules.map((s) => _ScheduleTile(schedule: s)),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final ExamSchedule schedule;
  const _ScheduleTile({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final labels = schedule.targetLabels.isNotEmpty
        ? schedule.targetLabels.toSet().join(', ')
        : '${schedule.targets.length} target(s)';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        schedule.isActive ? Icons.event_available_outlined : Icons.event_busy_outlined,
        size: 18,
        color: schedule.isActive ? null : Colors.grey,
      ),
      title: Text(
        schedule.title ?? 'Schedule',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '$labels · ${_range(schedule)}',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      trailing: Text(
        schedule.state,
        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
      ),
    );
  }

  String _range(ExamSchedule s) {
    String fmt(DateTime? d) => d == null
        ? '—'
        : '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:'
            '${d.minute.toString().padLeft(2, '0')}';

    return '${fmt(s.startsAt)} → ${fmt(s.endsAt)}';
  }
}

class _ResultsTab extends ConsumerWidget {
  final int examId;
  const _ResultsTab({required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperResultsProvider(examId));

    return state.when(
      loading: () => SkeletonLoaders.cardList(),
      error: (err, _) => ApiErrorWidget(
        error: err,
        onRetry: () => ref.invalidate(paperResultsProvider(examId)),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const ExamEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Nobody has sat it yet',
            message: 'Results appear here as students submit.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final row = rows[i];

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(row.student, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                row.awaitingReview
                    // Not a score yet — saying "0%" here would be a lie about a
                    // student who may have answered everything correctly.
                    ? 'Awaiting marking'
                    : row.inProgress
                        ? 'Still sitting'
                        : '${row.score.toStringAsFixed(row.score % 1 == 0 ? 0 : 1)}'
                            ' / ${row.maxScore.toStringAsFixed(row.maxScore % 1 == 0 ? 0 : 1)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              trailing: row.awaitingReview || row.inProgress
                  ? Icon(
                      row.inProgress ? Icons.timelapse_rounded : Icons.rate_review_outlined,
                      size: 17,
                      color: const Color(0xFFD98A00),
                    )
                  : Text(
                      '${row.percentage.round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
            );
          },
        );
      },
    );
  }
}

class _AnalyticsTab extends ConsumerWidget {
  final int examId;
  const _AnalyticsTab({required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paperAnalyticsProvider(examId));

    return state.when(
      loading: () => SkeletonLoaders.cardList(),
      error: (err, _) => ApiErrorWidget(
        error: err,
        onRetry: () => ref.invalidate(paperAnalyticsProvider(examId)),
      ),
      data: (data) {
        final items = ((data['items'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();

        if (items.isEmpty) {
          return const ExamEmptyState(
            icon: Icons.insights_outlined,
            title: 'No analytics yet',
            message: 'Item analysis needs sittings to work from.',
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const _TabHeading('Item analysis'),
            Text(
              // Says what the numbers mean, so the screen is usable by someone
              // who has never met the term "discrimination index".
              'How many got each question right, and whether the strong students '
              'did better on it than the weak ones.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ...items.map(_itemRow),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final correctPct = (item['correct_percentage'] as num?)?.toDouble() ??
        ((item['p_value'] as num?)?.toDouble() ?? 0) * 100;
    final discrimination = (item['discrimination'] as num?)?.toDouble() ??
        (item['discrimination_index'] as num?)?.toDouble();
    final suspect = item['state'] == 'suspect' || item['calibration_state'] == 'suspect';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (item['question'] ?? '').toString(),
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (suspect)
                const Tooltip(
                  // Negative discrimination usually means a wrong answer key,
                  // which is worth flagging louder than any accuracy figure.
                  message: 'Strong students did worse on this — check the answer key',
                  child: Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFD9534F)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (correctPct / 100).clamp(0, 1),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFEEF1F5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${correctPct.round()}% correct',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
              ),
              if (discrimination != null) ...[
                const SizedBox(width: 8),
                Text(
                  'D ${discrimination.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: discrimination < 0 ? const Color(0xFFD9534F) : Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TabHeading extends StatelessWidget {
  final String text;
  const _TabHeading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      );
}
