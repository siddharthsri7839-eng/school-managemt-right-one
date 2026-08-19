import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:school_erp_staff_app/features/chatbot/data/chatbot_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/staff_dashboard_repository.dart';
import '../domain/calendar_event.dart';

// Provider for the repository
final dashboardRepositoryProvider = Provider<StaffDashboardRepository>((ref) {
  return StaffDashboardRepository(ref.watch(apiClientProvider));
});

// A single provider to get all dashboard data. The API will tailor the response.
final dashboardDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) {
    throw 'Session expired. Please log in again.';
  }
  return ref.watch(dashboardRepositoryProvider).getDashboardData();
});

// ✅ ADD THIS NEW PROVIDER
final calendarEventsProvider = FutureProvider.autoDispose<List<CalendarEvent>>((ref) async {
  final user = await ref.watch(authControllerProvider.future);
  if (user == null) {
    throw 'Session expired. Please log in again.';
  }
  return ref.watch(dashboardRepositoryProvider).getCalendarEvents();
});

/// Chatbot config (name, logo path, enabled).
/// Used by the dashboard FAB to show the dynamic AI avatar image.
final chatbotConfigProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final chatbotService = ref.watch(chatbotServiceProvider);
  return chatbotService.fetchConfig();
});