import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import 'cbc_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class CbcDashboardScreen extends ConsumerWidget {
  const CbcDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(cbcDashboardProvider);

    return MainScaffold(
      title: 'CBC Academics',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(cbcDashboardProvider.future),
        child: dashboardState.when(
          loading: () => SkeletonLoaders.dashboard(),
          error: (err, stack) {
            if (err is ApiException && err.errorCode == 'FORBIDDEN' && err.message == 'module_disabled') {
              return _buildModuleDisabledWarning(context);
            }
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: ApiErrorWidget(
                  error: err,
                  onRetry: () => ref.invalidate(cbcDashboardProvider),
                ),
              ),
            );
          },
          data: (data) => _buildDashboard(context, data),
        ),
      ),
    );
  }

  Widget _buildModuleDisabledWarning(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.category, size: 80, color: Colors.red.shade400),
            ),
            const SizedBox(height: 32),
            const Text(
              'CBC Module Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'The CBC (Competency-Based Curriculum) module is currently disabled for your school. Please contact your school administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, Map<String, dynamic> data) {
    final stats = data['stats'] as Map<String, dynamic>;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.blue.shade700, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Competency-Based Assessment System',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Assess what students can do, not just what they know. This module supports competency-based education frameworks across the globe.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // 2. Stats Row
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('STRANDS DEFINED', '${stats['strand_count']}', Colors.blue),
                _buildStatColumn('COMPETENCIES', '${stats['competency_count']}', Colors.green),
                _buildStatColumn('ASSESSMENTS', '${stats['assessment_count']}', Colors.orange),
              ],
            ),
          ),

          const Divider(thickness: 1, height: 1),

          // 3. Setup Workflow
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_tree, color: Colors.black87),
                    SizedBox(width: 8),
                    Text(
                      'Setup Workflow',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildWorkflowStep(
                  stepNumber: 'STEP 1',
                  title: 'Strands & Outcomes',
                  description: 'Define broad learning areas (Strands) and specific topics (Sub-strands) for each subject.',
                  icon: Icons.menu,
                  iconColor: Colors.blue,
                ),
                _buildWorkflowStep(
                  stepNumber: 'STEP 2',
                  title: 'Core Competencies',
                  description: 'Establish cross-cutting skills like Critical Thinking and Communication.',
                  icon: Icons.star,
                  iconColor: Colors.teal,
                ),
                _buildWorkflowStep(
                  stepNumber: 'STEP 3',
                  title: 'Assessments',
                  description: 'Create strand-linked assessments and grade students on a rubric scale.',
                  icon: Icons.list_alt,
                  iconColor: Colors.green,
                ),
                _buildWorkflowStep(
                  stepNumber: 'STEP 4',
                  title: 'CBC Reports',
                  description: 'Generate detailed competency report cards and progress portfolios.',
                  icon: Icons.picture_as_pdf,
                  iconColor: Colors.orange,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildWorkflowStep({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    bool isLast = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stepNumber,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}
