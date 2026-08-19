import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import 'front_office_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class FrontOfficeDashboardScreen extends ConsumerWidget {
  const FrontOfficeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(frontOfficeDashboardProvider);

    return MainScaffold(
      title: 'Front Office',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(frontOfficeDashboardProvider.future),
        child: dashboardState.when(
          loading: () => SkeletonLoaders.dashboard(),
          error: (err, stack) {
            // Check for the strict "module_disabled" 403 error
            if (err is ApiException && err.errorCode == 'FORBIDDEN' && err.message == 'module_disabled') {
              return _buildModuleDisabledWarning(context);
            }
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: ApiErrorWidget(
                  error: err,
                  onRetry: () => ref.invalidate(frontOfficeDashboardProvider),
                ),
              ),
            );
          },
          data: (data) => _buildDashboard(context, data, ref),
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
              child: Icon(Icons.block, size: 80, color: Colors.red.shade400),
            ),
            const SizedBox(height: 32),
            const Text(
              'Module Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'The Front Office module is currently disabled for your school. Please contact your school administrator to upgrade your plan or enable this feature.',
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

  Widget _buildDashboard(BuildContext context, Map<String, dynamic> data, WidgetRef ref) {
    final stats = data['stats'] as Map<String, dynamic>;
    final recentEnquiries = data['recent_enquiries'] as List<dynamic>;

    final currentStatus = ref.watch(frontOfficeStatusFilterProvider);
    final currentSort = ref.watch(frontOfficeSortProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Grid Header
          Container(
            color: Theme.of(context).primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.8, // More compact ratio
                  children: [
                    _buildStatCard(
                      title: 'Total Enquiries',
                      value: '${stats['total_enquiries']}',
                      icon: Icons.people_alt,
                      color: Colors.blue,
                    ),
                    _buildStatCard(
                      title: 'Pending Follow-ups',
                      value: '${stats['pending_followups']}',
                      icon: Icons.warning_amber_rounded,
                      color: Colors.red,
                    ),
                    _buildStatCard(
                      title: 'Walk-in Source',
                      value: '${stats['source_walkin']}',
                      icon: Icons.directions_walk,
                      color: Colors.teal,
                    ),
                    _buildStatCard(
                      title: 'Online Source',
                      value: '${stats['source_online']}',
                      icon: Icons.language,
                      color: Colors.purple,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Recent Enquiries List
          Transform.translate(
            offset: const Offset(0, -16),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Filter & Sort
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Enquiries',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.filter_list,
                                color: currentStatus != 'All' ? Theme.of(context).primaryColor : Colors.grey,
                              ),
                              tooltip: 'Filter by Status',
                              onSelected: (val) => ref.read(frontOfficeStatusFilterProvider.notifier).state = val,
                              itemBuilder: (context) => [
                                'All', 'Pending', 'Followed-up', 'Interested', 'Admitted', 'Lost', 'Closed'
                              ].map((status) => PopupMenuItem(
                                value: status,
                                child: Text(status),
                              )).toList(),
                            ),
                            PopupMenuButton<String?>(
                              icon: Icon(
                                Icons.sort,
                                color: currentSort != null ? Theme.of(context).primaryColor : Colors.grey,
                              ),
                              tooltip: 'Sort by Follow-up',
                              onSelected: (val) => ref.read(frontOfficeSortProvider.notifier).state = val,
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: null, child: Text('Default (Recent)')),
                                PopupMenuItem(value: 'asc', child: Text('Follow-up (Oldest first)')),
                                PopupMenuItem(value: 'desc', child: Text('Follow-up (Newest first)')),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (currentStatus != 'All')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Chip(
                          label: Text('Status: $currentStatus', style: const TextStyle(fontSize: 12)),
                          onDeleted: () => ref.read(frontOfficeStatusFilterProvider.notifier).state = 'All',
                          backgroundColor: Colors.blue.shade50,
                        ),
                      ),
                    
                    if (recentEnquiries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                            'No enquiries found.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentEnquiries.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final enquiry = recentEnquiries[index];
                          return _buildEnquiryTile(enquiry);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.shade400, color.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 24, color: Colors.white),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEnquiryTile(Map<String, dynamic> enquiry) {
    final studentName = enquiry['student_name'] ?? 'Unknown';
    final initials = studentName.isNotEmpty ? studentName.substring(0, 1).toUpperCase() : '?';
    final status = enquiry['status'] ?? 'Pending';
    
    Color statusColor = Colors.grey;
    if (status == 'Pending') statusColor = Colors.orange;
    if (status == 'Followed-up') statusColor = Colors.blue;
    if (status == 'Interested') statusColor = Colors.green;
    if (status == 'Admitted') statusColor = Colors.purple;
    if (status == 'Lost' || status == 'Closed') statusColor = Colors.red;

    String nextFollowUpStr = '-';
    if (enquiry['follow_up_date'] != null) {
      final followUpDate = DateTime.parse(enquiry['follow_up_date']);
      nextFollowUpStr = DateFormat('dd MMM, yyyy').format(followUpDate);
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade700,
        child: Text(initials, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text(
        studentName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.phone, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(enquiry['phone'] ?? 'No Phone', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text('Follow-up: $nextFollowUpStr', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
