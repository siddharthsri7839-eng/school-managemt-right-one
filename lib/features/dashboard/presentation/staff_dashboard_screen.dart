import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_erp_staff_app/features/dashboard/domain/dashboard_models.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/core/auth/permission_service.dart';
import 'package:school_erp_staff_app/features/auth/presentation/auth_controller.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'dashboard_providers.dart';
import 'widgets/analytics_widgets.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import 'package:school_erp_staff_app/core/update/update_gate.dart';
import 'package:school_erp_staff_app/features/surveys/presentation/survey_alert.dart';

class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardDataProvider);

    return MainScaffold(
      showAppBar: false,
      useSafeArea: false,
      floatingActionButton: ref.watch(chatbotConfigProvider).when(
        data: (config) {
          final isEnabled = config['enabled'] == true;
          if (!isEnabled) return null;

          final logoPath = config['logo'] as String?;
          final storageBaseUrl = ref.watch(apiClientProvider).storageBaseUrl;
          Widget iconWidget = const Icon(Icons.smart_toy, color: Colors.white);

          if (logoPath != null && logoPath.isNotEmpty) {
            final fullLogoUrl = '$storageBaseUrl/storage/${logoPath.replaceFirst(RegExp(r'^/+'), '')}';
            iconWidget = ClipOval(
              child: Image.network(
                fullLogoUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) =>
                    const Icon(Icons.smart_toy, color: Colors.white),
              ),
            );
          }

          return FloatingActionButton(
            onPressed: () => context.push('/chatbot'),
            backgroundColor: Theme.of(context).primaryColor,
            child: iconWidget,
          );
        },
        loading: () => FloatingActionButton(
          onPressed: () => context.push('/chatbot'),
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.smart_toy, color: Colors.white),
        ),
        error: (_, __) => null,
      ),
      body: Stack(
        children: [
          // Invisible: once-per-run "update available" check (App Distribution).
          const UpdateGate(appKey: 'staff'),
          // Invisible: once-per-run "important survey" nudge.
          const SurveyAlertGate(),
          RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardDataProvider),
        child: dashboardState.when(
          loading: () => SkeletonLoaders.dashboard(),
          error: (err, stack) {
            final errorStr = err.toString();
            if (errorStr.contains('403')) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.blue),
                      SizedBox(height: 16),
                      Text(
                        'Welcome to Dashboard!',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Detailed metrics are currently optimized for academic staff. You can still use the quick links below to access your HR features.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Failed to load dashboard data: $err'),
              ),
            );
          },
          data: (dashboardData) {
            // Get user data for fallback
            final user = ref.watch(authControllerProvider).value;
            
            // Merge role and name into data if missing (for non-academic staff who get empty dashboard data)
            final Map<String, dynamic> data = Map.from(dashboardData);
            if (user != null) {
              data['role'] ??= user.role;
              data['name'] ??= user.name;
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // 1. Premium Hero Header
                  AnalyticsHeroHeader(data: data),

                  // 2. Metrics (Moved from header to floating white cards)
                  Transform.translate(
                    offset: const Offset(0, -16),
                    child: AnalyticsTopMetricsRow(data: data),
                  ),

                  // ADD THIS SPACE HERE
                  const SizedBox(height: 0),
                  
                  // NEW: Quick Links 4x1 Menu
                  AnalyticsQuickLinksRow(data: data),
                  

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





  Widget _buildUpcomingEvents(BuildContext context, Map<String, dynamic> data) {
    final List<UpcomingEventItem> events = (data['upcoming_events'] as List? ?? [])
        .map((item) => UpcomingEventItem.fromJson(item))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Notices & Events", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        if (events.isEmpty)
          const Card(child: ListTile(title: Center(child: Text("No upcoming activities."))))
        else
          ...events.map((event) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              leading: Icon(
                event.type == 'holiday' ? Icons.beach_access : event.type == 'notice' ? Icons.campaign : Icons.event,
                color: Theme.of(context).primaryColor,
              ),
              title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: Text(event.date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          )),
      ],
    );
  }
}