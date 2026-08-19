import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/shared/widgets/api_error_widget.dart';
import 'package:school_erp_staff_app/core/auth/app_permission.dart';
import 'package:school_erp_staff_app/core/auth/permission_service.dart';
import 'package:school_erp_staff_app/core/branding/branding_providers.dart';
import 'notice_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});

  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(noticeSearchQueryProvider.notifier).state = query;
  }

  @override
  Widget build(BuildContext context) {
    final noticeListState = ref.watch(noticeListProvider);
    final perms = ref.watch(permissionProvider);
    final canCreateNotices = perms.can(AppPermission.noticeCreate);
    final sortOrder = ref.watch(noticeSortOrderProvider);
    final filterType = ref.watch(noticeRecipientTypeFilterProvider);

    return MainScaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(noticeListProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search notices...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: Icon(sortOrder == 'desc' ? Icons.sort : Icons.sort_by_alpha),
                          tooltip: 'Toggle Sort Order',
                          onPressed: () {
                            ref.read(noticeSortOrderProvider.notifier).state = 
                                sortOrder == 'desc' ? 'asc' : 'desc';
                          },
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', 'all_types', filterType),
                          const SizedBox(width: 8),
                          _buildFilterChip('General', 'all', filterType),
                          const SizedBox(width: 8),
                          _buildFilterChip('Staff', 'staff', filterType),
                          const SizedBox(width: 8),
                          _buildFilterChip('Parents', 'parents', filterType),
                          const SizedBox(width: 8),
                          _buildFilterChip('${ref.watch(terminologyProvider).classLabel} Specific', 'class', filterType),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // List View
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80), // Padding for FAB
              sliver: noticeListState.when(
                loading: () => SkeletonLoaders.noticeCardSliver(),
                error: (err, stack) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: ApiErrorWidget(
                      error: err,
                      onRetry: () => ref.invalidate(noticeListProvider),
                    ),
                  ),
                ),
                data: (notices) {
                  if (notices.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: NoticeEmptyState(),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final notice = notices[index];
                        return NoticeCard(notice: notice);
                      },
                      childCount: notices.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: canCreateNotices ? FloatingActionButton(
        onPressed: () async {
          final result = await context.push('/notices/create');
          if (result == true) {
            ref.invalidate(noticeListProvider);
          }
        },
        elevation: 4,
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildFilterChip(String label, String value, String currentFilter) {
    final isSelected = currentFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        ref.read(noticeRecipientTypeFilterProvider.notifier).state = value;
      },
      backgroundColor: Colors.white,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
        ),
      ),
    );
  }
}

class NoticeCard extends ConsumerWidget {
  final dynamic notice;

  const NoticeCard({super.key, required this.notice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = DateTime.parse(notice['published_at']);
    final formattedDate = DateFormat('MMM dd, yyyy').format(date);
    
    // Determine audience chip styling
    String audienceLabel = 'General';
    Color audienceColor = Colors.blue.shade100;
    Color audienceTextColor = Colors.blue.shade800;
    IconData audienceIcon = Icons.public;

    if (notice['recipient_type'] == 'staff') {
      audienceLabel = 'Staff Only';
      audienceColor = Colors.purple.shade100;
      audienceTextColor = Colors.purple.shade800;
      audienceIcon = Icons.badge;
    } else if (notice['recipient_type'] == 'parents') {
      audienceLabel = 'Parents';
      audienceColor = Colors.orange.shade100;
      audienceTextColor = Colors.orange.shade800;
      audienceIcon = Icons.family_restroom;
    } else if (notice['recipient_type'] == 'class') {
      audienceLabel = notice['noticable'] != null ? notice['noticable']['name'] : ref.watch(terminologyProvider).classLabel;
      audienceColor = Colors.green.shade100;
      audienceTextColor = Colors.green.shade800;
      audienceIcon = Icons.class_;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/notices/detail', extra: notice),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Bar of the Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: audienceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(audienceIcon, size: 14, color: audienceTextColor),
                        const SizedBox(width: 4),
                        Text(
                          audienceLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: audienceTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),
            // Body of the Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // A clean, scannable summary — strip the HTML and show a
                  // short snippet; the full notice opens via "Read More".
                  Text(
                    _noticePreview(notice['content'] ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Read More',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 12, color: Theme.of(context).primaryColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoticeEmptyState extends StatelessWidget {
  const NoticeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60, bottom: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No notices found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no notices matching your current filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class NoticeSkeletonCard extends StatelessWidget {
  const NoticeSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSkeletonBox(width: 80, height: 24, radius: 12),
                _buildSkeletonBox(width: 100, height: 16, radius: 4),
              ],
            ),
            const SizedBox(height: 16),
            _buildSkeletonBox(width: 250, height: 24, radius: 4),
            const SizedBox(height: 12),
            _buildSkeletonBox(width: double.infinity, height: 14, radius: 4),
            const SizedBox(height: 6),
            _buildSkeletonBox(width: double.infinity, height: 14, radius: 4),
            const SizedBox(height: 6),
            _buildSkeletonBox(width: 150, height: 14, radius: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonBox({required double width, required double height, required double radius}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Turn a notice's HTML body into a clean one-line plain-text snippet for the
/// list preview (the full formatted notice still opens on the detail screen).
String _noticePreview(String html) {
  if (html.isEmpty) return '';
  final text = html
      .replaceAll(RegExp(r'<(br|/p|/div|/li|/h[1-6])\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), '') // strip remaining tags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text;
}