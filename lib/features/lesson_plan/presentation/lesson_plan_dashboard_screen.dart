import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import 'lesson_plan_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class LessonPlanDashboardScreen extends ConsumerWidget {
  const LessonPlanDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(lessonPlanDashboardProvider);

    return MainScaffold(
      title: 'Lesson Planner',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(lessonPlanDashboardProvider.future),
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
                  onRetry: () => ref.invalidate(lessonPlanDashboardProvider),
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
              child: Icon(Icons.menu_book, size: 80, color: Colors.red.shade400),
            ),
            const SizedBox(height: 32),
            const Text(
              'Lesson Planner Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'The Lesson Planner module is currently disabled for your school. Please contact your school administrator.',
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
    final recentList = List<Map<String, dynamic>>.from(data['recent_list'] ?? []);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stats Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildStatCard(title: 'TOTAL PLANS', value: '${stats['total_plans']}', icon: Icons.assignment, color: Colors.blue),
                _buildStatCard(title: 'DRAFTS', value: '${stats['draft_plans']}', icon: Icons.edit, color: Colors.blueGrey),
                _buildStatCard(title: 'PENDING REVIEW', value: '${stats['pending_plans']}', icon: Icons.hourglass_empty, color: Colors.orange),
                _buildStatCard(title: 'APPROVED', value: '${stats['approved_plans']}', icon: Icons.check_circle, color: Colors.green),
                _buildStatCard(title: 'NEEDS REVISION', value: '${stats['rejected_plans']}', icon: Icons.refresh, color: Colors.red),
                _buildStatCard(title: 'THIS WEEK', value: '${stats['this_week_plans']}', icon: Icons.event, color: Colors.purple),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Action / Coverage Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    title: 'Awaiting final approval',
                    value: '${stats['awaiting_approval']}',
                    subtitle: 'plan(s) pending action',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCoverageCard(
                    coveragePct: stats['coverage_pct'],
                    notCovered: stats['not_covered_count'],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1),

          // 3. Recent Lesson Plans
          if (recentList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Recent lesson plans',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
            ),
            ...recentList.map((m) => _buildPlanListTile(m)),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.shade400, color.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.1, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required String value, required String subtitle, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildCoverageCard({required dynamic coveragePct, required int notCovered}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Syllabus coverage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            coveragePct != null ? '$coveragePct%' : 'N/A',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: coveragePct != null ? Colors.green : Colors.grey),
          ),
          const SizedBox(height: 4),
          if (notCovered > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
              child: Text(
                '$notCovered topic(s) not covered',
                style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          else
            const Text('topics covered vs planned', style: TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPlanListTile(Map<String, dynamic> plan) {
    Color statusColor;
    String statusText = (plan['status'] ?? '').toString();
    
    switch (statusText) {
      case 'draft':
        statusColor = Colors.grey;
        statusText = 'Draft';
        break;
      case 'pending_hod':
        statusColor = Colors.cyan;
        statusText = 'Pending HOD';
        break;
      case 'pending_principal':
        statusColor = Colors.blue;
        statusText = 'Pending Principal';
        break;
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Approved';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Needs revision';
        break;
      default:
        statusColor = Colors.black;
        statusText = statusText.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    plan['title'] ?? 'Untitled',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${plan['class_section']} • ${plan['subject']}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'By: ${plan['teacher']}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  'Week: ${plan['week']}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Topics: ${plan['topics_count'] ?? 0}',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
