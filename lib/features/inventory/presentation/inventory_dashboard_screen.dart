import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import 'inventory_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class InventoryDashboardScreen extends ConsumerWidget {
  const InventoryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(inventoryDashboardProvider);

    return MainScaffold(
      title: 'Inventory Dashboard',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(inventoryDashboardProvider.future),
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
                  onRetry: () => ref.invalidate(inventoryDashboardProvider),
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
              child: Icon(Icons.inventory_2, size: 80, color: Colors.red.shade400),
            ),
            const SizedBox(height: 32),
            const Text(
              'Inventory Module Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'The Inventory & Stock module is currently disabled for your school. Please contact your school administrator to upgrade your plan or enable this feature.',
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
    final lowStock = data['low_stock_items'] as List<dynamic>;
    final expiring = data['expiring_soon'] as List<dynamic>;
    final recent = data['recent_activity'] as List<dynamic>;
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
              childAspectRatio: 1.8,
              children: [
                _buildGradientCard(
                  title: 'Total Items',
                  value: '${stats['total_items']}',
                  icon: Icons.category,
                  color: Colors.blue,
                ),
                _buildGradientCard(
                  title: 'Low Stock',
                  value: '${stats['low_stock_count']}',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
                _buildGradientCard(
                  title: 'Expired Items',
                  value: '${stats['expired_count']}',
                  icon: Icons.event_busy,
                  color: Colors.red,
                ),
                _buildGradientCard(
                  title: 'Stock Value',
                  value: formatCurrency.format(stats['total_stock_value']),
                  icon: Icons.monetization_on,
                  color: Colors.teal,
                ),
              ],
            ),
          ),

          // Main Body Offset
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
                    // 2. Categories Breakdown
                    _buildSectionTitle('Items by Category'),
                    if (categories.isEmpty)
                      const Text('No categories found.', style: TextStyle(color: Colors.black54))
                    else
                      ...categories.take(5).map((cat) => _buildCategoryProgress(cat, stats['total_items'])),
                    
                    const SizedBox(height: 24),

                    // 3. Alerts (Low Stock / Expiring)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildAlertColumn(
                            title: 'Low Stock',
                            items: lowStock,
                            icon: Icons.arrow_downward,
                            color: Colors.orange,
                            itemBuilder: (item) => '${item['stock_quantity']} / ${item['min_stock_level']} left',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildAlertColumn(
                            title: 'Expiring Soon',
                            items: expiring,
                            icon: Icons.timer,
                            color: Colors.red,
                            itemBuilder: (item) => item['expiry_date'] ?? 'No date',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // 4. Recent Activity
                    _buildSectionTitle('Recent Activity'),
                    if (recent.isEmpty)
                      const Text('No recent activity.', style: TextStyle(color: Colors.black54))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recent.length,
                        itemBuilder: (context, index) {
                          final activity = recent[index];
                          return _buildActivityTile(activity);
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
                  fontSize: 22,
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

  Widget _buildCategoryProgress(Map<String, dynamic> cat, int totalItems) {
    final count = cat['count'] as int;
    final double percentage = totalItems > 0 ? count / totalItems : 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('$count items', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade200,
              color: Colors.blue.shade400,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertColumn({
    required String title,
    required List<dynamic> items,
    required IconData icon,
    required MaterialColor color,
    required String Function(Map<String, dynamic>) itemBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color.shade700),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('All clear', style: TextStyle(fontSize: 12, color: Colors.black54))
          else
            ...items.take(3).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    itemBuilder(item),
                    style: TextStyle(fontSize: 11, color: color.shade700),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> activity) {
    IconData icon;
    Color color;

    switch (activity['type']) {
      case 'stock_in':
        icon = Icons.add_circle;
        color = Colors.green;
        break;
      case 'issue':
        icon = activity['label'].contains('returned') ? Icons.undo : Icons.arrow_outward;
        color = activity['label'].contains('returned') ? Colors.blue : Colors.orange;
        break;
      case 'adjustment':
        icon = Icons.tune;
        color = Colors.purple;
        break;
      default:
        icon = Icons.history;
        color = Colors.grey;
    }

    final dateStr = activity['at'];
    String timeAgo = '';
    if (dateStr != null) {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) {
        timeAgo = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = '${diff.inMinutes}m ago';
      }
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        activity['item'],
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        activity['label'],
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            activity['qty'].toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: activity['qty'].toString().startsWith('-') ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(height: 4),
          Text(timeAgo, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
