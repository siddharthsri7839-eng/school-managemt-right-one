import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../core/branding/branding_providers.dart';
import 'attendance_providers.dart';
import 'attendance_report_providers.dart';

class StudentAttendanceReportScreen extends ConsumerWidget {
  const StudentAttendanceReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MainScaffold(
      title: 'Attendance Report',
      actions: [
        IconButton(
          icon: const Icon(Icons.download),
          tooltip: 'Download PDF',
          onPressed: () => _downloadPdf(context, ref),
        ),
      ],
      body: Column(
        children: [
          _buildFilterSection(context, ref),
          const Expanded(child: _ReportContent()),
        ],
      ),
    );
  }

  void _downloadPdf(BuildContext context, WidgetRef ref) {
    final classId = ref.read(selectedReportClassProvider)?['id'];
    final sectionId = ref.read(selectedReportSectionProvider)?['id'];
    final month = ref.read(selectedReportMonthProvider);
    final year = ref.read(selectedReportYearProvider);

    if (classId == null || sectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a ${ref.read(terminologyProvider).classLabel.toLowerCase()} and ${ref.read(terminologyProvider).sectionLabel.toLowerCase()} first.')),
      );
      return;
    }

    final url = 'http://10.0.2.2:8000/api/v1/staff/attendance/reports/student/export-pdf?class_id=$classId&section_id=$sectionId&month=$month&year=$year';

    context.push('/pdf-viewer', extra: {
      'title': 'Attendance Report',
      'pdfUrl': url,
    });
  }

  Widget _buildFilterSection(BuildContext context, WidgetRef ref) {
    final classesState = ref.watch(classesProvider);
    final selectedClass = ref.watch(selectedReportClassProvider);
    final selectedSection = ref.watch(selectedReportSectionProvider);
    final selectedMonth = ref.watch(selectedReportMonthProvider);
    final selectedYear = ref.watch(selectedReportYearProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          classesState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => ApiErrorWidget(error: err, onRetry: () => ref.invalidate(classesProvider)),
            data: (classes) {
              if (classes.isEmpty) return Text('No allotted ${ref.watch(terminologyProvider).classesLabel.toLowerCase()} found.');

              return Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedClass,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: ref.watch(terminologyProvider).classLabel, border: const OutlineInputBorder()),
                      items: classes.map((c) => DropdownMenuItem<Map<String, dynamic>>(
                            value: c as Map<String, dynamic>,
                            child: Text(c['name'], overflow: TextOverflow.ellipsis),
                          )).toList(),
                      onChanged: (val) {
                        ref.read(selectedReportClassProvider.notifier).state = val;
                        ref.read(selectedReportSectionProvider.notifier).state = null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedSection,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: ref.watch(terminologyProvider).sectionLabel, border: const OutlineInputBorder()),
                      items: (selectedClass != null ? (selectedClass['sections'] as List).cast<Map<String, dynamic>>() : [])
                          .map<DropdownMenuItem<Map<String, dynamic>>>((s) => DropdownMenuItem(value: s, child: Text(s['name'], overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (val) {
                        ref.read(selectedReportSectionProvider.notifier).state = val;
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedMonth,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
                  items: List.generate(12, (i) {
                    final date = DateTime(2000, i + 1, 1);
                    return DropdownMenuItem(
                      value: i + 1,
                      child: Text(DateFormat('MMMM').format(date)),
                    );
                  }),
                  onChanged: (val) => ref.read(selectedReportMonthProvider.notifier).state = val!,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selectedYear,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                  items: [DateTime.now().year, DateTime.now().year - 1].map((y) {
                    return DropdownMenuItem(value: y, child: Text(y.toString()));
                  }).toList(),
                  onChanged: (val) => ref.read(selectedReportYearProvider.notifier).state = val!,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportContent extends ConsumerWidget {
  const _ReportContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportState = ref.watch(studentAttendanceReportProvider);
    final selectedClass = ref.watch(selectedReportClassProvider);
    final selectedSection = ref.watch(selectedReportSectionProvider);

    if (selectedClass == null || selectedSection == null) {
      return Center(child: Text('Select a ${ref.watch(terminologyProvider).classLabel.toLowerCase()} and ${ref.watch(terminologyProvider).sectionLabel.toLowerCase()} to view the report.'));
    }

    return reportState.when(
      loading: () => SkeletonLoaders.dashboard(),
      error: (err, stack) => ApiErrorWidget(error: err, onRetry: () => ref.invalidate(studentAttendanceReportProvider)),
      data: (data) {
        if (data == null) return const Center(child: Text('No data found.'));

        final students = List<dynamic>.from(data['attendance_data'] ?? []);
        
        if (students.isEmpty) {
           return Center(child: Text('No students found in this ${ref.watch(terminologyProvider).sectionLabel.toLowerCase()}.'));
        }

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(studentAttendanceReportProvider.future),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final summary = student['summary'] as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              student['student_name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Text('Roll No: ${student['roll_no'] ?? '-'}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatBadge('Present', summary['P']?.toString() ?? '0', Colors.green),
                          _buildStatBadge('Absent', summary['A']?.toString() ?? '0', Colors.red),
                          _buildStatBadge('Late', summary['L']?.toString() ?? '0', Colors.orange),
                          _buildStatBadge('Half Day', summary['H']?.toString() ?? '0', Colors.blue),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ],
    );
  }
}
