import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import 'ptm_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class PtmDashboardScreen extends ConsumerWidget {
  const PtmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(ptmDashboardProvider);

    return MainScaffold(
      title: 'Parent-Teacher Meetings',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(ptmDashboardProvider.future),
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
                  onRetry: () => ref.invalidate(ptmDashboardProvider),
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
              child: Icon(Icons.handshake, size: 80, color: Colors.red.shade400),
            ),
            const SizedBox(height: 32),
            const Text(
              'PTM Module Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'The Parent-Teacher Meetings module is currently disabled for your school. Please contact your school administrator.',
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
    final upcomingList = List<Map<String, dynamic>>.from(data['upcoming_list'] ?? []);
    final recentList = List<Map<String, dynamic>>.from(data['recent_list'] ?? []);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Record Attendance & Remarks Card
          GestureDetector(
            onTap: () => context.push('/dashboard/ptm/record'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade600, Colors.teal.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.edit_document, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Attendance & Remarks',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mark parent attendance and add student reviews',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),

          // 2. Advance Reporting Card
          GestureDetector(
            onTap: () => context.push('/dashboard/ptm/reports'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade600, Colors.indigo.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.analytics_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advance Reporting',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'View class-wise & student-wise meeting reports',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ],
              ),
            ),
          ),

          // 2. Stats Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  title: 'MEETINGS (THIS SESSION)',
                  value: '${stats['session_meetings']}',
                  subtitle: '${stats['total_meetings']} total all-time',
                  icon: Icons.handshake,
                  color: Colors.blue,
                ),
                _buildStatCard(
                  title: 'UPCOMING MEETINGS',
                  value: '${stats['upcoming_meetings']}',
                  subtitle: '${stats['completed_meetings']} completed',
                  icon: Icons.calendar_month,
                  color: Colors.purple,
                ),
                _buildStatCard(
                  title: 'PARENT ATTENDANCE',
                  value: '${stats['attendance_pct']}%',
                  subtitle: '${stats['present_invites']} of ${stats['total_invites']} invited',
                  icon: Icons.people,
                  color: Colors.green,
                ),
                _buildStatCard(
                  title: 'OPEN FOLLOW-UPS',
                  value: '${stats['open_followups']}',
                  subtitle: 'Feedback ${stats['feedback_avg'] ?? '-'}/5 (${stats['feedback_count']})',
                  icon: Icons.check_circle_outline,
                  color: Colors.orange,
                ),
              ],
            ),
          ),

          // 3. Remark Completion Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 16, color: Colors.black54),
                          SizedBox(width: 8),
                          Text('Remark completion (this session)', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text('${stats['remark_pct']}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (stats['remark_pct'] as num) / 100,
                    backgroundColor: Colors.grey.shade200,
                    color: Colors.teal,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${stats['remarked_students'] ?? 0} students with remarks',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // 4. Meeting Lists
          if (upcomingList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Upcoming Meetings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
              ),
            ),
            ...upcomingList.map((m) => _buildMeetingListTile(m, isUpcoming: true)),
          ],

          if (recentList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Recent Meetings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
            ),
            ...recentList.map((m) => _buildMeetingListTile(m, isUpcoming: false)),
          ],
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 20, color: color),
              ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingListTile(Map<String, dynamic> meeting, {required bool isUpcoming}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          meeting['title'] ?? 'Untitled Meeting',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${meeting['date'] ?? ''} • ${meeting['scope'] == 'school' ? 'Whole School' : ((meeting['class'] ?? '') + ' / ' + (meeting['section'] ?? ''))}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              '${meeting['invitations_count'] ?? 0} invited${!isUpcoming ? ' • ${meeting['remarks_count'] ?? 0} remarks' : ''}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isUpcoming ? Colors.blue.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            (meeting['status'] ?? '').toString().toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isUpcoming ? Colors.blue.shade700 : Colors.green.shade700,
            ),
          ),
        ),
      ),
    );
  }
}
