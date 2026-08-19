// lib/features/online_exam/presentation/exam_create_screen.dart
//
// Quick Setup: scaffold a draft, then go straight into the builder.
//
// Deliberately the ONLY way to start a paper, mirroring the web panel where
// having two entry points meant the button a teacher happened to press decided
// how capable their paper was. This creates a draft with one section and one
// schedule; everything else is the builder's job.
//
// Nothing here is visible to a student: papers are created as drafts and
// nobody is notified until publish.

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

class ExamCreateScreen extends ConsumerStatefulWidget {
  const ExamCreateScreen({super.key});

  @override
  ConsumerState<ExamCreateScreen> createState() => _ExamCreateScreenState();
}

class _ExamCreateScreenState extends ConsumerState<ExamCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _duration = TextEditingController(text: '30');

  String _type = ExamKind.exam;
  int? _classId;
  int? _sectionId;
  int? _subjectId;
  DateTime _start = DateTime.now().add(const Duration(days: 1));
  DateTime _end = DateTime.now().add(const Duration(days: 1, hours: 1));
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_classId == null || _sectionId == null || _subjectId == null) {
      _say('Choose a class, section and subject.');
      return;
    }

    setState(() => _busy = true);

    try {
      final examId = await ref.read(onlineExamRepositoryProvider).createDraft({
        'title': _title.text.trim(),
        'type': _type,
        'school_class_id': _classId,
        'section_id': _sectionId,
        'subject_id': _subjectId,
        'duration_minutes': int.tryParse(_duration.text.trim()) ?? 30,
        'start_time': _start.toIso8601String(),
        'end_time': _end.toIso8601String(),
      });

      if (!mounted) return;

      ref.invalidate(papersProvider);
      ref.invalidate(examDashboardProvider);

      // Replace rather than push: coming "back" to a create form for a paper
      // that now exists would invite a duplicate.
      context.pushReplacement('/dashboard/online-exams/$examId/builder');
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } catch (_) {
      if (mounted) _say('Could not create the draft. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : _end;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null || !mounted) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    setState(() {
      if (isStart) {
        _start = picked;
        // The server rejects an end before the start; fix it here rather than
        // letting the teacher fill the whole form and then be refused.
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(builderOptionsProvider);

    return MainScaffold(
      title: 'New paper',
      body: options.when(
        loading: () => SkeletonLoaders.cardList(),
        error: (err, _) {
          if (err is ApiException && err.message == 'module_disabled') {
            return const OnlineExamModuleDisabled();
          }
          return ApiErrorWidget(
            error: err,
            onRetry: () => ref.invalidate(builderOptionsProvider),
          );
        },
        data: (opts) {
          if (opts.classes.isEmpty) {
            return const ExamEmptyState(
              icon: Icons.school_outlined,
              title: 'No classes assigned',
              message: 'You can only create papers for classes you teach.',
            );
          }

          final sections = opts.sectionsFor(_classId);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Title *',
                    hintText: 'e.g. Unit Test 1 — Algebra',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Give the paper a title.' : null,
                ),
                const SizedBox(height: 14),

                const _FieldLabel('Delivery mode'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: ExamKind.exam, label: Text('Exam')),
                    ButtonSegment(value: ExamKind.quiz, label: Text('Quiz')),
                    ButtonSegment(value: ExamKind.practice, label: Text('Practice')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    // The three modes mean different things; say which is which
                    // here rather than letting a teacher find out afterwards.
                    switch (_type) {
                      ExamKind.quiz => 'Short, scored, usually retakeable.',
                      ExamKind.practice =>
                        'Untimed, no deadline, answers checked as the student goes.',
                      _ => 'One sitting against the clock, scored.',
                    },
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<int>(
                  initialValue: _classId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Class *',
                    border: OutlineInputBorder(),
                  ),
                  items: opts.classes
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _classId = v;
                    _sectionId = null; // sections belong to a class
                  }),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<int>(
                  initialValue: _sectionId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Section *',
                    border: const OutlineInputBorder(),
                    helperText: _classId == null ? 'Choose a class first' : null,
                  ),
                  items: sections
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: sections.isEmpty ? null : (v) => setState(() => _sectionId = v),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<int>(
                  initialValue: _subjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    border: OutlineInputBorder(),
                  ),
                  items: opts.subjects
                      .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _subjectId = v),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _duration,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Duration (minutes) *',
                    border: const OutlineInputBorder(),
                    helperText: _type == ExamKind.practice
                        ? 'Practice sets ignore the clock — this is just stored.'
                        : null,
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return (n == null || n < 1) ? 'Enter a duration.' : null;
                  },
                ),
                const SizedBox(height: 14),

                const _FieldLabel('Window'),
                _DateRow(label: 'Opens', value: _start, onTap: () => _pickDate(isStart: true)),
                _DateRow(label: 'Closes', value: _end, onTap: () => _pickDate(isStart: false)),
                if (_type == ExamKind.practice)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'A practice set is always open — these dates are stored but not enforced.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),

                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'This creates a draft. Next you add sections, questions and '
                    'schedules — nothing is visible to students and nobody is '
                    'notified until you publish.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create draft'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  const _DateRow({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_outlined, size: 18),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: Text(
        '${value.day}/${value.month}/${value.year} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    );
  }
}
