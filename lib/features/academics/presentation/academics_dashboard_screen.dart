import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import '../../../core/branding/branding_providers.dart';
import '../../../core/branding/terminology.dart';
import 'academic_dashboard_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class AcademicsDashboardScreen extends ConsumerWidget {
  const AcademicsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(academicDashboardControllerProvider);
    final controller = ref.read(academicDashboardControllerProvider.notifier);

    return MainScaffold(
      title: 'Academics',
      body: _buildBody(context, state, controller, ref.watch(terminologyProvider)),
    );
  }

  Widget _buildBody(BuildContext context, AcademicDashboardState state, AcademicDashboardController controller, Terminology terms) {
    if (state.isLoading) {
      return SkeletonLoaders.dashboard();
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(state.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => controller.fetchDashboard(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.data == null) {
      return const Center(child: Text('No academic data available'));
    }

    final summary = state.data!['summary'] ?? {};
    final alerts = state.data!['alerts'] ?? {};
    final lists = state.data!['lists'] ?? {};

    return RefreshIndicator(
      onRefresh: () => controller.fetchDashboard(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Session Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Text(
                    'Session: ${summary['current_session']}',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Summary Grid
            _buildSummaryGrid(summary, terms),
            const SizedBox(height: 24),

            // 3. Timetable Alerts
            if ((alerts['missing_timetables_count'] ?? 0) > 0) ...[
              _buildAlertsSection(alerts),
              const SizedBox(height: 24),
            ],

            // 4. Today's Timetable
            _buildSectionHeader('Today\'s Timetable', Icons.schedule, Colors.indigo),
            const SizedBox(height: 16),
            _buildTodaysTimetable(lists['today_timetable'] ?? []),
            const SizedBox(height: 24),

            // 5. Teacher Workload
            _buildSectionHeader('Teacher Workload', Icons.menu_book, Colors.orange),
            const SizedBox(height: 16),
            _buildTeacherWorkload(lists['teacher_workload'] ?? [], terms),
            const SizedBox(height: 24),

            // 6. Class Overview
            _buildSectionHeader('${terms.classLabel} & ${terms.sectionLabel} Overview', Icons.class_, Colors.teal),
            const SizedBox(height: 16),
            _buildClassOverview(lists['class_overview'] ?? [], terms),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- Summary Grid ---
  Widget _buildSummaryGrid(Map<String, dynamic> summary, Terminology terms) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard('Total ${terms.classesLabel}', summary['total_classes']?.toString() ?? '0', Icons.meeting_room, Colors.blue),
        _buildStatCard('Active ${terms.subjectsLabel}', summary['active_subjects']?.toString() ?? '0', Icons.menu_book, Colors.purple),
        _buildStatCard('Timetable Done', '${summary['timetable_completion_percent'] ?? 0}%', Icons.event_available, Colors.green),
        _buildStatCard('Students', summary['students_to_promote']?.toString() ?? '0', Icons.people, Colors.orange),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 11), overflow: TextOverflow.ellipsis)),
            ],
          ),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
        ],
      ),
    );
  }

  // --- Alerts Section ---
  Widget _buildAlertsSection(Map<String, dynamic> alerts) {
    final missingList = List.from(alerts['missing_timetables'] ?? []);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Timetable Alerts (${alerts['missing_timetables_count']})',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('The following sections are missing timetables:', style: TextStyle(fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: missingList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 5,
              mainAxisSpacing: 2,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final m = missingList[index];
              return Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m['name'].toString(), 
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Today's Timetable ---
  Widget _buildTodaysTimetable(List<dynamic> timetable) {
    if (timetable.isEmpty) {
      return const Text('No timetable entries for today.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timetable.length,
      itemBuilder: (context, index) {
        final t = timetable[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.indigo.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade400, Colors.indigo.shade600],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(t['start_time'].toString().substring(0, 5), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    const SizedBox(height: 4),
                    const Icon(Icons.schedule, size: 14, color: Colors.white70),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['subject_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.class_outlined, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(t['class_section'], style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(t['teacher_name'], style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Teacher Workload ---
  Widget _buildTeacherWorkload(List<dynamic> workload, Terminology terms) {
    if (workload.isEmpty) {
      return const Text('No teacher workload data.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: workload.length,
      itemBuilder: (context, index) {
        final w = workload[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.orange.shade50,
                child: Text(w['teacher_name'].toString()[0], style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(w['teacher_name'], style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text('${w['subjects_count']} ${terms.subjectsLabel}', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Class Overview ---
  Widget _buildClassOverview(List<dynamic> classes, Terminology terms) {
    if (classes.isEmpty) {
      return const Text('No classes found.');
    }

    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.indigo,
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: classes.length,
      itemBuilder: (context, index) {
        final c = classes[index];
        final color = colors[index % colors.length];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color.shade700)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, size: 14, color: color.shade700),
                          const SizedBox(width: 6),
                          Text(c['student_count'].toString(), style: TextStyle(fontWeight: FontWeight.bold, color: color.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), shape: BoxShape.circle),
                      child: Icon(Icons.meeting_room_outlined, size: 14, color: color.shade700),
                    ),
                    const SizedBox(width: 8),
                    Text('${terms.sectionsLabel}: ${c['sections']}', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.6), shape: BoxShape.circle),
                      child: Icon(Icons.person_outline, size: 14, color: color.shade700),
                    ),
                    const SizedBox(width: 8),
                    Text('Coordinator: ${c['coordinator_name']}', style: TextStyle(color: Colors.grey.shade800)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
