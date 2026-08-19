import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import '../data/assessment_repository.dart';
import '../domain/assessment_models.dart';
import 'assessment_widgets.dart';

class AssessmentListScreen extends ConsumerStatefulWidget {
  const AssessmentListScreen({super.key});

  @override
  ConsumerState<AssessmentListScreen> createState() => _AssessmentListScreenState();
}

class _AssessmentListScreenState extends ConsumerState<AssessmentListScreen> {
  final List<AssessmentSummary> _items = [];
  final ScrollController _scroll = ScrollController();

  bool _loading = false;
  bool _initialLoad = true;
  Object? _error;
  int _page = 1;
  int _lastPage = 1;

  // Filters
  String? _type;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300 &&
        !_loading &&
        _page < _lastPage) {
      _fetch();
    }
  }

  Future<void> _fetch({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        _page = 1;
        _error = null;
      }
    });

    try {
      final result = await ref.read(assessmentRepositoryProvider).getList(
            type: _type,
            page: reset ? 1 : _page,
          );
      final items = (result['items'] as List).cast<AssessmentSummary>();
      final meta = result['meta'] as Map<String, dynamic>;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(items);
        _lastPage = (meta['last_page'] as int?) ?? 1;
        _page = ((meta['current_page'] as int?) ?? 1) + 1;
        _initialLoad = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _initialLoad = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Assessments',
      body: Column(
        children: [
          _filterBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filterBar() {
    const types = [
      ['', 'All'],
      ['quiz', 'Quiz'],
      ['test', 'Test'],
      ['oral', 'Oral'],
      ['practical', 'Practical'],
      ['assignment', 'Assignment'],
      ['other', 'Other'],
    ];
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: types.map((t) {
          final selected = (_type ?? '') == t[0];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(t[1]),
              selected: selected,
              onSelected: (_) {
                setState(() => _type = t[0].isEmpty ? null : t[0]);
                _fetch(reset: true);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body() {
    if (_initialLoad) return const Center(child: CircularProgressIndicator());

    if (_error != null && _items.isEmpty) {
      if (_error is ApiException && (_error as ApiException).message == 'module_disabled') {
        return const AssessmentModuleDisabled();
      }
      return ApiErrorWidget(error: _error!, onRetry: () => _fetch(reset: true));
    }

    if (_items.isEmpty) {
      return const Center(child: Text('No assessments match these filters.', style: TextStyle(color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: () => _fetch(reset: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        itemCount: _items.length + (_page <= _lastPage && _loading ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final a = _items[i];
          return AssessmentListTile(
            assessment: a,
            onTap: () => context.push('/dashboard/assessment/${a.id}'),
          );
        },
      ),
    );
  }
}
