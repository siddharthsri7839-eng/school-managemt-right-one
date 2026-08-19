// lib/features/online_exam/presentation/schedule_form_screen.dart
//
// Add a sitting: a window plus who it is for.
//
// Targets are sent as "classId" or "classId:sectionId" — the exact shape
// ExamBuilderService::syncTargets takes. A bare class id means the WHOLE class,
// and stays correct when a new section is added to that class later, which is
// why "All sections" is offered as a real choice rather than as every section
// ticked.

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

class ScheduleFormScreen extends ConsumerStatefulWidget {
  final int examId;
  const ScheduleFormScreen({super.key, required this.examId});

  @override
  ConsumerState<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends ConsumerState<ScheduleFormScreen> {
  final _title = TextEditingController(text: 'Main schedule');
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(hours: 1));
  final _targets = <String>{};
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool isStart}) async {
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

    setState(() {
      final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);

      if (isStart) {
        _start = picked;
        // The server requires ends_at after starts_at; keep them consistent
        // rather than failing validation at the end of the form.
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 1));
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_targets.isEmpty) {
      _say('Choose at least one class or section.');
      return;
    }

    setState(() => _busy = true);

    try {
      final message = await ref.read(onlineExamRepositoryProvider).addSchedule(
        widget.examId,
        {
          'title': _title.text.trim(),
          'starts_at': _start.toIso8601String(),
          'ends_at': _end.toIso8601String(),
          'is_active': true,
          'targets': _targets.toList(),
        },
      );

      if (!mounted) return;

      _say(message);
      ref.invalidate(examBuilderProvider(widget.examId));
      context.pop();
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
    final options = ref.watch(builderOptionsProvider);

    return MainScaffold(
      title: 'Add schedule',
      body: options.when(
        loading: () => SkeletonLoaders.cardList(),
        error: (err, _) => ApiErrorWidget(
          error: err,
          onRetry: () => ref.invalidate(builderOptionsProvider),
        ),
        data: (opts) {
          if (opts.classes.isEmpty) {
            return const ExamEmptyState(
              icon: Icons.school_outlined,
              title: 'No classes assigned',
              message: 'You can only schedule papers for classes you teach.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow_rounded, size: 18),
                title: const Text('Opens', style: TextStyle(fontSize: 13)),
                trailing: Text(_fmt(_start),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onTap: () => _pick(isStart: true),
              ),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stop_rounded, size: 18),
                title: const Text('Closes', style: TextStyle(fontSize: 13)),
                trailing: Text(_fmt(_end),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                onTap: () => _pick(isStart: false),
              ),
              const Divider(height: 24),
              const Text(
                'Who sits it',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                'Choosing a whole class keeps working when a new section is added to it.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              ...opts.classes.map((c) {
                final sections = opts.sectionsFor(c.id);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${c.name} — all sections',
                          style: const TextStyle(fontSize: 13)),
                      value: _targets.contains('${c.id}'),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _targets.add('${c.id}');
                          // A whole-class target supersedes its sections; keeping
                          // both would create duplicate rows the server then
                          // collapses anyway.
                          _targets.removeWhere((t) => t.startsWith('${c.id}:'));
                        } else {
                          _targets.remove('${c.id}');
                        }
                      }),
                    ),
                    ...sections.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.name, style: const TextStyle(fontSize: 12.5)),
                          value: _targets.contains('${c.id}:${s.id}'),
                          onChanged: _targets.contains('${c.id}')
                              ? null // already covered by the whole class
                              : (v) => setState(() {
                                    if (v == true) {
                                      _targets.add('${c.id}:${s.id}');
                                    } else {
                                      _targets.remove('${c.id}:${s.id}');
                                    }
                                  }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                );
              }),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Add schedule'),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
