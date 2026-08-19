import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/main_scaffold.dart';
import '../../../shared/widgets/api_error_widget.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import 'ptm_providers.dart';

class PtmRecordListScreen extends ConsumerWidget {
  const PtmRecordListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // using page 1 for simplicity right now
    final listState = ref.watch(ptmRecordMeetingsProvider(1));

    return MainScaffold(
      title: 'Record Attendance & Remarks',
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(ptmRecordMeetingsProvider(1).future),
        child: listState.when(
          loading: () => SkeletonLoaders.listTile(count: 5),
          error: (err, stack) => ApiErrorWidget(
            error: err,
            onRetry: () => ref.invalidate(ptmRecordMeetingsProvider(1)),
          ),
          data: (data) {
            final meetings = List<Map<String, dynamic>>.from(data['meetings'] ?? []);
            
            if (meetings.isEmpty) {
              return _buildEmptyState(context);
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: meetings.length,
              itemBuilder: (context, index) {
                final meeting = meetings[index];
                return _buildMeetingTile(context, meeting);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            const Text(
              'No Meetings Found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            const Text(
              'There are no upcoming or active meetings assigned to you for recording.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeetingTile(BuildContext context, Map<String, dynamic> meeting) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/dashboard/ptm/record/${meeting['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        meeting['title'] ?? 'Untitled Meeting',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.teal.shade100),
                      ),
                      child: Text(
                        (meeting['status'] ?? '').toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      meeting['date'] ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.class_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        meeting['scope'] == 'school' 
                            ? 'Whole School' 
                            : '${meeting['school_class']?['name'] ?? ''} ${meeting['section']?['name'] != null ? '/ ${meeting['section']['name']}' : ''}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatPill(
                      Icons.people_outline,
                      '${meeting['invitations_count'] ?? 0} Invited',
                      Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildStatPill(
                      Icons.check_circle_outline,
                      '${meeting['present_count'] ?? 0} Present',
                      Colors.green,
                    ),
                    const Spacer(),
                    const Text(
                      'Record',
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward, size: 16, color: Colors.teal),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
