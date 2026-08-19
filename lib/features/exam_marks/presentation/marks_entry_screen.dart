import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/roster_toolbar.dart';
import '../domain/marks_models.dart';
import 'marks_controller.dart';

enum _MarksSort { rollAsc, nameAsc, blanksFirst }

class MarksEntryScreen extends ConsumerStatefulWidget {
  final int examId, classId, sectionId;
  final String header;
  const MarksEntryScreen(
      {super.key,
      required this.examId,
      required this.classId,
      required this.sectionId,
      required this.header});

  @override
  ConsumerState<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends ConsumerState<MarksEntryScreen> {
  bool _isSubmitting = false;
  String _query = '';
  _MarksSort _sort = _MarksSort.rollAsc;
  int _activeIndex = 0;

  // Per-cell UI state, keyed by "studentId:distributionId".
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _lastSaved = {}; // last value persisted to server
  final Set<String> _saving = {};
  final Set<String> _overMax = {};

  MarksEntryController get _notifier => ref.read(marksEntryControllerProvider(
        examId: widget.examId,
        classId: widget.classId,
        sectionId: widget.sectionId,
      ).notifier);

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- helpers -------------------------------------------------------------

  String _key(int studentId, int distId) => '$studentId:$distId';

  String _fmt(num v) {
    final d = v.toDouble();
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  StudentMark? _markFor(StudentMarksEntry s, int distId) {
    for (final m in s.marks) {
      if (m.distributionId == distId) return m;
    }
    return null;
  }

  TextEditingController _controllerFor(int studentId, StudentMark m) {
    final k = _key(studentId, m.distributionId);
    return _controllers.putIfAbsent(k, () {
      final text = m.marksObtained == null ? '' : _fmt(m.marksObtained!);
      _lastSaved[k] = text;
      return TextEditingController(text: text);
    });
  }

  List<StudentMarksEntry> _visible(
      List<StudentMarksEntry> students, MarkDistribution active) {
    final q = _query.trim().toLowerCase();
    final list = students.where((s) {
      if (q.isEmpty) return true;
      return s.fullName.toLowerCase().contains(q) ||
          s.rollNo.toLowerCase().contains(q);
    }).toList();

    int roll(StudentMarksEntry s) => int.tryParse(s.rollNo) ?? 1 << 30;
    bool blank(StudentMarksEntry s) {
      final m = _markFor(s, active.id);
      return m != null && m.attendanceStatus != 'absent' && m.marksObtained == null;
    }

    switch (_sort) {
      case _MarksSort.rollAsc:
        list.sort((a, b) => roll(a).compareTo(roll(b)));
        break;
      case _MarksSort.nameAsc:
        list.sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        break;
      case _MarksSort.blanksFirst:
        list.sort((a, b) {
          final r = (blank(b) ? 1 : 0).compareTo(blank(a) ? 1 : 0);
          return r != 0 ? r : roll(a).compareTo(roll(b));
        });
        break;
    }
    return list;
  }

  /// Counts for the ACTIVE subject only — that's what the teacher is entering.
  List<RosterCount> _counts(
      List<StudentMarksEntry> students, MarkDistribution active) {
    int entered = 0, blank = 0, over = 0, absent = 0;
    for (final s in students) {
      final m = _markFor(s, active.id);
      if (m == null) continue;
      if (m.attendanceStatus == 'absent') {
        absent++;
      } else if (m.marksObtained == null) {
        blank++;
      } else {
        entered++;
        if (m.marksObtained! > active.maxMarks) over++;
      }
    }
    return [
      if (blank > 0) RosterCount('Blank', blank, Colors.blueGrey),
      RosterCount('Entered', entered, Colors.green),
      if (over > 0) RosterCount('Over max', over, Colors.red),
      if (absent > 0) RosterCount('Absent', absent, Colors.orange),
    ];
  }

  int _enteredFor(List<StudentMarksEntry> students, int distId) {
    int n = 0;
    for (final s in students) {
      final m = _markFor(s, distId);
      if (m != null && (m.marksObtained != null || m.attendanceStatus == 'absent')) {
        n++;
      }
    }
    return n;
  }

  // ---- persistence ---------------------------------------------------------

  Map<String, dynamic> _payload(int studentId, StudentMark m) => {
        'student_id': studentId,
        'distribution_id': m.distributionId,
        'marks_obtained': m.attendanceStatus == 'absent' ? null : m.marksObtained,
        'attendance_status': m.attendanceStatus,
      };

  /// Save one field after the user commits it (dirty-checked).
  Future<void> _saveField(
      StudentMarksEntry student, MarkDistribution dist) async {
    final k = _key(student.id, dist.id);
    final text = _controllers[k]?.text.trim() ?? '';
    _notifier.updateMark(student.id, dist.id, text);

    final val = text.isEmpty ? null : double.tryParse(text);
    if (val != null && val > dist.maxMarks) {
      setState(() => _overMax.add(k));
      _snack('Marks cannot exceed ${_fmt(dist.maxMarks)}.', error: true);
      return;
    }
    setState(() => _overMax.remove(k));

    if ((_lastSaved[k] ?? '') == text) return; // nothing changed

    final mark = _markFor(student, dist.id);
    if (mark == null) return;
    await _post(k, [_payload(student.id, mark)], onDone: () => _lastSaved[k] = text);
  }

  Future<void> _toggleAbsent(
      StudentMarksEntry student, MarkDistribution dist) async {
    final mark = _markFor(student, dist.id);
    if (mark == null) return;
    final k = _key(student.id, dist.id);
    final becomingAbsent = mark.attendanceStatus != 'absent';

    _notifier.updateAttendance(student.id, dist.id, becomingAbsent);
    if (becomingAbsent) {
      _controllers[k]?.clear();
      _overMax.remove(k);
    }
    await _post(k, [_payload(student.id, mark)],
        onDone: () => _lastSaved[k] = _controllers[k]?.text.trim() ?? '');
  }

  Future<void> _post(String key, List<Map<String, dynamic>> cells,
      {required VoidCallback onDone}) async {
    setState(() => _saving.add(key));
    try {
      await _notifier.saveCells(cells);
      onDone();
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Save failed', error: true);
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  // ---- bulk actions --------------------------------------------------------

  Future<void> _bulk(String action, List<StudentMarksEntry> students,
      MarkDistribution dist) async {
    if (action == 'fill') {
      await _fillBlanks(students, dist);
      return;
    }
    final absent = action == 'absent';
    final cells = <Map<String, dynamic>>[];
    for (final s in students) {
      final m = _markFor(s, dist.id);
      if (m == null) continue;
      _notifier.updateAttendance(s.id, dist.id, absent);
      if (absent) _controllers[_key(s.id, dist.id)]?.clear();
      cells.add(_payload(s.id, m));
    }
    await _saveBatch(cells, students, dist);
    _snack(absent ? 'Marked all absent.' : 'Marked all present.');
  }

  Future<void> _fillBlanks(
      List<StudentMarksEntry> students, MarkDistribution dist) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fill blank marks'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(
            labelText: 'Value (max ${_fmt(dist.maxMarks)})',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: const Text('Fill'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    if (value > dist.maxMarks) {
      _snack('Value cannot exceed ${_fmt(dist.maxMarks)}.', error: true);
      return;
    }

    final cells = <Map<String, dynamic>>[];
    for (final s in students) {
      final m = _markFor(s, dist.id);
      if (m == null || m.attendanceStatus == 'absent' || m.marksObtained != null) {
        continue; // only blanks
      }
      final k = _key(s.id, dist.id);
      _controllers[k]?.text = _fmt(value);
      _notifier.updateMark(s.id, dist.id, _fmt(value));
      cells.add(_payload(s.id, m));
    }
    if (cells.isEmpty) {
      _snack('No blank cells to fill.');
      return;
    }
    await _saveBatch(cells, students, dist);
    _snack('Filled ${cells.length} blank cell(s).');
  }

  Future<void> _saveBatch(List<Map<String, dynamic>> cells,
      List<StudentMarksEntry> students, MarkDistribution dist) async {
    setState(() => _isSubmitting = true);
    try {
      await _notifier.saveCells(cells);
      // Refresh the "saved" baseline for touched cells.
      for (final s in students) {
        final k = _key(s.id, dist.id);
        _lastSaved[k] = _controllers[k]?.text.trim() ?? '';
      }
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Action failed', error: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitAll(List<StudentMarksEntry> students,
      List<MarkDistribution> dists) async {
    // Block if any cell is over its max.
    final maxById = {for (final d in dists) d.id: d.maxMarks};
    for (final s in students) {
      for (final m in s.marks) {
        final max = maxById[m.distributionId];
        if (m.attendanceStatus != 'absent' &&
            m.marksObtained != null &&
            max != null &&
            m.marksObtained! > max) {
          _snack('Some marks exceed the maximum. Fix them first.', error: true);
          return;
        }
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final msg = await _notifier.saveAllMarks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _snack(e is ApiException ? e.message : e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final marksState = ref.watch(marksEntryControllerProvider(
      examId: widget.examId,
      classId: widget.classId,
      sectionId: widget.sectionId,
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.header),
        actions: [
          marksState.maybeWhen(
            data: (data) {
              final dists = (data['distributions'] as List).cast<MarkDistribution>();
              final students = (data['students'] as List).cast<StudentMarksEntry>();
              if (dists.isEmpty || students.isEmpty) return const SizedBox.shrink();
              final active = dists[_activeIndex.clamp(0, dists.length - 1)];
              return PopupMenuButton<String>(
                enabled: !_isSubmitting,
                onSelected: (a) => _bulk(a, students, active),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'fill', child: Text('Fill blank marks…')),
                  PopupMenuItem(value: 'present', child: Text('Mark all present')),
                  PopupMenuItem(value: 'absent', child: Text('Mark all absent')),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: marksState.hasValue ? _bottomBar(marksState) : null,
      body: SafeArea(
        child: marksState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => ApiErrorWidget(
            error: ApiException.from(err),
            onRetry: () => ref.refresh(marksEntryControllerProvider(
              examId: widget.examId,
              classId: widget.classId,
              sectionId: widget.sectionId,
            )),
          ),
          data: (data) => _content(
            (data['distributions'] as List).cast<MarkDistribution>(),
            (data['students'] as List).cast<StudentMarksEntry>(),
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(AsyncValue<Map<String, dynamic>> marksState) {
    final data = marksState.value!;
    final dists = (data['distributions'] as List).cast<MarkDistribution>();
    final students = (data['students'] as List).cast<StudentMarksEntry>();
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: _isSubmitting ? null : () => _submitAll(students, dists),
          child: _isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save All Marks',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _content(List<MarkDistribution> dists, List<StudentMarksEntry> students) {
    if (dists.isEmpty || students.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No students or subjects to enter marks for.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    final active = dists[_activeIndex.clamp(0, dists.length - 1)];
    final visible = _visible(students, active);

    return Column(
      children: [
        if (dists.length > 1) _subjectTabs(dists, students),
        _subjectHeader(active, students),
        RosterToolbar<_MarksSort>(
          counts: _counts(students, active),
          query: _query,
          onQueryChanged: (v) => setState(() => _query = v),
          sortValue: _sort,
          onSortChanged: (v) => setState(() => _sort = v),
          sortOptions: const [
            RosterSortOption(value: _MarksSort.rollAsc, label: 'Roll number', icon: Icons.tag),
            RosterSortOption(value: _MarksSort.nameAsc, label: 'Name (A–Z)', icon: Icons.sort_by_alpha),
            RosterSortOption(value: _MarksSort.blanksFirst, label: 'Pending first', icon: Icons.flag_outlined),
          ],
        ),
        if (_isSubmitting) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No students match your search.'))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _studentRow(visible[i], active),
                ),
        ),
      ],
    );
  }

  Widget _subjectTabs(List<MarkDistribution> dists, List<StudentMarksEntry> students) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: dists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = dists[i];
          final selected = i == _activeIndex;
          final done = _enteredFor(students, d.id);
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => setState(() => _activeIndex = i),
            label: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.subjectName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${d.examTypeName} · $done/${students.length}',
                    style: const TextStyle(fontSize: 10)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _subjectHeader(MarkDistribution active, List<StudentMarksEntry> students) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text('${active.subjectName} · ${active.examTypeName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Text('Max ${_fmt(active.maxMarks)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _studentRow(StudentMarksEntry student, MarkDistribution dist) {
    final mark = _markFor(student, dist.id);
    if (mark == null) {
      return ListTile(dense: true, title: Text(student.fullName));
    }
    final k = _key(student.id, dist.id);
    final absent = mark.attendanceStatus == 'absent';
    final over = _overMax.contains(k);
    final saving = _saving.contains(k);
    final saved = !saving &&
        !over &&
        (_lastSaved[k] ?? '') == (_controllers[k]?.text.trim() ?? '') &&
        (mark.marksObtained != null || absent);

    final pct = (!absent && mark.marksObtained != null && dist.maxMarks > 0)
        ? (mark.marksObtained! / dist.maxMarks * 100)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(student.rollNo,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                if (pct != null)
                  Text('${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 11, color: Colors.green)),
              ],
            ),
          ),
          SizedBox(
            width: 68,
            child: TextField(
              controller: _controllerFor(student.id, mark),
              enabled: !absent,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.next,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                border: const OutlineInputBorder(),
                errorText: over ? 'Max ${_fmt(dist.maxMarks)}' : null,
                hintText: absent ? '—' : null,
              ),
              onEditingComplete: () {
                _saveField(student, dist);
                FocusScope.of(context).nextFocus();
              },
              onTapOutside: (_) => _saveField(student, dist),
            ),
          ),
          const SizedBox(width: 8),
          _absentToggle(student, dist, absent),
          SizedBox(
            width: 22,
            child: saving
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : saved
                    ? const Icon(Icons.check_circle, size: 16, color: Colors.green)
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _absentToggle(StudentMarksEntry student, MarkDistribution dist, bool absent) {
    return GestureDetector(
      onTap: () => _toggleAbsent(student, dist),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: absent ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: absent ? Colors.red.shade200 : Colors.green.shade200),
        ),
        child: Text(absent ? 'Absent' : 'Present',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: absent ? Colors.red : Colors.green)),
      ),
    );
  }
}
