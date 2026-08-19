// lib/features/online_exam/presentation/online_exam_list_screen.dart
//
// The teacher's paper list, with the same filters as the web screen so someone
// who knows one knows the other: kind, state and window as one-tap chips, class
// and subject in a sheet, plus search.
//
// Window state is derived from the clock server-side, never stored — the chips
// send `upcoming|open|closed` and the API turns them into date predicates.

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

class OnlineExamListScreen extends ConsumerStatefulWidget {
  const OnlineExamListScreen({super.key});

  @override
  ConsumerState<OnlineExamListScreen> createState() => _OnlineExamListScreenState();
}

class _OnlineExamListScreenState extends ConsumerState<OnlineExamListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(papersProvider);
    final filters = ref.watch(paperFiltersProvider);

    return MainScaffold(
      title: 'Papers',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/online-exams/create'),
        icon: const Icon(Icons.add),
        label: const Text('New paper'),
      ),
      body: Column(
        children: [
          _FilterBar(search: _search),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.refresh(papersProvider.future),
              child: state.when(
                loading: () => SkeletonLoaders.cardList(),
                error: (err, _) {
                  if (err is ApiException && err.message == 'module_disabled') {
                    return const OnlineExamModuleDisabled();
                  }
                  return ListView(
                    children: [
                      const SizedBox(height: 80),
                      ApiErrorWidget(
                        error: err,
                        onRetry: () => ref.invalidate(papersProvider),
                      ),
                    ],
                  );
                },
                data: (data) {
                  final papers = (data['items'] as List).cast<ExamPaper>();

                  if (papers.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 60),
                        // The two empties are different problems and deserve
                        // different answers.
                        filters.isEmpty
                            ? const ExamEmptyState(
                                icon: Icons.description_outlined,
                                title: 'No papers yet',
                                message: 'Create one with the button below.',
                              )
                            : ExamEmptyState(
                                icon: Icons.filter_alt_off_outlined,
                                title: 'Nothing matches',
                                message: 'No papers match these filters.',
                                action: TextButton(
                                  onPressed: () {
                                    _search.clear();
                                    ref.read(paperFiltersProvider.notifier).state =
                                        const PaperFilters();
                                  },
                                  child: const Text('Clear filters'),
                                ),
                              ),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: papers.length,
                    itemBuilder: (context, i) => _PaperCard(paper: papers[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final TextEditingController search;
  const _FilterBar({required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(paperFiltersProvider);
    final notifier = ref.read(paperFiltersProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) =>
                notifier.state = filters.copyWith(search: value.trim()),
            decoration: InputDecoration(
              hintText: 'Search papers',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: (filters.search ?? '').isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        search.clear();
                        notifier.state = filters.copyWith(search: null);
                      },
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Container(
          height: 46,
          // Separates the filter bar from the list scrolling beneath it.
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            children: [
              _chip(
                label: 'Exams',
                selected: filters.kind == ExamKind.exam,
                onTap: () => notifier.state = filters.copyWith(
                  kind: filters.kind == ExamKind.exam ? null : ExamKind.exam,
                ),
              ),
              _chip(
                label: 'Quizzes',
                selected: filters.kind == ExamKind.quiz,
                onTap: () => notifier.state = filters.copyWith(
                  kind: filters.kind == ExamKind.quiz ? null : ExamKind.quiz,
                ),
              ),
              _chip(
                label: 'Practice',
                selected: filters.kind == ExamKind.practice,
                onTap: () => notifier.state = filters.copyWith(
                  kind: filters.kind == ExamKind.practice ? null : ExamKind.practice,
                ),
              ),
              const _Divider(),
              _chip(
                label: 'Drafts',
                selected: filters.state == 'draft',
                onTap: () => notifier.state = filters.copyWith(
                  state: filters.state == 'draft' ? null : 'draft',
                ),
              ),
              _chip(
                label: 'Open now',
                selected: filters.window == 'open',
                onTap: () => notifier.state = filters.copyWith(
                  window: filters.window == 'open' ? null : 'open',
                ),
              ),
              _chip(
                label: 'Upcoming',
                selected: filters.window == 'upcoming',
                onTap: () => notifier.state = filters.copyWith(
                  window: filters.window == 'upcoming' ? null : 'upcoming',
                ),
              ),
              _chip(
                label: 'Closed',
                selected: filters.window == 'closed',
                onTap: () => notifier.state = filters.copyWith(
                  window: filters.window == 'closed' ? null : 'closed',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        // No inline TextStyle: the chip theme resolves the label colour from
        // the selected state, and a local style would be merged over it.
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: VerticalDivider(width: 1, color: Colors.grey.shade300),
      );
}

class _PaperCard extends StatelessWidget {
  final ExamPaper paper;
  const _PaperCard({required this.paper});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/dashboard/online-exams/${paper.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
              const SizedBox(height: 8),
              Text(
                paper.title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${paper.subject} · ${paper.className}'
                '${paper.section != null ? ' ${paper.section}' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.help_outline_rounded, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(
                    '${paper.questionCount} '
                    '${paper.questionCount == 1 ? 'question' : 'questions'}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.timer_outlined, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(
                    // Practice papers obey no clock; printing a duration for
                    // them was the web list's old bug.
                    paper.isTimed ? '${paper.duration ?? 0} min' : 'Untimed',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  const Spacer(),
                  Text(
                    '${paper.totalMarks.toStringAsFixed(paper.totalMarks % 1 == 0 ? 0 : 1)} marks',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
