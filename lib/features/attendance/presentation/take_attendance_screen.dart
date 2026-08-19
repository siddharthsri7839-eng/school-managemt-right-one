// lib/features/attendance/presentation/take_attendance_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../shared/widgets/roster_toolbar.dart';
import '../../../core/branding/branding_providers.dart';
import 'attendance_controller.dart';
import 'attendance_state.dart';

enum _AttSort { rollAsc, nameAsc, status }

class TakeAttendanceScreen extends ConsumerStatefulWidget {
  final int sectionId;
  final String date;
  const TakeAttendanceScreen(
      {super.key, required this.sectionId, required this.date});

  @override
  ConsumerState<TakeAttendanceScreen> createState() =>
      _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends ConsumerState<TakeAttendanceScreen> {
  bool _isSubmitting = false;
  bool _isViewOnly = false;
  String _query = '';
  _AttSort _sort = _AttSort.rollAsc;

  int _rollValue(dynamic student) =>
      int.tryParse('${student['roll_no'] ?? ''}') ?? 1 << 30;

  /// Order used by the "Status" sort: exceptions first so they're easy to find.
  int _statusRank(String? status) {
    switch (status) {
      case null:
        return 0; // Unmarked
      case 'Absent':
        return 1;
      case 'Late':
        return 2;
      case 'Half Day':
        return 3;
      default:
        return 4; // Present
    }
  }

  List<dynamic> _visibleStudents(AttendanceState state) {
    final q = _query.trim().toLowerCase();
    final list = state.students.where((s) {
      if (q.isEmpty) return true;
      final name = '${s['full_name'] ?? ''}'.toLowerCase();
      final roll = '${s['roll_no'] ?? ''}'.toLowerCase();
      return name.contains(q) || roll.contains(q);
    }).toList();

    switch (_sort) {
      case _AttSort.rollAsc:
        list.sort((a, b) => _rollValue(a).compareTo(_rollValue(b)));
        break;
      case _AttSort.nameAsc:
        list.sort((a, b) => '${a['full_name'] ?? ''}'
            .toLowerCase()
            .compareTo('${b['full_name'] ?? ''}'.toLowerCase()));
        break;
      case _AttSort.status:
        list.sort((a, b) {
          final r = _statusRank(state.attendanceMap[a['id']])
              .compareTo(_statusRank(state.attendanceMap[b['id']]));
          return r != 0 ? r : _rollValue(a).compareTo(_rollValue(b));
        });
        break;
    }
    return list;
  }

  List<RosterCount> _counts(AttendanceState state) {
    int present = 0, absent = 0, late = 0, half = 0, unmarked = 0;
    for (final s in state.students) {
      switch (state.attendanceMap[s['id']]) {
        case 'Present':
          present++;
          break;
        case 'Absent':
          absent++;
          break;
        case 'Late':
          late++;
          break;
        case 'Half Day':
          half++;
          break;
        default:
          unmarked++;
      }
    }
    return [
      if (unmarked > 0) RosterCount('Unmarked', unmarked, Colors.blueGrey),
      RosterCount('Present', present, Colors.green),
      RosterCount('Absent', absent, Colors.red),
      if (late > 0) RosterCount('Late', late, Colors.orange),
      if (half > 0) RosterCount('Half', half, Colors.blue),
    ];
  }

  int _unmarkedCount(AttendanceState state) {
    int n = 0;
    for (final s in state.students) {
      final id = s['id'] as int;
      if (state.lockedStudentIds.contains(id)) continue;
      if (state.attendanceMap[id] == null) n++;
    }
    return n;
  }

  /// Applies a bulk change and offers an Undo that restores the prior map.
  void _applyBulk(AttendanceState state, {required bool present}) {
    final prev = Map<int, String?>.from(state.attendanceMap);
    final notifier = ref.read(
        attendanceControllerProvider(widget.sectionId, widget.date).notifier);
    if (present) {
      notifier.markAllAsPresent();
    } else {
      notifier.clearAll();
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(present ? 'Marked all present.' : 'Cleared all marks.'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.restoreMap(prev),
        ),
      ));
  }

  /// Warns about unmarked (→ Absent) students before submitting.
  Future<void> _onSubmitPressed(AttendanceState state) async {
    final unmarked = _unmarkedCount(state);
    if (unmarked > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('$unmarked student${unmarked == 1 ? '' : 's'} not marked'),
          content: const Text(
              'Unmarked students will be recorded as Absent. Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Go back')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit anyway')),
          ],
        ),
      );
      if (proceed != true) return;
    }
    await _submitAttendance();
  }

  Widget _bulkActions(AttendanceState state) {
    final allLocked =
        state.lockedStudentIds.length == state.students.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: allLocked ? null : () => _applyBulk(state, present: true),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('All present'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: allLocked ? null : () => _applyBulk(state, present: false),
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Determine if the screen should be in "view only" mode.
    // This happens if the selected date is before today.
    try {
      final attendanceDate = DateFormat('yyyy-MM-dd').parse(widget.date);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      _isViewOnly = attendanceDate.isAfter(today); 
    } catch (e) {
      // If date parsing fails, default to view only for safety.
      _isViewOnly = true;
    }
  }

  Future<void> _submitAttendance() async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(attendanceControllerProvider(widget.sectionId, widget.date)
              .notifier)
          .submitAttendance();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance Submitted Successfully!'),
              backgroundColor: Colors.green,
            ));
        // Go back to the previous screen on success.
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final message = e is ApiException ? e.message : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsyncState =
        ref.watch(attendanceControllerProvider(widget.sectionId, widget.date));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isViewOnly ? 'View Attendance' : 'Take Attendance'),
      ),
      bottomNavigationBar: !_isViewOnly && attendanceAsyncState.hasValue
          ? Container(
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
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.orange, // Based on the user's FAB color
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    )
                  ),
                  onPressed: _isSubmitting || (attendanceAsyncState.value!.lockedStudentIds.length == attendanceAsyncState.value!.students.length)
                      ? null
                      : () => _onSubmitPressed(attendanceAsyncState.value!),
                  child: _isSubmitting 
                      ? const SizedBox(
                          width: 24, height: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text('Submit Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: attendanceAsyncState.when(
          loading: () => SkeletonLoaders.listTile(),
          error: (err, stack) {
            final exception = ApiException.from(err);
            return ApiErrorWidget(
              error: exception,
              onRetry: () => ref.refresh(attendanceControllerProvider(widget.sectionId, widget.date)),
            );
          },
          data: (state) {
            final students = state.students;
            if (students.isEmpty) {
              return Center(child: Text('No students found in this ${ref.watch(terminologyProvider).sectionLabel.toLowerCase()}.'));
            }

            final visible = _visibleStudents(state);

            return Column(
              children: [
                RosterToolbar<_AttSort>(
                  counts: _counts(state),
                  query: _query,
                  onQueryChanged: (v) => setState(() => _query = v),
                  sortValue: _sort,
                  onSortChanged: (v) => setState(() => _sort = v),
                  sortOptions: const [
                    RosterSortOption(
                        value: _AttSort.rollAsc,
                        label: 'Roll number',
                        icon: Icons.tag),
                    RosterSortOption(
                        value: _AttSort.nameAsc,
                        label: 'Name (A–Z)',
                        icon: Icons.sort_by_alpha),
                    RosterSortOption(
                        value: _AttSort.status,
                        label: 'Status (unmarked first)',
                        icon: Icons.flag_outlined),
                  ],
                ),
                if (!_isViewOnly) _bulkActions(state),
                const _AttendanceLegend(),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('No students match your search.'))
                      : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: visible.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final student = visible[index];
                      final studentId = student['id'] as int;
                      final isLocked = state.lockedStudentIds.contains(studentId);
                      
                      return _StudentAttendanceTile(
                        student: student,
                        status: state.attendanceMap[studentId],
                        isLocked: isLocked,
                        // Pass null for onStatusChanged if in "view only" mode OR if individual record is locked
                        onStatusChanged: (_isViewOnly || isLocked)
                            ? null
                            : (newStatus) {
                                ref
                                    .read(attendanceControllerProvider(
                                            widget.sectionId, widget.date)
                                        .notifier)
                                    .updateStatus(studentId, newStatus);
                              },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Widget for the instructional legend at the top of the screen.
class _AttendanceLegend extends StatelessWidget {
  const _AttendanceLegend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 16.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.center,
        children: const [
          _LegendItem(icon: Icons.check_circle_outline, label: 'Present', color: Colors.green),
          _LegendItem(icon: Icons.cancel_outlined, label: 'Absent', color: Colors.red),
          _LegendItem(icon: Icons.watch_later_outlined, label: 'Late', color: Colors.orange),
          _LegendItem(icon: Icons.star_half_outlined, label: 'Half Day', color: Colors.blue),
        ],
      ),
    );
  }
}

// Helper widget for each item in the legend.
class _LegendItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _LegendItem({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}


// Widget for each student's attendance selection row.
class _StudentAttendanceTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final String? status; // Can be null for "Not Marked"
  final bool isLocked;
  final ValueChanged<String>? onStatusChanged; // Is null in "view only" mode or if record is locked

  const _StudentAttendanceTile({
    required this.student,
    this.status,
    this.isLocked = false,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Expanded(child: Text(student['full_name'] ?? 'Unknown Student')),
          if (isLocked)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: Text(status != null
                          ? 'Already marked "$status". Locked — ask an admin to change it.'
                          : 'This record is locked and cannot be edited.'),
                    ));
                },
                child: const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
              ),
            ),
        ],
      ),
      subtitle: Text('Roll No: ${student['roll_no'] ?? 'N/A'}'),
      trailing: SizedBox(
        width: 220,
        child: Opacity(
          opacity: isLocked ? 0.7 : 1.0,
          child: SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                  value: 'Present',
                  icon: Tooltip(message: 'Present', child: Icon(Icons.check_circle_outline))),
              ButtonSegment<String>(
                  value: 'Absent',
                  icon: Tooltip(message: 'Absent', child: Icon(Icons.cancel_outlined))),
              ButtonSegment<String>(
                  value: 'Late',
                  icon: Tooltip(message: 'Late', child: Icon(Icons.watch_later_outlined))),
              ButtonSegment<String>(
                  value: 'Half Day',
                  icon: Tooltip(message: 'Half Day', child: Icon(Icons.star_half_outlined))),
            ],
            
            // If status is null, the set is empty, and NO button is selected.
            selected: status == null ? <String>{} : <String>{status!},
            
            // The onSelectionChanged callback is disabled if it's null.
            onSelectionChanged: onStatusChanged == null ? null : (newSelection) {
              onStatusChanged!(newSelection.first);
            },
            
            emptySelectionAllowed: true,
  
            style: ButtonStyle(
               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: WidgetStateProperty.all<EdgeInsets>(
                const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ),
      ),
    );
  }
}