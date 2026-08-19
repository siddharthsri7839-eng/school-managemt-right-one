import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import 'classwork_providers.dart';

class ClassworkListScreen extends ConsumerStatefulWidget {
  const ClassworkListScreen({super.key});

  @override
  ConsumerState<ClassworkListScreen> createState() => _ClassworkListScreenState();
}

class _ClassworkListScreenState extends ConsumerState<ClassworkListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _filterType = 'All'; // 'All', 'Classwork', 'Logbook', 'Notes'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classworkState = ref.watch(classworkListProvider);
    final theme = Theme.of(context);

    return MainScaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(classworkListProvider.future),
        child: Column(
          children: [
            _buildControlBar(theme),
            Expanded(
              child: classworkState.when(
                loading: () => SkeletonLoaders.cardList(),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (classworks) {
                  var filteredList = classworks.where((cw) {
                    final titleMatch = cw['topic'].toString().toLowerCase().contains(_searchController.text.toLowerCase());
                    final subjectMatch = cw['subject'] != null 
                        ? cw['subject']['name'].toString().toLowerCase().contains(_searchController.text.toLowerCase())
                        : false;
                    final searchMatch = titleMatch || subjectMatch;

                    bool filterMatch = true;
                    if (_filterType != 'All') {
                      filterMatch = cw['type'].toString().toLowerCase() == _filterType.toLowerCase();
                    }

                    return searchMatch && filterMatch;
                  }).toList();

                  if (filteredList.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(child: Text('No entries found matching criteria.')),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      return _buildClassworkCard(filteredList[index], theme);
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
          await context.push('/dashboard/classwork/create');
          ref.invalidate(classworkListProvider);
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
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by topic or subject...',
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Classwork', 'Logbook', 'Notes'].map((type) {
                final isSelected = _filterType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) setState(() => _filterType = type);
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
        ],
      ),
    );
  }

  Widget _buildClassworkCard(Map<String, dynamic> cw, ThemeData theme) {
    final date = DateTime.parse(cw['date']);
    final type = cw['type'].toString().toLowerCase();
    
    Color typeColor;
    IconData typeIcon;
    if (type == 'logbook') {
      typeColor = Colors.orange;
      typeIcon = Icons.book;
    } else if (type == 'notes') {
      typeColor = Colors.purple;
      typeIcon = Icons.note_alt;
    } else {
      typeColor = Colors.green;
      typeIcon = Icons.assignment;
    }

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
          onTap: () async {
            await context.push('/dashboard/classwork/details', extra: cw);
            ref.invalidate(classworkListProvider);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cw['topic'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (cw['subject'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              cw['subject']['name'],
                              style: TextStyle(color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: typeColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        cw['type'].toString().toUpperCase(),
                        style: TextStyle(
                          color: typeColor,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${cw['school_class']['name']} - ${cw['section']['name']}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM, yyyy').format(date),
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
