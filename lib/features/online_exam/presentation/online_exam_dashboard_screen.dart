// lib/features/online_exam/presentation/online_exam_dashboard_screen.dart
//
// The module's landing screen for a teacher.
//
// It answers "what needs me?" before "what exists?" — marking first, because
// unmarked written answers hold whole attempts in `submitted_pending_review`
// and nothing else in the module is blocked on a person.
//
// Every figure arrives already narrowed to the classes this teacher is allotted
// (the API does it through OnlineExamDashboardService's classIds hook), so
// nothing here filters again.

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

class OnlineExamDashboardScreen extends ConsumerWidget {
  const OnlineExamDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examDashboardProvider);

    return MainScaffold(
      title: 'Online Exams',
      actions: [
        IconButton(
          tooltip: 'All papers',
          icon: const Icon(Icons.list_alt_rounded),
          onPressed: () => context.push('/dashboard/online-exams/papers'),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/online-exams/create'),
        icon: const Icon(Icons.add),
        label: const Text('New paper'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(examDashboardProvider.future),
        child: state.when(
          loading: () => SkeletonLoaders.dashboard(),
          error: (err, _) {
            if (err is ApiException && err.message == 'module_disabled') {
              return const OnlineExamModuleDisabled();
            }
            return ListView(
              children: [
                const SizedBox(height: 100),
                ApiErrorWidget(
                  error: err,
                  onRetry: () => ref.invalidate(examDashboardProvider),
                ),
              ],
            );
          },
          data: (data) => _body(context, data),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ExamDashboard data) {
    final pending = (data.pendingReview['answers'] as num?)?.toInt() ??
        (data.pendingReview['total'] as num?)?.toInt() ??
        0;
    final sitting = (data.liveNow['students'] as num?)?.toInt() ??
        (data.liveNow['attempts'] as num?)?.toInt() ??
        0;
    final bankSize = (data.questionBank['total'] as num?)?.toInt() ?? 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        if (data.scoped)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.filter_alt_outlined, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Showing the classes you teach.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),

        // Marking leads: it is the only figure here that is blocked on a person.
        if (pending > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _MarkingCallout(pending: pending),
          ),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.55,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            ExamStatTile(
              label: 'Live papers',
              value: '${data.published}',
              icon: Icons.description_outlined,
              color: kExamColor,
              caption: data.drafts > 0 ? '${data.drafts} in draft' : null,
              onTap: () => context.push('/dashboard/online-exams/papers'),
            ),
            ExamStatTile(
              label: 'Sitting now',
              value: '$sitting',
              icon: Icons.play_circle_outline,
              color: const Color(0xFF1E9E6A),
              // Not every in-progress row: the API counts recent activity only,
              // or sittings abandoned days ago would inflate this into noise.
              caption: 'Active in the last 30 min',
            ),
            ExamStatTile(
              label: 'Awaiting marking',
              value: '$pending',
              icon: Icons.rate_review_outlined,
              color: const Color(0xFFD98A00),
              caption: pending == 0 ? 'Nothing waiting' : 'Written answers',
              onTap: pending == 0
                  ? null
                  : () => context.push('/dashboard/online-exams/marking'),
            ),
            ExamStatTile(
              label: 'Question bank',
              value: '$bankSize',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xFF7A4FE0),
              caption: 'Questions available',
            ),
          ],
        ),

        if (data.closingSoon > 0) ...[
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.schedule_rounded,
            color: const Color(0xFFD98A00),
            text: '${data.closingSoon} '
                '${data.closingSoon == 1 ? 'paper closes' : 'papers close'} this week.',
          ),
        ],

        if (data.lowTurnout.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle('Poor turnout'),
          const SizedBox(height: 6),
          ...data.lowTurnout.map((row) => _TurnoutCard(row: row)),
        ],

        if (data.recentPapers.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionTitle('Recent papers'),
          const SizedBox(height: 6),
          ...data.recentPapers.map(
            (paper) => _RecentPaperCard(
              paper: paper,
              onTap: () => context.push('/dashboard/online-exams/${paper.examId}'),
            ),
          ),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      );
}

class _MarkingCallout extends StatelessWidget {
  final int pending;
  const _MarkingCallout({required this.pending});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/dashboard/online-exams/marking'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFD98A00).withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD98A00).withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.rate_review_rounded, color: Color(0xFFD98A00)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pending ${pending == 1 ? 'answer needs' : 'answers need'} marking',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // Says why it matters, not just that it exists.
                    'Those students have no result until you mark them.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFD98A00)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}

class _TurnoutCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _TurnoutCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final title = row['title']?.toString() ?? 'Untitled';
    final sat = (row['sat'] as num?)?.toInt() ?? 0;
    final eligible = (row['eligible'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        dense: true,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '$sat of $eligible have sat it',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: Text(
          eligible > 0 ? '${(sat / eligible * 100).round()}%' : '—',
          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFD9534F)),
        ),
      ),
    );
  }
}

class _RecentPaperCard extends StatelessWidget {
  final RecentPaper paper;
  final VoidCallback onTap;

  const _RecentPaperCard({required this.paper, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        title: Row(
          children: [
            Expanded(
              child: Text(paper.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            ExamKindBadge(type: paper.type),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            paper.isPractice
                // A practice set is not scored against a cohort, so an average
                // would be a number that means nothing.
                ? '${paper.subject} · not counted'
                : _stats(paper),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }

  String _stats(RecentPaper paper) {
    final parts = <String>['${paper.students} sat'];

    if (paper.avgPercentage != null) parts.add('avg ${paper.avgPercentage}%');
    if (paper.hardAccuracy != null && paper.hardBand != null) {
      parts.add('${paper.hardBand}: ${paper.hardAccuracy}%');
    }

    return parts.join(' · ');
  }
}
