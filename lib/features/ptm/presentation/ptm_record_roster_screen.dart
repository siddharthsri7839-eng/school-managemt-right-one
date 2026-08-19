import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import 'ptm_providers.dart';
import '../data/ptm_repository.dart';

class PtmRecordRosterScreen extends ConsumerStatefulWidget {
  final int meetingId;

  const PtmRecordRosterScreen({super.key, required this.meetingId});

  @override
  ConsumerState<PtmRecordRosterScreen> createState() => _PtmRecordRosterScreenState();
}

class _PtmRecordRosterScreenState extends ConsumerState<PtmRecordRosterScreen> {
  // Store local edits before saving
  final Map<int, Map<String, dynamic>> _edits = {};
  bool _isSaving = false;

  void _markEdited(int invitationId, String key, dynamic value) {
    setState(() {
      _edits[invitationId] ??= {};
      _edits[invitationId]![key] = value;
    });
  }

  Future<void> _saveAll() async {
    if (_edits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No changes to save.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(ptmRepositoryProvider);
      final payloadRows = _edits.map((key, value) => MapEntry(key.toString(), value));
      final response = await repo.saveRecord(widget.meetingId, {'rows': payloadRows});
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response['message'] ?? 'Records saved successfully!'),
        backgroundColor: Colors.green,
      ));
      
      _edits.clear();
      ref.invalidate(ptmRecordRosterProvider(widget.meetingId));
      ref.invalidate(ptmDashboardProvider);
      ref.invalidate(ptmRecordMeetingsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ApiException.from(e).message),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rosterState = ref.watch(ptmRecordRosterProvider(widget.meetingId));

    return MainScaffold(
      title: 'Record PTM',
      body: rosterState.when(
        loading: () => SkeletonLoaders.listTile(count: 5),
        error: (err, stack) => ApiErrorWidget(
          error: err,
          onRetry: () => ref.invalidate(ptmRecordRosterProvider(widget.meetingId)),
        ),
        data: (data) {
          final invitations = List<Map<String, dynamic>>.from(data['invitations'] ?? []);
          final permissions = data['permissions'] as Map<String, dynamic>? ?? {};
          final canAttendance = permissions['can_attendance'] == true;
          final canRemark = permissions['can_remark'] == true;
          final currentStaffId = data['current_staff_id'];

          if (invitations.isEmpty) {
            return const Center(child: Text('No students found in this roster.'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, top: 12),
                  itemCount: invitations.length,
                  itemBuilder: (context, index) {
                    final inv = invitations[index];
                    return _buildStudentCard(inv, canAttendance, canRemark, currentStaffId);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, -2))],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving || _edits.isEmpty ? null : _saveAll,
                    icon: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Changes (${_edits.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> inv, bool canAttendance, bool canRemark, int? currentStaffId) {
    final int invId = inv['id'];
    final student = inv['student'] ?? {};
    final remark = inv['remark'] ?? {};
    
    // Check if the teacher is allowed to edit the remark (must be their own if it exists)
    final bool canEditRemark = canRemark && (remark.isEmpty || remark['staff_id'] == currentStaffId);

    // Current local state or fallback to server state
    final editState = _edits[invId] ?? {};
    final currentAttendance = editState['attendance_status'] ?? inv['attendance_status'] ?? 'pending';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Adm: ${student['admission_no'] ?? 'N/A'} | Roll: ${student['roll_no'] ?? 'N/A'}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: _buildAttendanceBadge(currentAttendance),
        childrenPadding: const EdgeInsets.all(16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canAttendance) ...[
            const Text('Attendance Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Pending', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 'present', label: Text('Present', style: TextStyle(fontSize: 12))),
                ButtonSegment(value: 'absent', label: Text('Absent', style: TextStyle(fontSize: 12))),
              ],
              selected: {currentAttendance == 'rescheduled' ? 'pending' : currentAttendance},
              onSelectionChanged: (Set<String> newSelection) {
                _markEdited(invId, 'attendance_status', newSelection.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (canEditRemark) ...[
            const Text('Performance Remark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: editState['performance_remark'] ?? remark['performance_remark'],
              decoration: const InputDecoration(
                hintText: 'Add performance note...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 2,
              onChanged: (val) => _markEdited(invId, 'performance_remark', val),
            ),
            const SizedBox(height: 16),

            const Text('Behaviour Remark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: editState['behaviour_remark'] ?? remark['behaviour_remark'],
              decoration: const InputDecoration(
                hintText: 'Add behaviour note...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 2,
              onChanged: (val) => _markEdited(invId, 'behaviour_remark', val),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Text('Overall Rating (1-5): ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _parseRating(editState['overall_rating'] ?? remark['overall_rating']),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: [null, 1, 2, 3, 4, 5].map((rating) {
                      return DropdownMenuItem<int>(
                        value: rating,
                        child: Text(rating == null ? 'None' : '$rating Stars'),
                      );
                    }).toList(),
                    onChanged: (val) => _markEdited(invId, 'overall_rating', val),
                  ),
                ),
              ],
            ),
          ] else if (canRemark) ...[
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.grey.shade100,
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey, size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Remarks for this student were recorded by another teacher and cannot be edited by you.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  int? _parseRating(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  Widget _buildAttendanceBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'present':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'absent':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case 'rescheduled':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}
