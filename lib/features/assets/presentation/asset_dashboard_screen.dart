import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import 'asset_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class AssetDashboardScreen extends ConsumerWidget {
  const AssetDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(assetDashboardProvider);

    return MainScaffold(
      title: 'Asset Management',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(assetDashboardProvider.future),
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
                  onRetry: () => ref.invalidate(assetDashboardProvider),
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
              child: Icon(Icons.business_center, size: 80, color: Colors.red.shade400),
            ),
            const SizedBox(height: 32),
            const Text(
              'Assets Module Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'The Asset Management module is currently disabled for your school. Please contact your school administrator to upgrade your plan.',
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
    final categories = data['category_breakdown'] as List<dynamic>;
    final warranty = data['warranty_expiring'] as List<dynamic>;
    final maintenance = data['maintenance_due'] as List<dynamic>;
    final statusCounts = data['status_counts'] as Map<String, dynamic>;
    final currencySymbol = data['currency_symbol'] as String? ?? '\$';

    final formatCurrency = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);

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
                  title: 'Total Assets',
                  value: '${stats['total_assets']}',
                  icon: Icons.inventory_2,
                  color: Colors.blue,
                ),
                _buildGradientCard(
                  title: 'Under Maintenance',
                  value: '${stats['under_maintenance']}',
                  icon: Icons.build,
                  color: Colors.amber,
                ),
                _buildGradientCard(
                  title: 'Acquisition Value',
                  value: formatCurrency.format(stats['acquisition_value']),
                  icon: Icons.account_balance_wallet,
                  color: Colors.green,
                ),
                _buildGradientCard(
                  title: 'Book Value',
                  value: formatCurrency.format(stats['book_value']),
                  icon: Icons.trending_up,
                  color: Colors.teal,
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
                    // 2. Status Badges Horizontal Scroll
                    _buildSectionTitle('By Status'),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChip('In Use', statusCounts['in_use'] ?? 0, Colors.blue),
                          _buildStatusChip('In Store', statusCounts['in_store'] ?? 0, Colors.grey),
                          _buildStatusChip('Under Maint.', statusCounts['under_maintenance'] ?? 0, Colors.amber),
                          _buildStatusChip('Disposed', statusCounts['disposed'] ?? 0, Colors.red),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. Maintenance Due
                    _buildSectionTitle('Maintenance Due & Overdue'),
                    if (maintenance.isEmpty)
                      const Text('No maintenance scheduled.', style: TextStyle(color: Colors.black54))
                    else
                      ...maintenance.map((m) => _buildMaintenanceCard(m)),

                    const SizedBox(height: 24),

                    // 4. Categories Breakdown
                    _buildSectionTitle('Assets by Category'),
                    if (categories.isEmpty)
                      const Text('No categories found.', style: TextStyle(color: Colors.black54))
                    else
                      ...categories.take(5).map((cat) => _buildCategoryProgress(cat, stats['total_assets'])),
                    
                    const SizedBox(height: 24),

                    // 5. Warranty Expiring
                    _buildSectionTitle('Warranty Expiring (30 Days)'),
                    if (warranty.isEmpty)
                      const Text('No warranties expiring soon.', style: TextStyle(color: Colors.black54))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: warranty.length,
                        separatorBuilder: (c, i) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = warranty[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('Tag: ${item['tag']} • ${item['category']}', style: const TextStyle(fontSize: 12)),
                            trailing: Text(item['expiry_date'] ?? 'N/A', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          );
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
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

  Widget _buildStatusChip(String label, int count, MaterialColor color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: color.shade400,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceCard(Map<String, dynamic> m) {
    final isOverdue = m['is_overdue'] == true;
    final color = isOverdue ? Colors.red : Colors.orange;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.shade100),
      ),
      color: color.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.build_circle, color: color.shade400, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['asset_name'],
                    style: TextStyle(fontWeight: FontWeight.bold, color: color.shade900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    m['task'],
                    style: TextStyle(fontSize: 12, color: color.shade700),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isOverdue ? 'OVERDUE' : 'DUE',
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  m['due_date'] ?? '',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryProgress(Map<String, dynamic> cat, int totalAssets) {
    final count = cat['count'] as int;
    final double percentage = totalAssets > 0 ? count / totalAssets : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('$count assets', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade200,
              color: Colors.indigo.shade400,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
