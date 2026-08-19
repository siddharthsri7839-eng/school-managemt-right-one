import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ THE FIX: Import the file where 'apiClientProvider' is defined.
// This provider lives in the 'attendance' feature for now.
import '../../attendance/presentation/attendance_providers.dart';

import '../data/leave_repository.dart';

// A provider for the repository itself
final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  // This line will now work correctly because of the import above.
  return LeaveRepository(ref.watch(apiClientProvider));
});

// A provider to fetch the list of leave requests
final myLeaveRequestsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(leaveRepositoryProvider).getMyLeaveRequests();
});

// ✅ ADD THIS NEW PROVIDER
// Fetches the list of leave types for the dropdown in the application form.
final leaveTypesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(leaveRepositoryProvider).getLeaveTypes();
});

// --- ADMIN PROVIDERS ---
final allLeaveRequestsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final response = await ref.watch(leaveRepositoryProvider).getAllLeaveRequests();
  return response; 
});