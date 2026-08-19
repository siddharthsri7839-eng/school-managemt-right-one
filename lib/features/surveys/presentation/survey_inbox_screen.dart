import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_colors.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../data/survey_models.dart';
import 'survey_providers.dart';

/// "My Surveys" inbox — pending surveys to answer and a history of completed
/// ones. Invitation-scoped: the staff member sees only surveys they were invited
/// to (teacher evaluations, staff pulse, suggestion box, etc.).
class SurveyInboxScreen extends ConsumerWidget {
  const SurveyInboxScreen({super.key});

  static const _titleColor = Color(0xFF1E293B);
  static const _labelColor = Color(0xFF64748B);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveysState = ref.watch(mySurveysProvider);

    return MainScaffold(
      title: 'Surveys & Feedback',
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: _labelColor,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(mySurveysProvider.future),
                child: surveysState.when(
                  loading: () => SkeletonLoaders.listTile(),
                  error: (err, _) => _ErrorView(
                    message: err.toString(),
                    onRetry: () => ref.invalidate(mySurveysProvider),
                  ),
                  data: (items) {
                    final pending = items.where((i) => i.isPending).toList();
                    final completed = items.where((i) => i.responded).toList();
                    return TabBarView(
                      children: [
                        _SurveyList(
                          items: pending,
                          emptyText: 'No pending surveys. You are all caught up! 🎉',
                        ),
                        _SurveyList(
                          items: completed,
                          emptyText: 'You have not completed any surveys yet.',
                          completed: true,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurveyList extends ConsumerWidget {
  final List<SurveyInvitationSummary> items;
  final String emptyText;
  final bool completed;

  const _SurveyList({
    required this.items,
    required this.emptyText,
    this.completed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      // Wrapped in a scroll view so pull-to-refresh still works when empty.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 120, left: 32, right: 32),
            child: Text(
              emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SurveyInboxScreen._labelColor, fontSize: 15),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) => _SurveyCard(
        item: items[index],
        completed: completed,
        onTap: () async {
          final changed = await context.push<bool>(
            '/dashboard/surveys/${items[index].token}',
          );
          if (changed == true) ref.invalidate(mySurveysProvider);
        },
      ),
    );
  }
}

class _SurveyCard extends StatelessWidget {
  final SurveyInvitationSummary item;
  final bool completed;
  final VoidCallback onTap;

  const _SurveyCard({
    required this.item,
    required this.completed,
    required this.onTap,
  });

  IconData get _kindIcon {
    switch (item.survey.kind) {
      case 'poll':
        return Icons.bar_chart_rounded;
      case 'feedback_form':
        return Icons.rate_review_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final survey = item.survey;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.iconBgSurvey,
                  child: Icon(_kindIcon, color: AppColors.iconFgSurvey, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        survey.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: SurveyInboxScreen._titleColor,
                        ),
                      ),
                      if (survey.description != null && survey.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          survey.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: SurveyInboxScreen._labelColor),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _chip(survey.kindLabel, AppColors.iconFgSurvey),
                          _chip('${survey.questionCount} question${survey.questionCount == 1 ? '' : 's'}',
                              SurveyInboxScreen._labelColor),
                          if (survey.isAnonymous)
                            _chip('Anonymous', const Color(0xFF0D9488), icon: Icons.visibility_off_outlined),
                          if (completed && item.respondedAt != null)
                            _chip('Done ${DateFormat('dd MMM').format(item.respondedAt!.toLocal())}',
                                const Color(0xFF16A34A), icon: Icons.check_circle_outline),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  completed ? Icons.check_circle : Icons.chevron_right,
                  color: completed ? const Color(0xFF16A34A) : SurveyInboxScreen._labelColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
          Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
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
        Padding(
          padding: const EdgeInsets.only(top: 100, left: 32, right: 32),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 40, color: SurveyInboxScreen._labelColor),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: SurveyInboxScreen._labelColor)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }
}
