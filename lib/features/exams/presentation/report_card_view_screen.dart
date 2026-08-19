import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package:school_erp_staff_app/features/dashboard/presentation/dashboard_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../data/exam_repository.dart';

class ReportCardViewScreen extends ConsumerStatefulWidget {
  final int setupId;
  const ReportCardViewScreen({super.key, required this.setupId});

  @override
  ConsumerState<ReportCardViewScreen> createState() => _ReportCardViewScreenState();
}

class _ReportCardViewScreenState extends ConsumerState<ReportCardViewScreen> {
  late final WebViewController _controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
    _loadReportCard();
  }

  Future<void> _loadReportCard() async {
    try {
      final studentId = ref.read(dashboardControllerProvider).value?.selectedChild?['id'];
      if (studentId == null) throw 'No student selected';

      final htmlContent = await ExamRepository().getReportCardHtml(
        studentId: studentId,
        setupId: widget.setupId,
      );
      await _controller.loadHtmlString(htmlContent);
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Card')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _controller),
    );
  }
}