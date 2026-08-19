import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/branding/branding_providers.dart';
import '../data/assessment_repository.dart';
import '../domain/assessment_models.dart';
import 'assessment_widgets.dart';

class MarkEntryScreen extends ConsumerStatefulWidget {
  final int occurrenceId;
  const MarkEntryScreen({super.key, required this.occurrenceId});

  @override
  ConsumerState<MarkEntryScreen> createState() => _MarkEntryScreenState();
}

class _MarkEntryScreenState extends ConsumerState<MarkEntryScreen> {
  MarkGrid? _grid;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  final Map<int, TextEditingController> _controllers = {};
  final Set<int> _saving = {};

  AssessmentRepository get _repo => ref.read(assessmentRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final grid = await _repo.getGrid(widget.occurrenceId);
      for (final c in _controllers.values) {
        c.dispose();
      }
      _controllers.clear();
      for (final s in grid.students) {
        _controllers[s.studentId] = TextEditingController(text: s.marks == null ? '' : _num(s.marks));
      }
      setState(() {
        _grid = grid;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _saveRow(MarkGridStudent s) async {
    final grid = _grid!;
    final text = _controllers[s.studentId]!.text.trim();
    double? marks = text.isEmpty ? null : double.tryParse(text);

    if (s.attendance == 'present' && marks != null && grid.totalMarks != null && marks > grid.totalMarks!) {
      _snack('Marks cannot exceed ${_num(grid.totalMarks)}.', error: true);
      return;
    }

    setState(() => _saving.add(s.studentId));
    try {
      final pct = await _repo.saveMark(
        widget.occurrenceId,
        studentId: s.studentId,
        marks: s.attendance == 'absent' ? null : marks,
        attendance: s.attendance,
      );
      setState(() {
        s.marks = s.attendance == 'absent' ? null : marks;
        s.percentage = pct;
      });
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Save failed', error: true);
    } finally {
      if (mounted) setState(() => _saving.remove(s.studentId));
    }
  }

  Future<void> _toggleAttendance(MarkGridStudent s, String value) async {
    setState(() {
      s.attendance = value;
      if (value == 'absent') _controllers[s.studentId]!.text = '';
    });
    await _saveRow(s);
  }

  Future<void> _bulk(String action) async {
    setState(() => _busy = true);
    try {
      final msg = await _repo.bulk(widget.occurrenceId, action);
      _snack(msg);
      await _load();
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Action failed', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishOrReopen({required bool publish}) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(publish ? 'Publish results?' : 'Reopen sitting?'),
        content: Text(publish
            ? 'Marks will become visible to parents/students and the sitting will lock.'
            : 'The sitting will reopen for edits and results will be hidden again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(publish ? 'Publish' : 'Reopen')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final msg = publish ? await _repo.publish(widget.occurrenceId) : await _repo.reopen(widget.occurrenceId);
      _snack(msg);
      await _load();
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Action failed', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = _grid;
    return MainScaffold(
      title: 'Enter Marks',
      actions: grid != null && grid.canEnter && !grid.isLocked
          ? [
              PopupMenuButton<String>(
                onSelected: _bulk,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'mark_all_absent', child: Text('Mark all absent')),
                  PopupMenuItem(value: 'zero_blanks', child: Text('Zero-fill blanks')),
                ],
              ),
            ]
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? (_error is ApiException && (_error as ApiException).message == 'module_disabled'
                  ? const AssessmentModuleDisabled()
                  : ApiErrorWidget(error: _error!, onRetry: _load))
              : _content(grid!),
    );
  }

  Widget _content(MarkGrid grid) {
    final bottomBar = _bottomBar(grid);
    return Column(
      children: [
        _header(grid),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: grid.students.isEmpty
              ? Center(child: Text('No students enrolled for this ${ref.watch(terminologyProvider).classLabel.toLowerCase()}/${ref.watch(terminologyProvider).sectionLabel.toLowerCase()}.', style: const TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: grid.students.length,
                  itemBuilder: (context, i) => _studentRow(grid, grid.students[i]),
                ),
        ),
        if (bottomBar != null) bottomBar,
      ],
    );
  }

  Widget _header(MarkGrid grid) {
    final statusColor = occurrenceStatusColor(grid.status);
    final classLine = [grid.className, grid.section].where((e) => e != null && e.isNotEmpty).join(' / ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(grid.assessmentTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (grid.subject != null) Text(grid.subject!, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (classLine.isNotEmpty) Text('• $classLine', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('• ${grid.scheduledDate ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
              child: Text((grid.statusLabel ?? '').toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Total marks: ${_num(grid.totalMarks)}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
          if (grid.isLocked)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('This sitting is locked. Reopen to edit marks.',
                  style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  Widget _studentRow(MarkGrid grid, MarkGridStudent s) {
    final canEnter = grid.canEnter && !grid.isLocked;
    final absent = s.attendance == 'absent';
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(s.rollNo ?? '-', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                if (s.percentage != null && !absent)
                  Text('${s.percentage}%', style: const TextStyle(fontSize: 11, color: Colors.green)),
              ],
            ),
          ),
          // Marks field
          SizedBox(
            width: 64,
            child: TextField(
              controller: _controllers[s.studentId],
              enabled: canEnter && !absent,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                border: const OutlineInputBorder(),
                hintText: absent ? '—' : null,
              ),
              onEditingComplete: () {
                FocusScope.of(context).unfocus();
                _saveRow(s);
              },
              onSubmitted: (_) => _saveRow(s),
            ),
          ),
          const SizedBox(width: 8),
          // Attendance toggle
          if (canEnter)
            _attendanceToggle(s)
          else
            Text(absent ? 'Absent' : (s.marks != null ? _num(s.marks) : '—'),
                style: TextStyle(fontSize: 12, color: absent ? Colors.red : Colors.black54)),
          SizedBox(
            width: 24,
            child: _saving.contains(s.studentId)
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _attendanceToggle(MarkGridStudent s) {
    final absent = s.attendance == 'absent';
    return GestureDetector(
      onTap: () => _toggleAttendance(s, absent ? 'present' : 'absent'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: absent ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: absent ? Colors.red.shade200 : Colors.green.shade200),
        ),
        child: Text(absent ? 'Absent' : 'Present',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: absent ? Colors.red : Colors.green)),
      ),
    );
  }

  Widget? _bottomBar(MarkGrid grid) {
    if (!grid.canPublish) return null;
    if (grid.isLocked) {
      return _bar('Reopen for editing', Icons.lock_open, Colors.orange, () => _publishOrReopen(publish: false));
    }
    return _bar('Publish results', Icons.publish, Colors.green, () => _publishOrReopen(publish: true));
  }

  Widget _bar(String label, IconData icon, Color color, VoidCallback onTap) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 48,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: _busy ? null : onTap,
            icon: Icon(icon),
            label: Text(label),
          ),
        ),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  String _num(double? v) {
    if (v == null) return '—';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }
}
