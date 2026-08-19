import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import 'ptm_providers.dart';

class PtmReportsScreen extends ConsumerWidget {
  const PtmReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsState = ref.watch(ptmReportMeetingsProvider);
    final selectedMeetingId = ref.watch(selectedPtmMeetingIdProvider);

    return MainScaffold(
      title: 'Advance PTM Reports',
      body: Column(
        children: [
          // 1. Meeting Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: meetingsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => ApiErrorWidget(error: err, onRetry: () => ref.invalidate(ptmReportMeetingsProvider)),
              data: (meetings) {
                if (meetings.isEmpty) {
                  return const Text('No accessible PTM meetings found.');
                }
                return DropdownButtonFormField<int>(
                  value: selectedMeetingId,
                  decoration: const InputDecoration(
                    labelText: 'Select Meeting',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  isExpanded: true,
                  items: meetings.map((m) {
                    return DropdownMenuItem<int>(
                      value: m['id'],
                      child: Text(m['title'] ?? 'Untitled', maxLines: 1, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    ref.read(selectedPtmMeetingIdProvider.notifier).state = val;
                  },
                );
              },
            ),
          ),

          // 2. Report Content
          Expanded(
            child: selectedMeetingId == null
                ? const Center(
                    child: Text(
                      'Please select a meeting to generate the report.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : const _PtmReportContent(),
          ),
        ],
      ),
    );
  }
}

class _PtmReportContent extends ConsumerWidget {
  const _PtmReportContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(ptmReportDataProvider);

    return reportState.when(
      loading: () => SkeletonLoaders.dashboard(),
      error: (err, stack) => ApiErrorWidget(error: err, onRetry: () => ref.invalidate(ptmReportDataProvider)),
      data: (data) {
        if (data == null) return const SizedBox();

        final summary = data['summary'] as Map<String, dynamic>;
        final rows = List<Map<String, dynamic>>.from(data['rows'] ?? []);

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(ptmReportDataProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Stats
                Text('Report Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildSummaryBox('Attended', '${summary['present']} / ${summary['invited']}', Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSummaryBox('Absent', '${summary['absent']}', Colors.red)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSummaryBox('Remarks', '${summary['remark_pct']}%', Colors.blue)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSummaryBox('Parent Feedback', '${summary['feedback_count']} received', Colors.orange)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSummaryBox('Follow-ups', '${summary['followups_open']} open', Colors.purple)),
                  ],
                ),
                const SizedBox(height: 24),

                // Student List
                Text('Student Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo.shade900)),
                const SizedBox(height: 12),
                
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No students found for this meeting.'),
                  ),
                
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final isPresent = row['attendance'] == 'present';
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    row['student'] ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPresent ? Colors.green.shade600 : Colors.red.shade600,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (row['attendance'] ?? 'Pending').toString().toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text('Adm No: ${row['admission']}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                                    Expanded(child: Text('Roll No: ${row['roll']}', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (row['remark'] != null && row['remark'].toString().isNotEmpty) ...[
                                  const Text('Teacher Remark:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(row['remark'], style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                  const SizedBox(height: 12),
                                ],
                                if (row['feedback'] != null) ...[
                                  Row(
                                    children: [
                                      const Text('Parent Rating:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      ...List.generate(5, (i) {
                                        return Icon(
                                          i < (int.tryParse(row['feedback'].toString()) ?? 0) ? Icons.star : Icons.star_border,
                                          size: 16,
                                          color: Colors.orange,
                                        );
                                      }),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                if (row['parent_comment'] != null && row['parent_comment'].toString().isNotEmpty) ...[
                                  const Text('Parent Comment:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      row['parent_comment'],
                                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
