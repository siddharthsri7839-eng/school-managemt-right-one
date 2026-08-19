import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import 'leave_providers.dart';

class MyLeaveRequestsScreen extends ConsumerWidget {
  const MyLeaveRequestsScreen({super.key});

  // Helper method to determine the color of the status chip
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaveRequestsState = ref.watch(myLeaveRequestsProvider);

    return MainScaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myLeaveRequestsProvider.future),
        child: leaveRequestsState.when(
          loading: () => SkeletonLoaders.listTile(),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (requests) {
            if (requests.isEmpty) {
              return const Center(child: Text('You have not applied for any leave yet.'));
            }
            return ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                final status = request['status'] as String;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(
                      request['leave_type']['name'] ?? 'Leave Request',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${DateFormat('dd MMM, yyyy').format(DateTime.parse(request['start_date']))} to ${DateFormat('dd MMM, yyyy').format(DateTime.parse(request['end_date']))}',
                    ),
                    trailing: Chip(
                      label: Text(
                        status,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: _getStatusColor(status),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to the apply screen, then refresh the list when we return.
          await context.push('/dashboard/my-leave/apply');
          ref.invalidate(myLeaveRequestsProvider);
        },
        child: const Icon(Icons.add),
        tooltip: 'Apply for Leave',
      ),
    );
  }
}