// lib/features/online_exam/presentation/question_picker_screen.dart
//
// Pick questions from the bank into one section.
//
// The pool already excludes what is on the paper, so re-adding is not offered.
// Multi-select then one Add, because attaching one at a time over a phone
// connection is the slowest possible way to build a paper.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../data/online_exam_repository.dart';
import 'online_exam_providers.dart';
import 'online_exam_widgets.dart';

class QuestionPickerScreen extends ConsumerStatefulWidget {
  final int examId;
  final int sectionId;

  const QuestionPickerScreen({
    super.key,
    required this.examId,
    required this.sectionId,
  });

  @override
  ConsumerState<QuestionPickerScreen> createState() => _QuestionPickerScreenState();
}

class _QuestionPickerScreenState extends ConsumerState<QuestionPickerScreen> {
  final _search = TextEditingController();
  final _selected = <int>{};
  PoolFilters _filters = const PoolFilters();
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_selected.isEmpty) return;

    setState(() => _busy = true);

    try {
      final message = await ref.read(onlineExamRepositoryProvider).attachQuestions(
            widget.examId,
            widget.sectionId,
            _selected.toList(),
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));

      ref.invalidate(examBuilderProvider(widget.examId));
      context.pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = ref.watch(
      questionPoolProvider((examId: widget.examId, filters: _filters)),
    );
    final options = ref.watch(builderOptionsProvider);

    return MainScaffold(
      title: 'Add questions',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => setState(() {
                _filters = PoolFilters(
                  search: v.trim(),
                  type: _filters.type,
                  difficulty: _filters.difficulty,
                  topicId: _filters.topicId,
                );
              }),
              decoration: const InputDecoration(
                hintText: 'Search the bank',
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          options.maybeWhen(
            // A border under the filter bar, so a scrolled list reads as
            // passing beneath it rather than as a broken layout.
            data: (opts) => Container(
              height: 46,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                children: [
                  // Band labels come from the school's own registry — never
                  // hard-code easy/medium/hard.
                  for (final band in opts.bands)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        // No inline TextStyle: the chip theme resolves the label
                        // colour from the selected state, and a local style
                        // would be merged over it.
                        label: Text(band.label),
                        selected: _filters.difficulty == band.key,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() {
                          _filters = PoolFilters(
                            search: _filters.search,
                            type: _filters.type,
                            difficulty:
                                _filters.difficulty == band.key ? null : band.key,
                            topicId: _filters.topicId,
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: pool.when(
              loading: () => SkeletonLoaders.cardList(),
              error: (err, _) => ApiErrorWidget(
                error: err,
                onRetry: () => ref.invalidate(
                  questionPoolProvider((examId: widget.examId, filters: _filters)),
                ),
              ),
              data: (questions) {
                if (questions.isEmpty) {
                  return const ExamEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Nothing to add',
                    message:
                        'Every matching question is already on this paper, or the '
                        'bank has none for these filters.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                  itemCount: questions.length,
                  itemBuilder: (context, i) {
                    final q = questions[i];
                    final picked = _selected.contains(q.id);

                    return CheckboxListTile(
                      dense: true,
                      value: picked,
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(q.id);
                        } else {
                          _selected.remove(q.id);
                        }
                      }),
                      title: Text(
                        q.question,
                        style: const TextStyle(fontSize: 12.5),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${q.type} · ${q.difficulty} · '
                        '${q.marks.toStringAsFixed(q.marks % 1 == 0 ? 0 : 1)} marks',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selected.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _add,
              icon: _busy
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.playlist_add_check),
              label: Text('Add ${_selected.length}'),
            ),
    );
  }
}
