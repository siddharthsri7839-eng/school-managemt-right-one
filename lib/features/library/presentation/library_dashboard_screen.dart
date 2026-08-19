import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../core/api/api_exception.dart';
import 'library_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class LibraryDashboardScreen extends ConsumerWidget {
  const LibraryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(libraryDashboardProvider);

    return MainScaffold(
      title: 'Library Management',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(libraryDashboardProvider.future),
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
                  onRetry: () => ref.invalidate(libraryDashboardProvider),
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
              child: Icon(Icons.local_library, size: 80, color: Colors.red.shade400),
            ),
            const SizedBox(height: 32),
            const Text(
              'Library Module Disabled',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'The Library Management module is currently disabled for your school. Please contact your school administrator to upgrade your plan.',
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
    final overdueAlerts = data['overdue_alerts'] as List<dynamic>;
    final catalog = data['library_catalog'] as List<dynamic>;

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
                _buildGradientCard(
                  title: 'TOTAL BOOKS',
                  value: '${stats['total_books']}',
                  icon: Icons.menu_book,
                  color: Colors.blue,
                ),
                _buildGradientCard(
                  title: 'ISSUED BOOKS',
                  value: '${stats['issued_books']}',
                  icon: Icons.bookmark_added,
                  color: Colors.teal,
                ),
                _buildGradientCard(
                  title: 'OVERDUE RETURNS',
                  value: '${stats['overdue_returns']}',
                  icon: Icons.warning_amber,
                  color: Colors.red,
                ),
                _buildGradientCard(
                  title: 'NEW ACQUISITIONS',
                  value: '${stats['new_acquisitions']}',
                  icon: Icons.new_releases,
                  color: Colors.purple,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Overdue Alerts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle('Overdue Alerts', icon: Icons.notification_important, color: Colors.red),
                    if (overdueAlerts.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${overdueAlerts.length} NEW',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                if (overdueAlerts.isEmpty)
                  const Text('No overdue books currently.', style: TextStyle(color: Colors.black54))
                else
                  ...overdueAlerts.map((a) => _buildOverdueAlertCard(a)),

                const SizedBox(height: 24),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 8),

                // 3. Library Catalog
                _buildSectionTitle('Library Catalog', icon: Icons.library_books, color: Colors.indigo),
                if (catalog.isEmpty)
                  const Text('No books found in the catalog.', style: TextStyle(color: Colors.black54))
                else
                  ...catalog.map((b) => _buildCatalogItem(b)),
              ],
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

  Widget _buildOverdueAlertCard(Map<String, dynamic> alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  alert['user_name'],
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${alert['days_late']} DAYS LATE',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            alert['book_title'],
            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogItem(Map<String, dynamic> book) {
    final isAvailable = book['is_available'] == true;
    final color = isAvailable ? Colors.green : Colors.red;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                book['title'].toString().substring(0, 1).toUpperCase(),
                style: TextStyle(color: Colors.indigo.shade400, fontWeight: FontWeight.bold, fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  book['author'],
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        book['category'].toString().toUpperCase(),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.circle, size: 8, color: color),
                    const SizedBox(width: 4),
                    Text(
                      isAvailable ? 'Available (${book['available_quantity']})' : 'Out of Stock',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
