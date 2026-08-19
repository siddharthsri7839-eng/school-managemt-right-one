import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/config/app_colors.dart';
import 'package:school_erp_staff_app/shared/widgets/api_error_widget.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import '../data/communication_log_model.dart';
import 'communication_log_providers.dart';
import 'widgets/communication_log_tile.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

/// Communication Log screen for admin roles.
///
/// Displays all system-generated notifications (SMS, WhatsApp, Email) with
/// channel filtering, search, paginated list, and tap-to-view message content.
class CommunicateScreen extends ConsumerStatefulWidget {
  const CommunicateScreen({super.key});

  @override
  ConsumerState<CommunicateScreen> createState() => _CommunicateScreenState();
}

class _CommunicateScreenState extends ConsumerState<CommunicateScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  /// Accumulated logs across all loaded pages.
  final List<CommunicationLogEntry> _allLogs = [];

  /// Whether the provider has been loaded at least once with page > 1 data.
  bool _isPaginationActive = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Reset to page 1 and clear accumulated logs on new search
      _allLogs.clear();
      _isPaginationActive = false;
      ref.read(communicationLogPageProvider.notifier).state = 1;
      ref.read(communicationLogSearchProvider.notifier).state = value.trim();
    });
  }

  void _onChannelChanged(String? channel) {
    // Reset to page 1 and clear accumulated logs on filter change
    _allLogs.clear();
    _isPaginationActive = false;
    ref.read(communicationLogPageProvider.notifier).state = 1;
    ref.read(communicationLogChannelFilterProvider.notifier).state = channel;
  }

  void _loadNextPage(CommunicationLogResponse currentResponse) {
    if (!currentResponse.hasMorePages) return;
    _isPaginationActive = true;
    ref.read(communicationLogPageProvider.notifier).state = currentResponse.currentPage + 1;
  }

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(communicationLogProvider);
    final activeChannel = ref.watch(communicationLogChannelFilterProvider);

    return MainScaffold(
      body: Column(
        children: [
          // ── Header ──
          _buildHeader(context),

          // ── Channel Filter Chips ──
          _buildChannelFilters(activeChannel),

          // ── Search Bar ──
          _buildSearchBar(),

          // ── Log List ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _allLogs.clear();
                _isPaginationActive = false;
                ref.read(communicationLogPageProvider.notifier).state = 1;
                ref.invalidate(communicationLogProvider);
                // Wait for the provider to reload
                await ref.read(communicationLogProvider.future);
              },
              child: logState.when(
                loading: () => SkeletonLoaders.communicationLog(),
                error: (err, stack) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: ApiErrorWidget(
                      error: err,
                      onRetry: () {
                        _allLogs.clear();
                        _isPaginationActive = false;
                        ref.read(communicationLogPageProvider.notifier).state = 1;
                        ref.invalidate(communicationLogProvider);
                      },
                    ),
                  ),
                ),
                data: (response) {
                  // Merge new page data into accumulated list
                  if (response.logs.isNotEmpty) {
                    if (_isPaginationActive) {
                      // Avoid duplicates when data refreshes
                      final existingIds = _allLogs.map((e) => e.id).toSet();
                      for (final log in response.logs) {
                        if (!existingIds.contains(log.id)) {
                          _allLogs.add(log);
                        }
                      }
                    } else {
                      _allLogs
                        ..clear()
                        ..addAll(response.logs);
                    }
                  } else if (!_isPaginationActive) {
                    _allLogs.clear();
                  }

                  if (_allLogs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildLogList(response);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Communication Log',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'All system-generated notifications',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelFilters(String? activeChannel) {
    const channels = [
      (value: null, label: 'All', icon: Icons.all_inclusive),
      (value: 'sms', label: 'SMS', icon: Icons.sms_outlined),
      (value: 'whatsapp', label: 'WhatsApp', icon: Icons.chat_outlined),
      (value: 'mail', label: 'Email', icon: Icons.email_outlined),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: channels.map((ch) {
          final isActive = activeChannel == ch.value;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onChannelChanged(ch.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      ch.icon,
                      size: 14,
                      color: isActive ? Colors.white : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        ch.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : Colors.grey.shade700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by recipient, email, or subject...',
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildLogList(CommunicationLogResponse response) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: _allLogs.length + (response.hasMorePages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < _allLogs.length) {
          return CommunicationLogTile(entry: _allLogs[index]);
        }

        // "Load More" button at the bottom
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
          child: OutlinedButton.icon(
            onPressed: () => _loadNextPage(response),
            icon: const Icon(Icons.expand_more, size: 18),
            label: Text(
              'Load More (${response.currentPage}/${response.lastPage})',
              style: const TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Communication Logs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'System-generated notifications will\nappear here once they are sent.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}