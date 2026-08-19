import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import 'hostel_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class HostelDashboardScreen extends ConsumerWidget {
  const HostelDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(hostelDashboardProvider);

    return MainScaffold(
      title: 'Hostel Management',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(hostelDashboardProvider.future),
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
                  onRetry: () => ref.invalidate(hostelDashboardProvider),
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
              child: Icon(Icons.apartment, size: 80, color: Colors.red.shade400),
            ),
            const SizedBox(height: 32),
            const Text(
              'Hostel Module Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'The Hostel Management module is currently disabled for your school. Please contact your school administrator to upgrade your plan.',
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
    final allocations = data['recent_allocations'] as List<dynamic>;
    final occupancy = data['occupancy_data'] as List<dynamic>;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Stats Grid
          Container(
            color: Theme.of(context).primaryColor,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _buildGradientCard(
                  title: 'Total Hostels',
                  value: '${stats['total_hostels']}',
                  icon: Icons.apartment,
                  color: Colors.indigo,
                ),
                _buildGradientCard(
                  title: 'Total Rooms',
                  value: '${stats['total_rooms']}',
                  icon: Icons.meeting_room,
                  color: Colors.orange,
                ),
                _buildGradientCard(
                  title: 'Occupied Beds',
                  value: '${stats['occupied_beds']}',
                  icon: Icons.bed,
                  color: Colors.red,
                ),
                _buildGradientCard(
                  title: 'Available Beds',
                  value: '${stats['available_beds']}',
                  icon: Icons.check_circle_outline,
                  color: Colors.blue,
                ),
              ],
            ),
          ),

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
                    // 2. Recent Allocations
                    _buildSectionTitle('Recent Allocations', icon: Icons.history, color: Colors.indigo),
                    if (allocations.isEmpty)
                      const Text('No recent room allocations found.', style: TextStyle(color: Colors.black54))
                    else
                      ...allocations.map((a) => _buildAllocationItem(a)),

                    const SizedBox(height: 32),

                    // 3. Occupancy Status
                    _buildSectionTitle('Occupancy by Hostel', icon: Icons.pie_chart, color: Colors.indigo),
                    if (occupancy.isEmpty)
                      const Text('No occupancy data available.', style: TextStyle(color: Colors.black54))
                    else
                      ...occupancy.map((o) => _buildOccupancyBar(o)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color ?? Colors.black87, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientCard({
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
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

  Widget _buildAllocationItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            child: const Icon(Icons.person, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['student_name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['hostel_name']} - Room ${item['room_no']} (${item['room_type']})',
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Allocated ${item['allocated_at']}',
                  style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancyBar(Map<String, dynamic> item) {
    final percentage = (item['occupancy_percentage'] as num).toDouble();
    final color = percentage > 90 ? Colors.red : (percentage > 70 ? Colors.orange : Colors.green);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item['name'],
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              Text(
                '${percentage.toInt()}%',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade200,
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
