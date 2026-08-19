import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:intl/intl.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import 'leave_providers.dart';

class AdminLeaveApprovalScreen extends ConsumerStatefulWidget {
  const AdminLeaveApprovalScreen({super.key});

  @override
  ConsumerState<AdminLeaveApprovalScreen> createState() => _AdminLeaveApprovalScreenState();
}

class _AdminLeaveApprovalScreenState extends ConsumerState<AdminLeaveApprovalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Statuses this screen has successfully changed, keyed by request id.
  ///
  /// The server is the source of truth, but the refetch that follows an
  /// approval was not reliably moving the card between tabs. Recording the
  /// confirmed new status here means the card moves the instant the API call
  /// succeeds, regardless of how the refetch behaves. Entries are dropped once
  /// the server sends back the same status, so this can never mask real data.
  final Map<int, String> _confirmedStatuses = {};

  /// The status to file a request under: our confirmed change if we have one,
  /// otherwise whatever the server said.
  String _statusOf(dynamic request) {
    final serverStatus = (request['status'] as String?) ?? 'pending';
    final id = request['id'];
    if (id is! int) return serverStatus;

    final confirmed = _confirmedStatuses[id];
    if (confirmed == null) return serverStatus;

    // Server has caught up — stop overriding.
    if (confirmed == serverStatus) {
      _confirmedStatuses.remove(id);
      return serverStatus;
    }
    return confirmed;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(int leaveId, String status) async {
    String? remarks;
    
    if (status == 'rejected') {
      final remarksController = TextEditingController();
      final bool? confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject Leave'),
          content: TextField(
            controller: remarksController,
            decoration: const InputDecoration(
              labelText: 'Remarks (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Reject'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
      remarks = remarksController.text;
    }

    try {
      await ref.read(leaveRepositoryProvider).updateLeaveStatus(
        leaveId: leaveId,
        status: status,
        remarks: remarks,
      );

      // The API returned 200, so this change is real — record it and rebuild
      // straight away. The card moves now rather than waiting on the refetch.
      if (mounted) {
        setState(() => _confirmedStatuses[leaveId] = status);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Leave request $status successfully'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          )
        );
      }

      // Reconcile with the server. If this fails the card has already moved,
      // and the override clears itself once the server agrees.
      ref.invalidate(allLeaveRequestsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiException.from(e).message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveRequestsAsync = ref.watch(allLeaveRequestsProvider);

    return MainScaffold(
      title: 'Staff Leave Approval',
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blue.shade800,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue.shade800,
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Approved'),
                Tab(text: 'Rejected'),
              ],
            ),
          ),
          Expanded(
            child: leaveRequestsAsync.when(
              loading: () => SkeletonLoaders.cardList(),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(ApiException.from(err).message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(allLeaveRequestsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (requests) {
                final pending = requests.where((r) => _statusOf(r) == 'pending').toList();
                final approved = requests.where((r) => _statusOf(r) == 'approved').toList();
                final rejected = requests.where((r) => _statusOf(r) == 'rejected').toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(pending, true),
                    _buildList(approved, false),
                    _buildList(rejected, false),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<dynamic> requests, bool isPending) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.beach_access, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No Leave Requests',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                'There are no ${isPending ? 'pending' : 'leave'} requests in this category.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Must await, or the spinner disappears before the new data lands.
        ref.invalidate(allLeaveRequestsProvider);
        await ref.read(allLeaveRequestsProvider.future);
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final req = requests[index];
          
          final staffName =
              (req['staff']?['user']?['name'] as String?) ?? 'Unknown Staff';
          final staffIdCard = (req['staff']?['staff_id_card'] as String?) ?? '';
          final leaveType = (req['leave_type']?['name'] as String?) ?? 'Leave';
          final reason = (req['reason'] as String?) ?? 'No reason given';

          final startDate = _parseDate(req['start_date']);
          final endDate = _parseDate(req['end_date']);
          // The API has no `apply_date` — the row's created_at is when it was
          // applied for. Parsing the missing key is what crashed this screen.
          final applyDate = _parseDate(req['created_at']);

          // `requested_days` is frequently null on real rows, so fall back to
          // the inclusive span of the leave rather than showing "1 Day(s)".
          // It is a decimal:2 cast, so when set it arrives as "2.00" — trim it
          // so half-days still read "0.5" but whole days read "2", not "2.00".
          final days = _formatDays(req['requested_days']) ??
              (startDate != null && endDate != null
                  ? '${endDate.difference(startDate).inDays + 1}'
                  : '1');

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staffName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (staffIdCard.isNotEmpty)
                                Text(
                                  staffIdCard,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            leaveType,
                            style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildDateColumn('From', startDate),
                        _buildDateColumn('To', endDate),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Duration', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('$days Day(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Reason: $reason',
                      style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                    ),
                    if (applyDate != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Applied On: ${DateFormat('d MMM yyyy').format(applyDate)}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                    if (isPending) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _updateStatus(req['id'], 'rejected'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _updateStatus(req['id'], 'approved'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Renders a decimal day count without trailing zeros, or null when the
  /// backend did not supply one.
  String? _formatDays(dynamic value) {
    if (value == null) return null;
    final n = value is num ? value : num.tryParse(value.toString());
    if (n == null) return null;
    return n == n.roundToDouble() ? '${n.toInt()}' : '$n';
  }

  /// Tolerant date parse — the API omits some date keys entirely and returns
  /// null for others, and a hard `DateTime.parse` on those takes down the whole
  /// screen rather than one card.
  DateTime? _parseDate(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  Widget _buildDateColumn(String label, DateTime? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          date == null ? '—' : DateFormat('d MMM, yyyy').format(date),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
