import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import 'audit_trail_providers.dart';

class AuditTrailScreen extends ConsumerStatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  ConsumerState<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends ConsumerState<AuditTrailScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(auditTrailControllerProvider.notifier).fetchMoreLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditTrailControllerProvider);
    final controller = ref.read(auditTrailControllerProvider.notifier);

    return MainScaffold(
      title: 'Audit Trail',
      body: _buildBody(state, controller),
    );
  }

  Widget _buildBody(AuditTrailState state, AuditTrailController controller) {
    if (state.isLoading && state.logs.isEmpty) {
      return SkeletonLoaders.listTile();
    }

    if (state.errorMessage != null && state.logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(state.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => controller.fetchLogs(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildFilterBar(state, controller),
        Expanded(
          child: state.logs.isEmpty
              ? const Center(child: Text('No system activity found for the selected filters.'))
              : RefreshIndicator(
                  onRefresh: () => controller.fetchLogs(refresh: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: state.logs.length + (state.isFetchingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.logs.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final log = state.logs[index];
                      return _buildAuditCard(log);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(AuditTrailState state, AuditTrailController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Event Filter
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: state.eventFilter,
                  isExpanded: true,
                  hint: const Text('All Events'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Events')),
                    DropdownMenuItem(value: 'created', child: Text('Created Only')),
                    DropdownMenuItem(value: 'updated', child: Text('Updated Only')),
                    DropdownMenuItem(value: 'deleted', child: Text('Deleted Only')),
                  ],
                  onChanged: (val) => controller.setFilter(val),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Sort Button
          InkWell(
            onTap: () {
              final newSort = state.sortOrder == 'desc' ? 'asc' : 'desc';
              controller.setSortOrder(newSort);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    state.sortOrder == 'desc' ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text('Time', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditCard(dynamic log) {
    final event = log['event'].toString().toLowerCase();
    Color badgeColor = Colors.grey;
    IconData eventIcon = Icons.info_outline;

    switch (event) {
      case 'created':
        badgeColor = Colors.green;
        eventIcon = Icons.add_circle_outline;
        break;
      case 'updated':
        badgeColor = Colors.blue;
        eventIcon = Icons.edit_outlined;
        break;
      case 'deleted':
        badgeColor = Colors.red;
        eventIcon = Icons.delete_outline;
        break;
    }

    final List<dynamic> changes = log['changes'] ?? [];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: badgeColor.withOpacity(0.3), width: 1),
      ),
      color: Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(eventIcon, color: badgeColor, size: 24),
          ),
          title: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
              children: [
                TextSpan(text: log['user_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: ' ${event} a '),
                TextSpan(text: log['model'], style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' record.'),
              ],
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              log['created_at'],
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          children: [
            if (changes.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: changes.map((change) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              change.toString(),
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (changes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: Text('No detailed changes recorded.', style: TextStyle(color: Colors.grey.shade500, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }
}
