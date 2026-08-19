import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/branding/branding_providers.dart';
import '../data/assessment_repository.dart';
import '../domain/assessment_models.dart';
import 'assessment_providers.dart';

class AssessmentFormScreen extends ConsumerStatefulWidget {
  /// When non-null the form is in edit mode.
  final AssessmentDetail? existing;
  const AssessmentFormScreen({super.key, this.existing});

  @override
  ConsumerState<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends ConsumerState<AssessmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _totalMarks = TextEditingController();
  final _passingMarks = TextEditingController();
  final _instructions = TextEditingController();

  String? _type;
  String? _frequency;
  String? _conductedVia;
  int? _classId;
  int? _subjectId;
  int? _sectionId; // null = whole class
  DateTime? _scheduledDate;

  List<NamedOption> _subjects = [];
  List<NamedOption> _sections = [];
  bool _loadingCascade = false;
  bool _submitting = false;

  bool get isEdit => widget.existing != null;
  bool get _audienceLocked => widget.existing?.hasMarks ?? false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _type = e.type;
      _frequency = e.frequency;
      _conductedVia = e.conductedVia;
      _classId = e.classId;
      _subjectId = e.subjectId;
      _sectionId = e.sectionId;
      _totalMarks.text = e.totalMarks == null ? '' : _num(e.totalMarks!);
      _passingMarks.text = e.passingMarks == null ? '' : _num(e.passingMarks!);
      _instructions.text = e.instructions ?? '';
      if (e.classId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadCascade(e.classId!, keepSelection: true));
      }
    } else {
      _type = 'quiz';
      _frequency = 'once';
      _scheduledDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _totalMarks.dispose();
    _passingMarks.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _loadCascade(int classId, {bool keepSelection = false}) async {
    setState(() => _loadingCascade = true);
    try {
      final res = await ref.read(assessmentRepositoryProvider).getClassOptions(classId);
      setState(() {
        _subjects = res['subjects'] ?? [];
        _sections = res['sections'] ?? [];
        if (!keepSelection) {
          _subjectId = null;
          _sectionId = null;
        } else {
          // Drop stale selections that aren't valid for this class.
          if (_subjectId != null && !_subjects.any((s) => s.id == _subjectId)) _subjectId = null;
          if (_sectionId != null && !_sections.any((s) => s.id == _sectionId)) _sectionId = null;
        }
      });
    } catch (_) {
      // Cascade failure is non-fatal; the dropdowns just stay empty.
    } finally {
      if (mounted) setState(() => _loadingCascade = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_classId == null || _subjectId == null) {
      _snack('Pick a ${ref.read(terminologyProvider).classLabel.toLowerCase()} and ${ref.read(terminologyProvider).subjectLabel.toLowerCase()}.', error: true);
      return;
    }
    if (!isEdit && _scheduledDate == null) {
      _snack('Pick a sitting date.', error: true);
      return;
    }

    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'type': _type,
      'subject_id': _subjectId,
      'school_class_id': _classId,
      'section_id': _sectionId,
      'total_marks': _totalMarks.text.trim(),
      'passing_marks': _passingMarks.text.trim().isEmpty ? null : _passingMarks.text.trim(),
      'frequency': _frequency,
      'conducted_via': _conductedVia,
      'instructions': _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
      if (!isEdit) 'scheduled_date': _scheduledDate!.toIso8601String().split('T').first,
    };

    setState(() => _submitting = true);
    try {
      final repo = ref.read(assessmentRepositoryProvider);
      final detail = isEdit ? await repo.update(widget.existing!.id, body) : await repo.create(body);
      if (!mounted) return;
      _snack(isEdit ? 'Assessment updated.' : 'Assessment created.');
      if (isEdit) {
        context.pop(true);
      } else {
        // Replace the form with the new assessment's detail page.
        context.pushReplacement('/dashboard/assessment/${detail.id}');
      }
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Save failed', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final optionsAsync = ref.watch(assessmentFormOptionsProvider);

    return MainScaffold(
      title: isEdit ? 'Edit Assessment' : 'New Assessment',
      body: optionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ApiErrorWidget(error: err, onRetry: () => ref.invalidate(assessmentFormOptionsProvider)),
        data: (opts) => _form(opts),
      ),
    );
  }

  Widget _form(Map<String, dynamic> opts) {
    final types = (opts['types'] as List).cast<EnumOption>();
    final freqs = (opts['frequencies'] as List).cast<EnumOption>();
    final conducted = (opts['conducted_via'] as List).cast<EnumOption>();
    final classes = (opts['classes'] as List).cast<NamedOption>();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          _dropdown<String>(
            label: 'Type *',
            value: _type,
            items: types.map((t) => DropdownMenuItem(value: t.value, child: Text(t.label))).toList(),
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 14),
          if (_audienceLocked)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(
                  'Marks already entered — ${ref.watch(terminologyProvider).classLabel.toLowerCase()}, ${ref.watch(terminologyProvider).subjectLabel.toLowerCase()} and ${ref.watch(terminologyProvider).sectionLabel.toLowerCase()} are locked.',
                  style: const TextStyle(fontSize: 12, color: Colors.brown)),
            ),
          _dropdown<int>(
            label: '${ref.watch(terminologyProvider).classLabel} *',
            value: _classId,
            enabled: !_audienceLocked,
            items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
            onChanged: (v) {
              setState(() => _classId = v);
              if (v != null) _loadCascade(v);
            },
          ),
          const SizedBox(height: 14),
          _dropdown<int>(
            label: '${ref.watch(terminologyProvider).subjectLabel} *',
            value: _subjectId,
            enabled: !_audienceLocked && _classId != null,
            hint: _loadingCascade
                ? 'Loading…'
                : (_classId == null
                    ? 'Pick a ${ref.watch(terminologyProvider).classLabel.toLowerCase()} first'
                    : 'Select ${ref.watch(terminologyProvider).subjectLabel.toLowerCase()}'),
            items: _subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
            onChanged: (v) => setState(() => _subjectId = v),
          ),
          const SizedBox(height: 14),
          _dropdown<int?>(
            label:
                '${ref.watch(terminologyProvider).sectionLabel} (optional — whole ${ref.watch(terminologyProvider).classLabel.toLowerCase()} if empty)',
            value: _sectionId,
            enabled: !_audienceLocked && _classId != null,
            items: [
              DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Whole ${ref.watch(terminologyProvider).classLabel.toLowerCase()}')),
              ..._sections.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
            ],
            onChanged: (v) => setState(() => _sectionId = v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _totalMarks,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Total marks *', border: OutlineInputBorder()),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1) return 'Min 1';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _passingMarks,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Passing marks', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _dropdown<String>(
            label: 'Frequency *',
            value: _frequency,
            items: freqs.map((f) => DropdownMenuItem(value: f.value, child: Text(f.label))).toList(),
            onChanged: (v) => setState(() => _frequency = v),
          ),
          const SizedBox(height: 14),
          _dropdown<String?>(
            label: 'Conducted via',
            value: _conductedVia,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              ...conducted.map((c) => DropdownMenuItem<String?>(value: c.value, child: Text(c.label))),
            ],
            onChanged: (v) => setState(() => _conductedVia = v),
          ),
          const SizedBox(height: 14),
          if (!isEdit) ...[
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _scheduledDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _scheduledDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'First sitting date *', border: OutlineInputBorder()),
                child: Text(_scheduledDate == null
                    ? 'Select date'
                    : _scheduledDate!.toIso8601String().split('T').first),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _instructions,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Instructions', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(isEdit ? 'Save changes' : 'Create assessment'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
    String? hint,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      hint: hint == null ? null : Text(hint),
      items: items,
      onChanged: enabled ? onChanged : null,
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
