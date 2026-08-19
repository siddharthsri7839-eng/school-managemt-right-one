import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/app_colors.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../data/models/live_class.dart';
import 'live_class_providers.dart';

/// Schedule a new live class, or edit an existing one.
///
/// Provider choice is catalogue-driven: the options come from the school's
/// enabled providers, so a school with Zoom configured sees Zoom and one
/// without does not. Nothing here hardcodes a provider key except the
/// `needs_link` behaviour the backend itself declares.
class LiveClassFormScreen extends ConsumerStatefulWidget {
  final LiveClass? existing;

  const LiveClassFormScreen({super.key, this.existing});

  @override
  ConsumerState<LiveClassFormScreen> createState() => _LiveClassFormScreenState();
}

class _LiveClassFormScreenState extends ConsumerState<LiveClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _durationController = TextEditingController(text: '45');

  int? _classId;
  int? _sectionId;
  int? _subjectId;
  String? _providerKey;
  DateTime? _startTime;
  String _recurrence = 'none';
  DateTime? _recurrenceEnd;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description ?? '';
      _linkController.text = existing.meetingLink ?? '';
      _durationController.text = '${existing.durationMinutes}';
      _classId = existing.schoolClassId;
      _sectionId = existing.sectionId;
      _subjectId = existing.subjectId;
      _providerKey = existing.provider;
      _startTime = existing.startTime;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _startTime ?? now.add(const Duration(hours: 1)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime ?? now),
    );
    if (time == null) return;

    setState(() {
      _startTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _pickRecurrenceEnd() async {
    final base = _startTime ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _recurrenceEnd ?? base.add(const Duration(days: 7)),
      firstDate: base,
      lastDate: base.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _recurrenceEnd = date);
  }

  Future<void> _submit(List<MeetingProviderOption> providers) async {
    if (!_formKey.currentState!.validate()) return;

    if (_startTime == null) {
      _snack('Pick a start date and time.', isError: true);
      return;
    }
    if (_classId == null || _sectionId == null || _subjectId == null) {
      _snack('Pick a class, section and subject.', isError: true);
      return;
    }
    if (_providerKey == null) {
      _snack('Pick where the meeting happens.', isError: true);
      return;
    }
    if (_recurrence != 'none' && _recurrenceEnd == null) {
      _snack('Pick a date for the series to end.', isError: true);
      return;
    }

    final payload = <String, dynamic>{
      'school_class_id': _classId,
      'section_id': _sectionId,
      'subject_id': _subjectId,
      'title': _titleController.text.trim(),
      // Send local wall-clock time; the backend stores it in the school's zone.
      'start_time': DateFormat('yyyy-MM-dd HH:mm:ss').format(_startTime!),
      'duration_minutes': int.tryParse(_durationController.text.trim()) ?? 45,
      'provider': _providerKey,
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
      if (_linkController.text.trim().isNotEmpty)
        'meeting_link': _linkController.text.trim(),
    };

    // Recurrence is create-only: editing one occurrence must not silently
    // regenerate the series, which is how the web panel behaves too.
    if (!_isEdit && _recurrence != 'none') {
      payload['recurrence'] = _recurrence;
      payload['recurrence_end_date'] = DateFormat('yyyy-MM-dd').format(_recurrenceEnd!);
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(liveClassRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.existing!.id, payload);
      } else {
        await repo.create(payload);
      }

      ref.invalidate(liveClassesProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _snack(_isEdit ? 'Live class updated.' : 'Live class scheduled.');
    } on ApiException catch (e) {
      // Provider failures ("Could not create the meeting with Zoom: ...") are
      // the message that actually helps, so show it rather than a generic one.
      _snack(e.message, isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  @override
  Widget build(BuildContext context) {
    // Re-fetched whenever the chosen class changes, which is what drives the
    // section and subject lists.
    final async = ref.watch(liveClassFormDataProvider(_classId));

    return MainScaffold(
      title: _isEdit ? 'Edit Live Class' : 'Schedule Live Class',
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ApiErrorWidget(
          error: e,
          onRetry: () => ref.invalidate(liveClassFormDataProvider(_classId)),
        ),
        data: (form) {
          final provider = form.providers
              .where((p) => p.key == _providerKey)
              .cast<MeetingProviderOption?>()
              .firstWhere((p) => true, orElse: () => null);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Algebra revision',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Give the class a title' : null,
                ),
                const SizedBox(height: 16),

                _Dropdown<int>(
                  label: 'Class',
                  value: _classId,
                  items: form.classes.map((c) => (c.id, c.name)).toList(),
                  onChanged: (v) => setState(() {
                    _classId = v;
                    // The cascade sources change with the class, so anything
                    // chosen underneath it is no longer valid.
                    _sectionId = null;
                    _subjectId = null;
                  }),
                ),
                const SizedBox(height: 16),

                _Dropdown<int>(
                  label: 'Section',
                  value: _sectionId,
                  enabled: _classId != null,
                  items: form.sections.map((s) => (s.id, s.name)).toList(),
                  onChanged: (v) => setState(() => _sectionId = v),
                ),
                const SizedBox(height: 16),

                _Dropdown<int>(
                  label: 'Subject',
                  value: _subjectId,
                  enabled: _classId != null,
                  items: form.subjects.map((s) => (s.id, s.name)).toList(),
                  onChanged: (v) => setState(() => _subjectId = v),
                ),
                const SizedBox(height: 16),

                ListTile(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: AppColors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  leading: const Icon(Icons.event, color: AppColors.textSecondary),
                  title: Text(
                    _startTime == null
                        ? 'Start date and time'
                        : DateFormat('EEE d MMM yyyy, h:mm a').format(_startTime!),
                    style: TextStyle(
                      color: _startTime == null
                          ? AppColors.textHint
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickStartTime,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 1) return 'Enter a duration in minutes';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _Dropdown<String>(
                  label: 'Meeting on',
                  value: _providerKey,
                  items: form.providers.map((p) => (p.key, p.label)).toList(),
                  onChanged: (v) => setState(() => _providerKey = v),
                ),
                if (form.providers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'No meeting providers are enabled for your school yet. '
                      'Ask an administrator to set one up.',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),

                // Only providers that cannot mint their own meeting ask for a
                // link — mirrors the web form's data-needs-link behaviour.
                if (provider?.needsLink == true) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _linkController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Meeting link',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (provider?.needsLink != true) return null;
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Paste the meeting link';
                      final uri = Uri.tryParse(value);
                      if (uri == null || !uri.isAbsolute) return 'Enter a valid URL';
                      return null;
                    },
                  ),
                ],

                if (!_isEdit) ...[
                  const SizedBox(height: 16),
                  _Dropdown<String>(
                    label: 'Repeats',
                    value: _recurrence,
                    items: const [
                      ('none', 'Does not repeat'),
                      ('daily', 'Daily'),
                      ('weekly', 'Weekly'),
                    ],
                    onChanged: (v) => setState(() => _recurrence = v ?? 'none'),
                  ),
                  if (_recurrence != 'none') ...[
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: AppColors.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      leading: const Icon(Icons.event_repeat,
                          color: AppColors.textSecondary),
                      title: Text(
                        _recurrenceEnd == null
                            ? 'Repeat until'
                            : DateFormat('EEE d MMM yyyy').format(_recurrenceEnd!),
                        style: TextStyle(
                          color: _recurrenceEnd == null
                              ? AppColors.textHint
                              : AppColors.textPrimary,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickRecurrenceEnd,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'A separate class is created for each occurrence.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting || form.providers.isEmpty
                      ? null
                      : () => _submit(form.providers),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEdit ? 'Save changes' : 'Schedule class',
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Dropdown that drops a stale value rather than throwing.
///
/// When the class changes, the previously-selected section id may no longer be
/// in the new list — DropdownButtonFormField asserts if `value` is absent from
/// its items, so guard rather than trusting the cascade reset.
class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final safeValue = items.any((i) => i.$1 == value) ? value : null;

    return DropdownButtonFormField<T>(
      initialValue: safeValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: enabled,
      ),
      items: items
          .map((i) => DropdownMenuItem<T>(value: i.$1, child: Text(i.$2)))
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}
