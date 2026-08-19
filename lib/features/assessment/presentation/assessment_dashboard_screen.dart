import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/branding/branding_providers.dart';
import '../domain/assessment_models.dart';
import 'assessment_providers.dart';
import 'assessment_widgets.dart';

class AssessmentDashboardScreen extends ConsumerWidget {
  const AssessmentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentDashboardProvider);

    return MainScaffold(
      title: 'Assessment',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(assessmentDashboardProvider.future),
        child: state.when(
          loading: () => SkeletonLoaders.dashboard(),
          error: (err, _) {
            if (err is ApiException && err.message == 'module_disabled') {
              return const AssessmentModuleDisabled();
            }
            return ListView(
              children: [
                const SizedBox(height: 100),
                ApiErrorWidget(error: err, onRetry: () => ref.invalidate(assessmentDashboardProvider)),
              ],
            );
          },
          data: (data) => _buildBody(
              context, data, ref.watch(terminologyProvider).classLabel),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> data, String classLabel) {
    final stats = data['stats'] as Map<String, dynamic>;
    final recent = (data['recent'] as List).cast<AssessmentSummary>();
    final can = data['can'] as AssessmentCapabilities;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action cards
          if (can.manage)
            _actionCard(
              context,
              title: 'New Assessment',
              subtitle: 'Create a quiz, test or assignment',
              icon: Icons.add_task,
              colors: [Colors.indigo.shade600, Colors.indigo.shade400],
              onTap: () => context.push('/dashboard/assessment/create'),
            ),
          _actionCard(
            context,
            title: 'Browse Assessments',
            subtitle: 'All assessments, filter & enter marks',
            icon: Icons.list_alt,
            colors: [Colors.teal.shade600, Colors.teal.shade400],
            onTap: () => context.push('/dashboard/assessment/list'),
          ),
          if (can.report)
            _actionCard(
              context,
              title: 'Reports & Analytics',
              subtitle: '$classLabel overview, rank list, student progress',
              icon: Icons.insights,
              colors: [Colors.deepPurple.shade600, Colors.deepPurple.shade400],
              onTap: () => context.push('/dashboard/assessment/reports'),
            ),

          // KPI grid
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                StatCard(title: 'ASSESSMENTS', value: '${stats['assessments'] ?? 0}', icon: Icons.assignment_outlined, color: Colors.blue),
                StatCard(title: 'SITTINGS', value: '${stats['sittings'] ?? 0}', icon: Icons.layers_outlined, color: Colors.purple),
                StatCard(title: 'PUBLISHED', value: '${stats['published'] ?? 0}', icon: Icons.check_circle_outline, color: Colors.green),
                StatCard(title: 'AVERAGE SCORE', value: stats['avg_pct'] != null ? '${stats['avg_pct']}%' : '—', icon: Icons.percent, color: Colors.orange),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent assessments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(onPressed: () => context.push('/dashboard/assessment/list'), child: const Text('View all')),
              ],
            ),
          ),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No assessments yet.', style: TextStyle(color: Colors.grey))),
            )
          else
            ...recent.map((a) => AssessmentListTile(
                  assessment: a,
                  onTap: () => context.push('/dashboard/assessment/${a.id}'),
                )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
