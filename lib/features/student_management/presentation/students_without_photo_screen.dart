import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import 'package:school_erp_staff_app/shared/widgets/api_error_widget.dart';
import '../data/student_repository.dart';
import 'student_photo_actions.dart';

/// Worklist of students missing a profile photo. Tap the camera on a row to
/// capture/upload; the student drops off the list once a photo is saved.
class StudentsWithoutPhotoScreen extends ConsumerStatefulWidget {
  const StudentsWithoutPhotoScreen({super.key});

  @override
  ConsumerState<StudentsWithoutPhotoScreen> createState() =>
      _StudentsWithoutPhotoScreenState();
}

class _StudentsWithoutPhotoScreenState
    extends ConsumerState<StudentsWithoutPhotoScreen> {
  final _repo = StudentRepository();
  final _scrollController = ScrollController();

  final List<Map<String, dynamic>> _students = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_loadingMore &&
          _page < _lastPage) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.getStudentsWithoutPhoto(page: 1);
      setState(() {
        _students
          ..clear()
          ..addAll(res['students'] as List<Map<String, dynamic>>);
        _page = 1;
        _lastPage = res['lastPage'] as int;
        _total = res['total'] as int;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final res = await _repo.getStudentsWithoutPhoto(page: _page + 1);
      setState(() {
        _page += 1;
        _lastPage = res['lastPage'] as int;
        _students.addAll(res['students'] as List<Map<String, dynamic>>);
      });
    } catch (_) {
      // Silent — the user can pull to refresh.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _upload(Map<String, dynamic> student) async {
    final result = await pickAndUploadStudentPhoto(context, student['id'] as int);
    if (result != null && mounted) {
      // Photo saved — drop the student from the worklist.
      setState(() {
        _students.removeWhere((s) => s['id'] == student['id']);
        if (_total > 0) _total -= 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_loading ? 'Photo Missing' : 'Photo Missing ($_total)'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ApiErrorWidget(
        error: ApiException.from(_error!),
        onRetry: () => _load(reset: true),
      );
    }
    if (_students.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 56, color: Colors.green),
              SizedBox(height: 12),
              Text('All students have a photo.',
                  style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _students.length + (_page < _lastPage ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _students.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final s = _students[index];
          final classLine = [s['class'], s['section']]
              .where((e) => e != null && '$e'.isNotEmpty)
              .join(' - ');
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              child: Text('${(s['full_name'] ?? 'S').toString().characters.first}'),
            ),
            title: Text(s['full_name'] ?? 'No Name'),
            subtitle: Text([
              if (classLine.isNotEmpty) classLine,
              if (s['roll_no'] != null && '${s['roll_no']}'.isNotEmpty)
                'Roll ${s['roll_no']}',
              if (s['admission_no'] != null) 'Adm ${s['admission_no']}',
            ].join(' • ')),
            trailing: FilledButton.icon(
              onPressed: () => _upload(s),
              icon: const Icon(Icons.photo_camera, size: 18),
              label: const Text('Add'),
            ),
          );
        },
      ),
    );
  }
}
