import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/secure_pdf_viewer_screen.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/branding/branding_providers.dart';
import '../data/assessment_repository.dart';
import '../domain/assessment_models.dart';
import 'assessment_widgets.dart';

class AssessmentReportsScreen extends ConsumerStatefulWidget {
  const AssessmentReportsScreen({super.key});

  @override
  ConsumerState<AssessmentReportsScreen> createState() => _AssessmentReportsScreenState();
}

class _AssessmentReportsScreenState extends ConsumerState<AssessmentReportsScreen> {
  AssessmentRepository get _repo => ref.read(assessmentRepositoryProvider);

  // Filter scaffolding
  List<NamedOption> _classes = [];
  List<NamedOption> _subjects = [];
  List<EnumOption> _types = [];
  bool _loadingFilters = true;

  // Selected filters
  int? _classId;
  int? _subjectId;
  String? _type;
  int _view = 0; // 0=overview, 1=ranking, 2=student

  // Per-view data
  Map<String, dynamic>? _data;
  bool _loading = false;
  Object? _error;

  // Sub-selections
  int? _studentId;
  int? _occurrenceId;

  @override
  void initState() {
    super.initState();
    _loadFilters(null);
  }

  Map<String, dynamic> get _filters => {
        if (_classId != null) 'class_id': _classId,
        if (_subjectId != null) 'subject_id': _subjectId,
        if (_type != null) 'type': _type,
      };

  Future<void> _loadFilters(int? classId) async {
    setState(() => _loadingFilters = true);
    try {
      final res = await _repo.reportFilters(classId: classId);
      setState(() {
        _classes = (res['classes'] as List).cast<NamedOption>();
        _subjects = (res['subjects'] as List).cast<NamedOption>();
        _types = (res['types'] as List).cast<EnumOption>();
      });
    } catch (_) {
      // ignore; selectors stay empty
    } finally {
      if (mounted) setState(() => _loadingFilters = false);
    }
  }

  Future<void> _load() async {
    if (_classId == null) {
      setState(() => _data = null);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final f = {..._filters};
      Map<String, dynamic> data;
      if (_view == 1) {
        if (_occurrenceId != null) f['occurrence_id'] = _occurrenceId;
        data = await _repo.reportRanking(f);
      } else if (_view == 2) {
        if (_studentId != null) f['student_id'] = _studentId;
        data = await _repo.reportStudent(f);
      } else {
        if (_studentId != null) f['student_id'] = _studentId;
        data = await _repo.reportOverview(f);
      }
      setState(() => _data = data);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onClassChanged(int? v) {
    setState(() {
      _classId = v;
      _subjectId = null;
      _studentId = null;
      _occurrenceId = null;
      _data = null;
    });
    _loadFilters(v);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Assessment Reports',
      body: Column(
        children: [
          _filterBar(),
          _viewSelector(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _classId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: ref.watch(terminologyProvider).classLabel, isDense: true, border: const OutlineInputBorder()),
                  hint: Text(_loadingFilters ? 'Loading…' : 'Select ${ref.watch(terminologyProvider).classLabel.toLowerCase()}'),
                  items: _classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: _onClassChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  value: _subjectId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: ref.watch(terminologyProvider).subjectLabel, isDense: true, border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem<int?>(value: null, child: Text('All ${ref.watch(terminologyProvider).subjectsLabel.toLowerCase()}')),
                    ..._subjects.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: _classId == null ? null : (v) { setState(() => _subjectId = v); _load(); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _type,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type', isDense: true, border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All types')),
                    ..._types.map((t) => DropdownMenuItem<String?>(value: t.value, child: Text(t.label))),
                  ],
                  onChanged: _classId == null ? null : (v) { setState(() => _type = v); _load(); },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _viewSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('Overview'), icon: Icon(Icons.bar_chart, size: 16)),
          ButtonSegment(value: 1, label: Text('Rank'), icon: Icon(Icons.leaderboard, size: 16)),
          ButtonSegment(value: 2, label: Text('Student'), icon: Icon(Icons.person, size: 16)),
        ],
        selected: {_view},
        onSelectionChanged: (s) {
          setState(() {
            _view = s.first;
            _data = null;
          });
          _load();
        },
      ),
    );
  }

  Widget _body() {
    if (_classId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Select a ${ref.watch(terminologyProvider).classLabel.toLowerCase()} to view reports.', style: const TextStyle(color: Colors.grey)),
        ),
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      if (_error is ApiException && (_error as ApiException).message == 'module_disabled') {
        return const AssessmentModuleDisabled();
      }
      return Center(child: Text(_error is ApiException ? (_error as ApiException).message : 'Failed to load report.'));
    }
    if (_data == null) return const SizedBox.shrink();

    switch (_view) {
      case 1:
        return _rankingView(_data!);
      case 2:
        return _studentView(_data!);
      default:
        return _overviewView(_data!);
    }
  }

  // ── Overview ──────────────────────────────────────────────────────
  Widget _overviewView(Map<String, dynamic> d) {
    final summary = (d['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final sittings = ((d['sittings'] as List?) ?? []).cast<dynamic>();
    final subjectCmp = ((d['subject_comparison'] as List?) ?? []).cast<dynamic>();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: StatCard(title: 'SITTINGS', value: '${summary['sittings'] ?? 0}', icon: Icons.layers_outlined, color: Colors.purple)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(title: 'CLASS AVG', value: summary['class_avg'] != null ? '${summary['class_avg']}%' : '—', icon: Icons.percent, color: Colors.blue)),
              const SizedBox(width: 10),
              Expanded(child: StatCard(title: 'BEST', value: summary['best'] != null ? '${summary['best']}%' : '—', icon: Icons.star_outline, color: Colors.orange)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _openPdf('pdf', 'Assessment report'), icon: const Icon(Icons.picture_as_pdf_outlined, size: 18), label: const Text('PDF'))),
            const SizedBox(width: 10),
            Expanded(child: OutlinedButton.icon(onPressed: _downloadCsv, icon: const Icon(Icons.table_chart_outlined, size: 18), label: const Text('CSV'))),
          ],
        ),
        const SizedBox(height: 12),
        if (subjectCmp.isNotEmpty) ...[
          Text('${ref.watch(terminologyProvider).subjectLabel} comparison', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...subjectCmp.map((s) => _barRow(s['subject']?.toString() ?? '—', (s['avg_pct'] as num?)?.toDouble())),
          const SizedBox(height: 12),
        ],
        const Text('Sittings', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (sittings.isEmpty)
          const Text('No graded sittings in range.', style: TextStyle(color: Colors.grey))
        else
          ...sittings.map((s) => _sittingCard(s as Map)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sittingCard(Map s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('${s['assessment'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              Text(s['avg_pct'] != null ? '${s['avg_pct']}%' : '—', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${s['date'] ?? ''} • ${s['subject'] ?? ''} • ${s['graded'] ?? 0} graded',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (s['highest'] != null || s['lowest'] != null)
            Text('High ${s['highest'] ?? '-'} · Low ${s['lowest'] ?? '-'} · /${s['total_marks'] ?? '-'}',
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      ),
    );
  }

  // ── Ranking ───────────────────────────────────────────────────────
  Widget _rankingView(Map<String, dynamic> d) {
    final occurrences = ((d['occurrences'] as List?) ?? []).cast<dynamic>();
    final result = (d['result'] as Map?)?.cast<String, dynamic>();
    final ranked = ((result?['ranked'] as List?) ?? []).cast<dynamic>();
    final unranked = ((result?['unranked'] as List?) ?? []).cast<dynamic>();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        DropdownButtonFormField<int?>(
          value: _occurrenceId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Scope', isDense: true, border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Overall (all sittings)')),
            ...occurrences.map((o) => DropdownMenuItem<int?>(value: o['id'] as int?, child: Text('${o['label']}', overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) { setState(() => _occurrenceId = v); _load(); },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (result?['class_avg'] != null)
              Expanded(child: Text('${ref.watch(terminologyProvider).classLabel} average: ${result!['class_avg']}%', style: const TextStyle(fontWeight: FontWeight.bold))),
            OutlinedButton.icon(
              onPressed: () => _openPdf('ranking_pdf', '${ref.read(terminologyProvider).classLabel} ranking'),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('PDF'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (ranked.isEmpty)
          const Text('No graded results yet.', style: TextStyle(color: Colors.grey))
        else
          ...ranked.map((r) => _rankTile(r as Map)),
        if (unranked.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Not yet graded', style: TextStyle(color: Colors.grey, fontSize: 12))),
          ...unranked.map((r) => _rankTile(r as Map, unranked: true)),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _rankTile(Map r, {bool unranked = false}) {
    final grade = (r['grade'] as Map?)?.cast<String, dynamic>();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: unranked ? Colors.grey.shade200 : Colors.indigo.shade50,
          child: Text(unranked ? '–' : '${r['rank'] ?? ''}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: unranked ? Colors.grey : Colors.indigo)),
        ),
        title: Text('${r['name'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text('Roll ${r['roll_no'] ?? '-'} • ${r['tests'] ?? 0} test(s)', style: const TextStyle(fontSize: 11)),
        trailing: Text(
          r['percentage'] != null ? '${r['percentage']}%${grade != null ? '  ${grade['letter']}' : ''}' : '—',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── Student ───────────────────────────────────────────────────────
  Widget _studentView(Map<String, dynamic> d) {
    final students = ((d['students'] as List?) ?? []).cast<dynamic>();
    final report = (d['report'] as Map?)?.cast<String, dynamic>();
    final summary = (report?['summary'] as Map?)?.cast<String, dynamic>();
    final subjects = ((report?['subjects'] as List?) ?? []).cast<dynamic>();
    final timeline = ((report?['timeline'] as List?) ?? []).cast<dynamic>();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        DropdownButtonFormField<int?>(
          value: _studentId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Student', isDense: true, border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Select student')),
            ...students.map((s) => DropdownMenuItem<int?>(value: s['id'] as int?, child: Text('${s['roll_no'] ?? ''}  ${s['name']}', overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) { setState(() => _studentId = v); _load(); },
        ),
        const SizedBox(height: 8),
        if (_studentId == null)
          const Padding(padding: EdgeInsets.all(16), child: Text('Pick a student to see their progress.', style: TextStyle(color: Colors.grey)))
        else if (report == null)
          const SizedBox.shrink()
        else ...[
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: StatCard(title: 'AVG', value: summary?['avg_pct'] != null ? '${summary!['avg_pct']}%' : '—', icon: Icons.percent, color: Colors.blue)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(title: 'BEST', value: summary?['best_pct'] != null ? '${summary!['best_pct']}%' : '—', icon: Icons.star_outline, color: Colors.orange)),
                const SizedBox(width: 10),
                Expanded(child: StatCard(title: 'TESTS', value: '${summary?['graded'] ?? 0}/${summary?['tests'] ?? 0}', icon: Icons.assignment_turned_in_outlined, color: Colors.green)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _openPdf('student_pdf', 'Student report'),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('PDF'),
            ),
          ),
          if (subjects.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('By subject', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...subjects.map((s) => _barRow('${(s as Map)['subject']}', (s['avg_pct'] as num?)?.toDouble())),
          ],
          const SizedBox(height: 12),
          const Text('Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...timeline.map((t) => _timelineTile(t as Map)),
          const SizedBox(height: 40),
        ],
      ],
    );
  }

  Widget _timelineTile(Map t) {
    final absent = t['absent'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${t['assessment'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text('${t['date'] ?? ''} • ${t['subject'] ?? ''}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Text(
            absent ? 'Absent' : (t['percentage'] != null ? '${t['percentage']}%' : '—'),
            style: TextStyle(fontWeight: FontWeight.bold, color: absent ? Colors.red : Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _barRow(String label, double? pct) {
    final v = (pct ?? 0) / 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: v.clamp(0, 1), minHeight: 10, backgroundColor: Colors.grey.shade200, color: Colors.indigo),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 42, child: Text(pct != null ? '$pct%' : '—', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // ── Exports ───────────────────────────────────────────────────────
  void _openPdf(String kind, String title) {
    final f = {..._filters};
    if (kind == 'student_pdf') {
      if (_studentId == null) { _snack('Pick a student first.', error: true); return; }
      f['student_id'] = _studentId;
    }
    if (kind == 'ranking_pdf' && _occurrenceId != null) f['occurrence_id'] = _occurrenceId;
    final url = _repo.exportPath(kind, f);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => SecurePdfViewerScreen(title: title, pdfUrl: url)));
  }

  Future<void> _downloadCsv() async {
    final url = _repo.exportPath('csv', _filters);
    try {
      final res = await ref.read(apiClientProvider).dio.get<List<int>>(
            url,
            options: Options(responseType: ResponseType.bytes),
          );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/assessment-report-${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsBytes(res.data!);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], text: 'Assessment report');
    } catch (e) {
      _snack('CSV export failed.', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null));
  }
}
