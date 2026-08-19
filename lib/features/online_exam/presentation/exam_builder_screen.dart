// lib/features/online_exam/presentation/exam_builder_screen.dart
//
// The mobile builder: Details · Settings · Sections · Questions · Schedules.
//
// Tabs, not a wizard — the same choice the web builder makes. Editing a
// paper's schedule should not mean stepping past its questions.
//
// Publish is refused by the SERVER when the paper has no questions or no active
// schedule (ExamBuilderService::publishBlocker). The app reads that same
// blocker rather than re-deriving it, so the button is never offered for
// something the server would reject.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../data/online_exam_repository.dart';
import '../domain/online_exam_models.dart';
import 'online_exam_providers.dart';
import 'online_exam_widgets.dart';

class ExamBuilderScreen extends ConsumerWidget {
  final int examId;
  const ExamBuilderScreen({super.key, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examBuilderProvider(examId));

    return DefaultTabController(
      length: 5,
      child: MainScaffold(
        title: 'Build paper',
        body: state.when(
          loading: () => SkeletonLoaders.cardList(),
          error: (err, _) {
            if (err is ApiException && err.message == 'module_disabled') {
              return const OnlineExamModuleDisabled();
            }
            return ApiErrorWidget(
              error: err,
              onRetry: () => ref.invalidate(examBuilderProvider(examId)),
            );
          },
          data: (paper) => Column(
            children: [
              _BuilderHeader(paper: paper, examId: examId),
              const ExamTabBar(
                scrollable: true,
                tabs: ['Details', 'Settings', 'Sections', 'Questions', 'Schedules'],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _DetailsTab(examId: examId, paper: paper),
                    _SettingsTab(examId: examId, paper: paper),
                    _SectionsTab(examId: examId, paper: paper),
                    _QuestionsTab(examId: examId, paper: paper),
                    _SchedulesTab(examId: examId, paper: paper),
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

class _BuilderHeader extends ConsumerStatefulWidget {
  final ExamBuilderState paper;
  final int examId;

  const _BuilderHeader({required this.paper, required this.examId});

  @override
  ConsumerState<_BuilderHeader> createState() => _BuilderHeaderState();
}

class _BuilderHeaderState extends ConsumerState<_BuilderHeader> {
  bool _busy = false;

  Future<void> _togglePublish() async {
    final paper = widget.paper;

    if (!paper.isPublished && !paper.canPublish) {
      _say(paper.publishBlocker!);
      return;
    }

    if (paper.isPublished) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Move back to draft?'),
          content: const Text(
            'Students will no longer see this paper. Attempts already taken are kept.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unpublish')),
          ],
        ),
      );

      if (ok != true) return;
    }

    setState(() => _busy = true);

    try {
      final message = await ref.read(onlineExamRepositoryProvider).publish(
            widget.examId,
            publish: !paper.isPublished,
          );

      if (!mounted) return;

      _say(message);
      ref.invalidate(examBuilderProvider(widget.examId));
      ref.invalidate(papersProvider);
      ref.invalidate(examDashboardProvider);
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final paper = widget.paper;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExamKindBadge(type: paper.type),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (paper.isPublished ? const Color(0xFF1E9E6A) : Colors.orange.shade700)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  paper.isPublished ? 'Published' : 'Draft',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: paper.isPublished
                        ? const Color(0xFF1E9E6A)
                        : Colors.orange.shade700,
                  ),
                ),
              ),
              const Spacer(),
              _busy
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: _togglePublish,
                      child: Text(paper.isPublished ? 'Unpublish' : 'Publish'),
                    ),
            ],
          ),
          Text(
            paper.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${paper.questionCount} questions · '
            '${paper.totalMarks.toStringAsFixed(paper.totalMarks % 1 == 0 ? 0 : 1)} marks',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),

          // Why it cannot go live yet, said before the teacher tries.
          if (!paper.isPublished && paper.publishBlocker != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.orange.shade800),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      paper.publishBlocker!,
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── step 1: details ────────────────────────────────────────────────────────

class _DetailsTab extends ConsumerStatefulWidget {
  final int examId;
  final ExamBuilderState paper;

  const _DetailsTab({required this.examId, required this.paper});

  @override
  ConsumerState<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends ConsumerState<_DetailsTab> {
  late final TextEditingController _title;
  late final TextEditingController _duration;
  late final TextEditingController _passing;
  late String _type;
  int? _subjectId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.paper.title);
    _duration = TextEditingController(text: '${widget.paper.durationMinutes}');
    _passing = TextEditingController(text: '${widget.paper.passingMarks ?? 0}');
    _type = widget.paper.type;
    _subjectId = widget.paper.subjectId;
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _passing.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);

    try {
      final message = await ref.read(onlineExamRepositoryProvider).updateDetails(
        widget.examId,
        {
          'title': _title.text.trim(),
          'type': _type,
          'subject_id': _subjectId,
          'duration_minutes': int.tryParse(_duration.text.trim()) ?? 30,
          'passing_marks': int.tryParse(_passing.text.trim()) ?? 0,
        },
      );

      if (!mounted) return;
      _snack(context, message);
      ref.invalidate(examBuilderProvider(widget.examId));
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(builderOptionsProvider);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: ExamKind.exam, label: Text('Exam')),
            ButtonSegment(value: ExamKind.quiz, label: Text('Quiz')),
            ButtonSegment(value: ExamKind.practice, label: Text('Practice')),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 12),
        options.maybeWhen(
          data: (opts) => DropdownButtonFormField<int>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
            items: opts.subjects
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (v) => setState(() => _subjectId = v),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _duration,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration (minutes)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passing,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Passing marks',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save details'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ── step 2: settings ───────────────────────────────────────────────────────

class _SettingsTab extends ConsumerStatefulWidget {
  final int examId;
  final ExamBuilderState paper;

  const _SettingsTab({required this.examId, required this.paper});

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  late Map<String, dynamic> _s;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _s = Map<String, dynamic>.from(widget.paper.settings);
  }

  bool _flag(String key, [bool fallback = false]) => _s[key] == true || (_s[key] == null && fallback);

  Future<void> _save() async {
    setState(() => _busy = true);

    try {
      final message = await ref.read(onlineExamRepositoryProvider).updateSettings(
        widget.examId,
        {
          // The two `required` fields on the server must always be present, so
          // they carry a default rather than being sent null.
          'marks_mode': _s['marks_mode'] ?? 'manual',
          'section_navigation': _s['section_navigation'] ?? 'free',
          'show_result_mode': _s['show_result_mode'] ?? 'immediate',
          'base_marks': _s['base_marks'],
          'negative_ratio': _s['negative_ratio'],
          'max_attempts': _s['max_attempts'],
          for (final key in _flags) key: _flag(key),
        },
      );

      if (!mounted) return;
      _snack(context, message);
      ref.invalidate(examBuilderProvider(widget.examId));
    } on ApiException catch (e) {
      if (mounted) _snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const _flags = [
    'negative_marking', 'partial_credit', 'shuffle_questions', 'shuffle_options',
    'section_cutoff_enabled', 'restrict_attempts', 'hide_solutions',
    'show_leaderboard', 'allow_review', 'show_difficulty',
    'disable_finish_button', 'question_list_view',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _dropdown(
          label: 'Marks mode',
          value: _s['marks_mode'] ?? 'manual',
          items: const {'manual': 'Per question', 'auto': 'Auto by difficulty'},
          onChanged: (v) => setState(() => _s['marks_mode'] = v),
          help: 'Auto derives each question\'s marks from its difficulty weight.',
        ),
        _dropdown(
          label: 'Section navigation',
          value: _s['section_navigation'] ?? 'free',
          items: const {'free': 'Move freely', 'locked': 'One section at a time'},
          onChanged: (v) => setState(() => _s['section_navigation'] = v),
        ),
        _dropdown(
          label: 'Show results',
          value: _s['show_result_mode'] ?? 'immediate',
          items: const {
            'immediate': 'Straight away',
            'after_close': 'After the paper closes',
            'manual': 'When I release them',
          },
          onChanged: (v) => setState(() => _s['show_result_mode'] = v),
        ),
        const Divider(height: 24),
        _switch('shuffle_questions', 'Shuffle questions'),
        _switch('shuffle_options', 'Shuffle options'),
        _switch('negative_marking', 'Negative marking'),
        _switch('partial_credit', 'Partial credit',
            help: 'Multi-answer questions score proportionally.'),
        _switch('restrict_attempts', 'Limit attempts'),
        _switch('allow_review', 'Let students review answers afterwards'),
        _switch('hide_solutions', 'Hide solutions'),
        _switch('show_leaderboard', 'Show leaderboard'),
        _switch('show_difficulty', 'Show difficulty to students'),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save settings'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
    String? help,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : items.keys.first,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: help,
          helperMaxLines: 2,
        ),
        items: items.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _switch(String key, String label, {String? help}) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: help == null
          ? null
          : Text(help, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      value: _flag(key),
      onChanged: (v) => setState(() => _s[key] = v),
    );
  }
}

// ── step 3: sections ───────────────────────────────────────────────────────

class _SectionsTab extends ConsumerWidget {
  final int examId;
  final ExamBuilderState paper;

  const _SectionsTab({required this.examId, required this.paper});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New section'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Section B'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final message =
          await ref.read(onlineExamRepositoryProvider).addSection(examId, {'name': name});
      if (context.mounted) _snack(context, message);
      ref.invalidate(examBuilderProvider(examId));
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, BuilderSection section) async {
    try {
      // The server moves the questions to the first surviving section rather
      // than deleting them, and refuses outright if this is the last one.
      final message =
          await ref.read(onlineExamRepositoryProvider).deleteSection(examId, section.id);
      if (context.mounted) _snack(context, message);
      ref.invalidate(examBuilderProvider(examId));
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ...paper.sections.map(
          (section) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              dense: true,
              title: Text(section.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                '${section.questions.length} '
                '${section.questions.length == 1 ? 'question' : 'questions'}'
                '${section.isOptional ? ' · optional' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 19),
                onPressed: () => _delete(context, ref, section),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _add(context, ref),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add section'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ── step 4: questions ──────────────────────────────────────────────────────

class _QuestionsTab extends ConsumerWidget {
  final int examId;
  final ExamBuilderState paper;

  const _QuestionsTab({required this.examId, required this.paper});

  Future<void> _detach(BuildContext context, WidgetRef ref, BuilderQuestion q) async {
    try {
      // rowId, not questionId: the pivot row is what a detach targets.
      final message =
          await ref.read(onlineExamRepositoryProvider).detachQuestion(examId, q.rowId);
      if (context.mounted) _snack(context, message);
      ref.invalidate(examBuilderProvider(examId));
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Difficulty balance',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              DifficultyBalanceBar(bands: paper.balance),
            ],
          ),
        ),

        // Advisory only — never blocks, exactly as on the web builder.
        if (paper.exposure?.hasWarning == true) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD98A00).withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt_rounded, size: 15, color: Color(0xFFD98A00)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${paper.exposure!.exposed} of ${paper.exposure!.total} questions here '
                    'have already been practised by ${paper.exposure!.threshold}+ students, '
                    'with the solution shown. Scores on them will read higher than they should.',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),
        ...paper.sections.map(
          (section) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      section.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(
                      '/dashboard/online-exams/$examId/questions/${section.id}',
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add'),
                  ),
                ],
              ),

              // The blueprint asked for more of a band than the section holds —
              // the whole reason anyone maintains a difficulty tag.
              if (section.shortfall.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Short of: ${section.shortfall.map((s) => '${s['label'] ?? s['band']} ×${s['short']}').join(', ')}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFD9534F)),
                  ),
                ),

              if (section.questions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'No questions in this section yet.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                )
              else
                ...section.questions.map(
                  (q) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      q.question,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${q.type} · ${q.difficulty} · '
                      '${q.marks.toStringAsFixed(q.marks % 1 == 0 ? 0 : 1)} marks',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 17),
                      onPressed: () => _detach(context, ref, q),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ── step 5: schedules ──────────────────────────────────────────────────────

class _SchedulesTab extends ConsumerWidget {
  final int examId;
  final ExamBuilderState paper;

  const _SchedulesTab({required this.examId, required this.paper});

  Future<void> _delete(BuildContext context, WidgetRef ref, ExamSchedule s) async {
    try {
      final message =
          await ref.read(onlineExamRepositoryProvider).deleteSchedule(examId, s.id);
      if (context.mounted) _snack(context, message);
      ref.invalidate(examBuilderProvider(examId));
    } on ApiException catch (e) {
      // "Students have already sat this schedule" arrives here as a 422 —
      // the server's own words are the message the teacher needs.
      if (context.mounted) _snack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text(
          'A schedule is one sitting: a window plus who it is for. The same paper '
          'can run for two classes on different days without being duplicated.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        ...paper.schedules.map(
          (s) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              dense: true,
              title: Text(s.title ?? 'Schedule', style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                '${s.targets.length} target(s) · ${s.state}'
                '${s.isActive ? '' : ' · inactive'}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              trailing: s.hasAttempts
                  // Deleting one students have sat would strand their attempts.
                  ? Tooltip(
                      message: 'Students have sat this — deactivate instead',
                      child: Icon(Icons.lock_outline, size: 17, color: Colors.grey.shade500),
                    )
                  : IconButton(
                      icon: const Icon(Icons.delete_outline, size: 19),
                      onPressed: () => _delete(context, ref, s),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.push('/dashboard/online-exams/$examId/schedules'),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add schedule'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
