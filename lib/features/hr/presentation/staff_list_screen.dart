// lib/features/hr/presentation/staff_list_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'hr_dashboard_controller.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

final staffListProvider = FutureProvider<List<dynamic>>((ref) async {
  final dio = ApiClient().dio;
  final response = await dio.get('/staff/hr/staff-list');
  return response.data['data'] as List<dynamic>;
});

class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);
    final storageBaseUrl = ref.watch(apiClientProvider).storageBaseUrl;

    return MainScaffold(
      title: 'Staff Directory & HR',
      body: staffAsync.when(
        loading: () => SkeletonLoaders.cardList(),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (staffList) {
          final filteredList = staffList.where((staff) {
            final name = (staff['name'] ?? '').toString().toLowerCase();
            final dept = (staff['department'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || dept.contains(query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search staff by name or department...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              Expanded(
                child: _searchQuery.isEmpty 
                  ? const HrAnalyticsDashboard()
                  : filteredList.isEmpty
                    ? const Center(child: Text('No staff records found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          return _StaffListItem(
                            staff: filteredList[index],
                            storageBaseUrl: storageBaseUrl,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class HrAnalyticsDashboard extends ConsumerWidget {
  const HrAnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hrDashboardControllerProvider);

    if (state.isLoading) return SkeletonLoaders.moduleDashboard();
    
    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(state.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(hrDashboardControllerProvider.notifier).fetchDashboard(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = state.data;
    if (data == null) return const Center(child: Text('No data available.'));

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(hrDashboardControllerProvider.notifier).fetchDashboard();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _HrStatCard(title: 'TOTAL STAFF', value: data['total_staff'].toString(), icon: Icons.people, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _HrStatCard(title: 'PENDING LEAVES', value: data['pending_leaves'].toString(), icon: Icons.hourglass_empty, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _HrStatCard(title: 'ON LEAVE TODAY', value: data['on_leave_today'].toString(), icon: Icons.beach_access, color: Colors.pink)),
              const SizedBox(width: 12),
              Expanded(child: _HrStatCard(title: 'ACTIVE LOANS', value: data['active_loans'].toString(), icon: Icons.monetization_on, color: Colors.teal)),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text('Staff by Department', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _DepartmentPieChart(data: List<Map<String, dynamic>>.from(data['department_breakdown'] ?? [])),
          
          const SizedBox(height: 24),
          const Text('Pending Leave Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _PendingLeavesList(leaves: List<Map<String, dynamic>>.from(data['pending_leave_requests'] ?? [])),

          const SizedBox(height: 24),
          const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _RecentActivityList(activities: List<Map<String, dynamic>>.from(data['recent_activity'] ?? [])),

          const SizedBox(height: 24),
          const Text('Upcoming Birthdays', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _UpcomingEventsList(events: List<Map<String, dynamic>>.from(data['upcoming_birthdays'] ?? []), icon: Icons.cake, color: Colors.pink),
          
          const SizedBox(height: 24),
          const Text('Work Anniversaries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _UpcomingEventsList(events: List<Map<String, dynamic>>.from(data['upcoming_anniversaries'] ?? []), icon: Icons.work, color: Colors.indigo),
          
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _HrStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _HrStatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DepartmentPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _DepartmentPieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox(height: 100, child: Center(child: Text('No data')));
    
    final List<Color> colors = [Colors.teal, Colors.orange, Colors.blue, Colors.pink, Colors.purple, Colors.green, Colors.indigo, Colors.red, Colors.amber, Colors.cyan];

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: List.generate(data.length, (i) {
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: data[i]['total'].toDouble(),
                    title: '',
                    radius: 40,
                  );
                }),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, color: colors[i % colors.length]),
                      const SizedBox(width: 4),
                      Expanded(child: Text('${data[i]['label']}', style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingLeavesList extends StatelessWidget {
  final List<Map<String, dynamic>> leaves;
  const _PendingLeavesList({required this.leaves});

  @override
  Widget build(BuildContext context) {
    if (leaves.isEmpty) return const Text('No pending requests.');
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: leaves.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final req = leaves[i];
          return ListTile(
            leading: CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.1), child: const Icon(Icons.hourglass_empty, color: Colors.orange, size: 20)),
            title: Text(req['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('${req['type']} • ${req['dates']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            trailing: Text(req['time_ago'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          );
        },
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  const _RecentActivityList({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const Text('No recent activity.');
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final act = activities[i];
          final type = act['type'];
          
          IconData icon;
          Color color;
          
          if (type == 'staff') {
            icon = Icons.person_add;
            color = Colors.teal;
          } else if (type == 'leave') {
            icon = act['status'] == 'approved' ? Icons.check_circle : (act['status'] == 'rejected' ? Icons.cancel : Icons.hourglass_bottom);
            color = act['status'] == 'approved' ? Colors.green : (act['status'] == 'rejected' ? Colors.red : Colors.orange);
          } else {
            icon = Icons.monetization_on;
            color = Colors.indigo;
          }

          return ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
            title: Text(act['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('${act['label']} • ${act['meta']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            trailing: Text(act['time_ago'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          );
        },
      ),
    );
  }
}

class _UpcomingEventsList extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  final IconData icon;
  final Color color;
  const _UpcomingEventsList({required this.events, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const Text('No upcoming events in 30 days.');
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: events.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final ev = events[i];
          return ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
            title: Text(ev['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(ev['meta'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            trailing: Text(ev['formatted_date'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          );
        },
      ),
    );
  }
}

class _StaffListItem extends StatelessWidget {
  final dynamic staff;
  final String storageBaseUrl;
  const _StaffListItem({required this.staff, required this.storageBaseUrl});

  @override
  Widget build(BuildContext context) {
    final color = _getAttendanceColor(staff['attendance_today'] ?? 'Not Marked');
    
    final photoPath = staff['photo_url'] ?? staff['avatar'];
    String? fullPhotoUrl;
    if (photoPath != null && photoPath.toString().isNotEmpty) {
      if (photoPath.toString().startsWith('http')) {
        fullPhotoUrl = photoPath.toString();
      } else {
        fullPhotoUrl = '$storageBaseUrl$photoPath';
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: () => context.push('/dashboard/staff-list/detail/${staff['id']}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue.shade50,
                backgroundImage: fullPhotoUrl != null ? NetworkImage(fullPhotoUrl) : null,
                child: fullPhotoUrl == null 
                    ? Text((staff['name'] ?? 'S')[0].toUpperCase(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 24)) 
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${staff['designation']} • ${staff['department']}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MiniBadge(
                          label: staff['attendance_today'],
                          color: color,
                          icon: Icons.calendar_today,
                        ),
                        _MiniBadge(
                          label: '${staff['monthly_attendance_rate']}% Monthly',
                          color: Colors.blue,
                          icon: Icons.analytics,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _getAttendanceColor(String status) {
    switch (status.toLowerCase()) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'late': return Colors.orange;
      default: return Colors.grey;
    }
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _MiniBadge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
