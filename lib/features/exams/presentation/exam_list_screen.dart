import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package:school_erp_staff_app/features/dashboard/presentation/dashboard_controller.dart';
import '../data/exam_repository.dart';
import 'exam_controller.dart';

class ExamListScreen extends ConsumerWidget {
  const ExamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examState = ref.watch(examControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exams & Reports')),
      body: examState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(child: Text('No reports have been published yet.'));
          }
          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return ListTile(
                leading: Icon(report['type'] == 'report_card'
                    ? Icons.description
                    : Icons.cloud_upload),
                title: Text(report['title']),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  final studentId = ref.read(dashboardControllerProvider).value?.selectedChild?['id'];
                  if (studentId == null) return;

                  if (report['type'] == 'report_card') {
                    context.go('/dashboard/exams/report-card/${report['id']}');
                  } else {
                    ExamRepository().openUploadedMarksheet(
                      studentId: studentId,
                      marksheetId: report['id'],
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}