import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import 'homework_providers.dart';

class HomeworkListScreen extends ConsumerStatefulWidget {
  const HomeworkListScreen({super.key});

  @override
  ConsumerState<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends ConsumerState<HomeworkListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'All'; // 'All', 'Active', 'Overdue', 'Pending Eval'
  String _sortMode = 'due_desc';

  // label shown on the sort button for each mode
  static const Map<String, String> _sortLabels = {
    'due_desc': 'Newest',
    'due_asc': 'Oldest',
    'sub_desc': 'Most submitted',
    'sub_asc': 'Least submitted',
    'title_asc': 'Title A–Z',
  };

  int _submitted(Map h) => (h['submissions_count'] as int?) ?? 0;
  int _evaluated(Map h) => (h['evaluated_count'] as int?) ?? 0;
  int _total(Map h) => (h['students_count'] as int?) ?? 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeworkState = ref.watch(homeworkListProvider);
    final theme = Theme.of(context);

    return MainScaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeworkListProvider.future),
        child: Column(
          children: [
            // TOP CONTROL BAR
            _buildControlBar(theme),
            
            // HOMEWORK LIST
            Expanded(
              child: homeworkState.when(
                loading: () => SkeletonLoaders.cardList(),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (homeworks) {
                  // Apply Search & Filter
                  var filteredList = homeworks.where((hw) {
                    final titleMatch = hw['title'].toString().toLowerCase().contains(_searchController.text.toLowerCase());
                    final subjectMatch = hw['subject']['name'].toString().toLowerCase().contains(_searchController.text.toLowerCase());
                    final searchMatch = titleMatch || subjectMatch;

                    final dueDate = DateTime.parse(hw['due_date']);
                    final isOverdue = dueDate.isBefore(DateTime.now());
                    final hasUngraded = _submitted(hw) > _evaluated(hw);

                    bool filterMatch = true;
                    if (_filterStatus == 'Active') filterMatch = !isOverdue;
                    if (_filterStatus == 'Overdue') filterMatch = isOverdue;
                    if (_filterStatus == 'Pending Eval') filterMatch = hasUngraded;

                    return searchMatch && filterMatch;
                  }).toList();

                  // Apply Sort
                  filteredList.sort((a, b) {
                    switch (_sortMode) {
                      case 'due_asc':
                        return DateTime.parse(a['due_date'])
                            .compareTo(DateTime.parse(b['due_date']));
                      case 'sub_desc':
                        return _submitted(b).compareTo(_submitted(a));
                      case 'sub_asc':
                        return _submitted(a).compareTo(_submitted(b));
                      case 'title_asc':
                        return a['title']
                            .toString()
                            .toLowerCase()
                            .compareTo(b['title'].toString().toLowerCase());
                      case 'due_desc':
                      default:
                        return DateTime.parse(b['due_date'])
                            .compareTo(DateTime.parse(a['due_date']));
                    }
                  });

                  if (filteredList.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(child: Text('No homework assignments found matching criteria.')),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      return _buildHomeworkCard(filteredList[index], theme);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.primaryColor,
        onPressed: () async {
          await context.push('/dashboard/homework/create');
          ref.invalidate(homeworkListProvider);
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildControlBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by title or subject...',
              prefixIcon: Icon(Icons.search, color: theme.primaryColor),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter & Sort Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Filter Chips
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Active', 'Overdue', 'Pending Eval'].map((status) {
                      final isSelected = _filterStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _filterStatus = status);
                          },
                          selectedColor: theme.primaryColor.withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: isSelected ? theme.primaryColor : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Sort Menu
              PopupMenuButton<String>(
                initialValue: _sortMode,
                onSelected: (value) => setState(() => _sortMode = value),
                tooltip: 'Sort',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                itemBuilder: (context) => _sortLabels.entries
                    .map((e) => PopupMenuItem<String>(
                          value: e.key,
                          child: Row(
                            children: [
                              Icon(
                                _sortMode == e.key
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: theme.primaryColor,
                              ),
                              const SizedBox(width: 10),
                              Text(e.value),
                            ],
                          ),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sort, size: 16, color: theme.primaryColor),
                      const SizedBox(width: 4),
                      Text(
                        _sortLabels[_sortMode] ?? 'Sort',
                        style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Icon(Icons.arrow_drop_down, size: 18, color: theme.primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> homework, ThemeData theme) {
    final dueDate = DateTime.parse(homework['due_date']);
    final isOverdue = dueDate.isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/dashboard/homework/details/${homework['id']}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Subject Icon + Title + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.menu_book, color: theme.primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    // Title & Subject
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            homework['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            homework['subject']['name'],
                            style: TextStyle(color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOverdue ? Colors.red.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isOverdue ? Colors.red.shade200 : Colors.green.shade200),
                      ),
                      child: Text(
                        isOverdue ? 'Overdue' : 'Active',
                        style: TextStyle(
                          color: isOverdue ? Colors.red.shade700 : Colors.green.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                // Footer Row: Class details + Due Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Class & Section
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${homework['school_class']['name']} - ${homework['section']['name']}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                    ),
                    // Due Date
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: isOverdue ? Colors.red.shade600 : Colors.orange.shade800),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM, yyyy').format(dueDate),
                          style: TextStyle(
                            color: isOverdue ? Colors.red.shade700 : Colors.orange.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _buildSubmissionProgress(homework, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Submission progress strip: "X / Y submitted • Z graded" + a thin bar.
  /// Colour shifts green as more of the class submits.
  Widget _buildSubmissionProgress(Map<String, dynamic> homework, ThemeData theme) {
    // Older API builds don't send submission counts — hide the strip entirely
    // rather than show a misleading "0 submitted" on every card.
    if (homework['submissions_count'] == null) return const SizedBox.shrink();

    final submitted = _submitted(homework);
    final evaluated = _evaluated(homework);
    final total = _total(homework);
    final ratio = total > 0 ? (submitted / total).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).round();

    final Color barColor = submitted == 0
        ? Colors.grey.shade400
        : (ratio >= 1.0
            ? Colors.green.shade600
            : (ratio >= 0.5 ? Colors.teal.shade500 : Colors.orange.shade600));

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined,
                  size: 15, color: barColor),
              const SizedBox(width: 5),
              Text(
                total > 0 ? '$submitted / $total submitted' : '$submitted submitted',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: 6),
                Text('($percent%)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
              const Spacer(),
              if (evaluated > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$evaluated graded',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? ratio : 0,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}