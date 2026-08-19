import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/secure_pdf_viewer_screen.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/branding/branding_providers.dart';
import '../data/fees_due_repository.dart';
import '../domain/fees_due_models.dart';
import 'fees_due_providers.dart';

class FeesDueScreen extends ConsumerStatefulWidget {
  const FeesDueScreen({super.key});

  @override
  ConsumerState<FeesDueScreen> createState() => _FeesDueScreenState();
}

class _FeesDueScreenState extends ConsumerState<FeesDueScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  int? _classId;
  int? _sectionId;
  String _filterType = 'all';
  DateTime? _customDate;
  String _search = '';

  final List<FeesDueRow> _rows = [];
  DueSummary _summary = const DueSummary();
  String _sym = '';
  bool _loading = false;
  bool _initial = true;
  Object? _error;
  int _page = 1;
  int _lastPage = 1;

  FeesDueRepository get _repo => ref.read(feesDueRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300 &&
        !_loading &&
        _page <= _lastPage) {
      _fetch();
    }
  }

  String? get _dueDateParam => _filterType == 'custom' && _customDate != null
      ? _customDate!.toIso8601String().split('T').first
      : null;

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _page = 1;
      _error = null;
    }
    setState(() => _loading = true);

    try {
      final res = await _repo.getList(
        classId: _classId,
        sectionId: _sectionId,
        filterType: _filterType,
        dueDate: _dueDateParam,
        search: _search,
        page: reset ? 1 : _page,
      );
      setState(() {
        if (reset) _rows.clear();
        _rows.addAll(res.rows);
        _summary = res.summary;
        _sym = res.currencySymbol;
        _lastPage = res.lastPage;
        _page = res.currentPage + 1;
        _initial = false;
      });
    } catch (e) {
      // A failure while loading more (page 2+) keeps the existing rows and
      // surfaces a friendly snackbar; a first-page failure shows the full
      // error state with a retry.
      if (!reset && _rows.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e is ApiException ? e.message : 'Could not load more.')),
          );
        }
      } else {
        setState(() {
          _error = e;
          _initial = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _money(double v) {
    final s = v.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$_sym$s';
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: '${ref.watch(terminologyProvider).classLabel} Due Fees',
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'Download PDF',
          onPressed: () {
            final url = _repo.pdfPath(
              classId: _classId,
              sectionId: _sectionId,
              filterType: _filterType,
              dueDate: _dueDateParam,
            );
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SecurePdfViewerScreen(title: 'Due Fees', pdfUrl: url),
            ));
          },
        ),
      ],
      body: Column(
        children: [
          _filters(),
          _summaryStrip(),
          Expanded(child: _list()),
        ],
      ),
    );
  }

  // ── Filters ───────────────────────────────────────────────────────
  Widget _filters() {
    final classesAsync = ref.watch(feesDueClassesProvider);
    return classesAsync.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        final classes = (data['classes'] as List).cast<ClassOption>();
        final filters = (data['filters'] as List).cast<FilterOption>();
        final sections = _classId == null
            ? <NamedOption>[]
            : (classes.firstWhere((c) => c.id == _classId,
                    orElse: () => const ClassOption(id: 0, name: ''))
                .sections);

        return Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _dropdown<int?>(
                      label: ref.watch(terminologyProvider).classLabel,
                      value: _classId,
                      items: [
                        DropdownMenuItem<int?>(value: null, child: Text('My ${ref.watch(terminologyProvider).classesLabel.toLowerCase()}')),
                        ...classes.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _classId = v;
                          _sectionId = null;
                        });
                        _fetch(reset: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dropdown<int?>(
                      label: ref.watch(terminologyProvider).sectionLabel,
                      value: _sectionId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All')),
                        ...sections.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                      ],
                      onChanged: _classId == null
                          ? null
                          : (v) {
                              setState(() => _sectionId = v);
                              _fetch(reset: true);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _dropdown<String>(
                      label: 'Due filter',
                      value: _filterType,
                      items: filters
                          .map((f) => DropdownMenuItem(value: f.value, child: Text(f.label, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        if (v == 'custom') {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _customDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                          );
                          if (picked == null) return;
                          setState(() {
                            _filterType = 'custom';
                            _customDate = picked;
                          });
                        } else {
                          setState(() => _filterType = v);
                        }
                        _fetch(reset: true);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Search',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: const OutlineInputBorder(),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                  _fetch(reset: true);
                                },
                              ),
                      ),
                      onSubmitted: (v) {
                        setState(() => _search = v.trim());
                        _fetch(reset: true);
                      },
                    ),
                  ),
                ],
              ),
              if (_filterType == 'custom' && _customDate != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Up to ${_customDate!.toIso8601String().split('T').first}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
      items: items,
      onChanged: onChanged,
    );
  }

  // ── Summary ───────────────────────────────────────────────────────
  Widget _summaryStrip() {
    final cards = [
      ('STUDENTS', '${_summary.students}', Colors.blue),
      ('DEMAND', _money(_summary.total), Colors.indigo),
      ('COLLECTED', _money(_summary.paid), Colors.green),
      ('OUTSTANDING', _money(_summary.due), Colors.red),
    ];
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (label, value, color) = cards[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color), maxLines: 1),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────
  Widget _list() {
    if (_initial) return const Center(child: CircularProgressIndicator());
    if (_error != null && _rows.isEmpty) {
      return ApiErrorWidget(error: _error!, onRetry: () => _fetch(reset: true));
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No outstanding dues for this filter. 🎉', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _fetch(reset: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _rows.length + (_loading && _page <= _lastPage ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _rows.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          return _studentCard(_rows[i]);
        },
      ),
    );
  }

  Widget _studentCard(FeesDueRow r) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${r.admissionNo} • ${r.classLine.isEmpty ? '—' : r.classLine}\n${r.parentName} • ${r.dueDate}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(r.due), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
              Text('${r.groups} group${r.groups == 1 ? '' : 's'}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          children: [
            _breakdownTable(r),
            const SizedBox(height: 10),
            _contactActions(r),
          ],
        ),
      ),
    );
  }

  Widget _breakdownTable(FeesDueRow r) {
    if (r.breakdown.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          ...r.breakdown.map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.feeGroup, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(b.dueDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Text(_money(b.due), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _contactActions(FeesDueRow r) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _actionChip(Icons.call, 'Call', Colors.green, r.phones.isEmpty ? null : () => _pickPhone(r, _dial)),
        _actionChip(Icons.chat, 'WhatsApp', const Color(0xFF25D366), r.phones.isEmpty ? null : () => _pickPhone(r, _whatsapp)),
        _actionChip(Icons.email_outlined, 'Email', Colors.blue, r.emails.isEmpty ? null : () => _pickEmail(r)),
        _actionChip(Icons.copy, 'Copy', Colors.blueGrey, () => _copy(r)),
      ],
    );
  }

  Widget _actionChip(IconData icon, String label, Color color, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: enabled ? color.withValues(alpha: 0.3) : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: enabled ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: enabled ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ── Contact handlers ──────────────────────────────────────────────
  Future<void> _pickPhone(FeesDueRow r, Future<void> Function(String) action) async {
    if (r.phones.length == 1) {
      await action(r.phones.first.number);
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: r.phones
              .map((p) => ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text('${p.label}: ${p.number}'),
                    onTap: () => Navigator.pop(context, p.number),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked != null) await action(picked);
  }

  Future<void> _pickEmail(FeesDueRow r) async {
    String? email;
    if (r.emails.length == 1) {
      email = r.emails.first.email;
    } else {
      email = await showModalBottomSheet<String>(
        context: context,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: r.emails
                .map((e) => ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: Text('${e.label}: ${e.email}'),
                      onTap: () => Navigator.pop(context, e.email),
                    ))
                .toList(),
          ),
        ),
      );
    }
    if (email == null) return;
    await _launch(Uri(scheme: 'mailto', path: email, query: 'subject=${Uri.encodeComponent('Fees Due Reminder')}'));
  }

  Future<void> _dial(String number) async {
    await _launch(Uri(scheme: 'tel', path: number));
  }

  Future<void> _whatsapp(String number) async {
    var digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '91$digits'; // default to India country code
    await _launch(Uri.parse('https://wa.me/$digits'));
  }

  Future<void> _launch(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack('Could not open ${uri.scheme}.');
    } catch (_) {
      if (mounted) _snack('Could not open ${uri.scheme}.');
    }
  }

  void _copy(FeesDueRow r) {
    final phone = r.phones.isEmpty ? '' : r.phones.first.number;
    final email = r.emails.isEmpty ? '' : r.emails.first.email;
    final text = '${r.name} (${r.admissionNo}) — ${r.classLine}\n'
        'Parent: ${r.parentName}${phone.isEmpty ? '' : ' • $phone'}${email.isEmpty ? '' : ' • $email'}\n'
        'Outstanding: ${_money(r.due)} (${r.dueDate})';
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Copied. Share with the parent?'),
        action: SnackBarAction(label: 'Share', onPressed: () => Share.share(text)),
      ));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
