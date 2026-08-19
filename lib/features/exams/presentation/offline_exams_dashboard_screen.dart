import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import 'offline_exams_providers.dart';

class OfflineExamsDashboardScreen extends ConsumerStatefulWidget {
  const OfflineExamsDashboardScreen({super.key});

  @override
  ConsumerState<OfflineExamsDashboardScreen> createState() => _OfflineExamsDashboardScreenState();
}

class _OfflineExamsDashboardScreenState extends ConsumerState<OfflineExamsDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offlineExamsDashboardControllerProvider);
    final controller = ref.read(offlineExamsDashboardControllerProvider.notifier);

    return MainScaffold(
      title: 'Offline Examinations',
      body: RefreshIndicator(
        onRefresh: () => controller.fetchDashboardData(refresh: true),
        child: _buildBody(state, controller),
      ),
    );
  }

  Widget _buildBody(OfflineExamsDashboardState state, OfflineExamsDashboardController controller) {
    if (state.isLoading && state.data == null) {
      return SkeletonLoaders.dashboard();
    }

    if (state.errorMessage != null && state.data == null) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(state.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => controller.fetchDashboardData(refresh: true),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (state.data == null) {
      return const Center(child: Text('No data available.'));
    }

    final data = state.data!;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(data),
          const SizedBox(height: 24),
          _buildOverallProgress(data),
          const SizedBox(height: 24),
          // More widgets will go here
          _buildQuickStats(data),
          const SizedBox(height: 24),
          _buildExamProgressTable(data),
          const SizedBox(height: 24),
          _buildRecentExams(data),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Exams This Session',
                value: '${data['sessionExams']}',
                subtext: '${data['sessionExams']} total all-time',
                icon: Icons.article_outlined,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                title: 'Upcoming Exams',
                value: '${data['upcomingExamsCount']}',
                subtext: '${data['ongoingExamsCount']} ongoing now',
                icon: Icons.calendar_today_outlined,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Marks Entry',
                value: '${data['marksEntryPct']}%',
                subtext: '${data['scoredDistributions']} of ${data['totalDistributions']} subjects',
                icon: Icons.edit_note_outlined,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                title: 'Published',
                value: '${data['publishedSetups']}',
                subtext: '${data['publishedUploads']} uploaded marksheets',
                icon: Icons.description_outlined,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Hug content vertically
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgress(Map<String, dynamic> data) {
    final double pct = (data['marksEntryPct'] as num).toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.radio_button_checked, color: Colors.blue.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                'Overall Marks Entry Progress',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              const Spacer(),
              Text(
                '${pct.toStringAsFixed(0)}%',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: pct >= 100 ? Colors.green : Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Percentage of class-subject distributions that have marks entered.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, color: Colors.grey.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Operations',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildOperationRow('Exam Types', '${data['examTypesCount']}', Icons.category, Colors.orange),
          const Divider(),
          _buildOperationRow('Grades', '${data['gradesCount']}', Icons.grade, Colors.purple),
          const Divider(),
          _buildOperationRow('Scheduled Papers', '${data['schedulesCount']}', Icons.event_note, Colors.green),
          const Divider(),
          _buildOperationRow('Report Card Setups', '${data['reportSetupsCount']}', Icons.settings_applications, Colors.teal),
        ],
      ),
    );
  }

  Widget _buildOperationRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildExamProgressTable(Map<String, dynamic> data) {
    final progressList = data['examProgress'] as List<dynamic>? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, color: Colors.blue.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Marks Entry Progress by Exam',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (progressList.isEmpty)
            Text('No exams found.', style: TextStyle(color: Colors.grey.shade500))
          else
            ...progressList.map((exam) {
              final double pct = (exam['percent'] as num).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exam['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Text(
                          '${exam['scored']}/${exam['total']} · ${pct.toStringAsFixed(0)}%',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: exam['total'] > 0 ? pct / 100 : 0,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(pct >= 100 ? Colors.green : Colors.blue),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentExams(Map<String, dynamic> data) {
    final recentExams = data['recentExams'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.grey.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Recent Exams',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentExams.isEmpty)
            Text('No recent exams.', style: TextStyle(color: Colors.grey.shade500))
          else
            ...recentExams.map((exam) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.article, color: Colors.blue.shade400, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(exam['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${exam['session']} · ${exam['start_date'] ?? 'No date'}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
