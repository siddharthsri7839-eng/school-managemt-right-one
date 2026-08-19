import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/features/timetable/presentation/timetable_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import '../../../core/branding/branding_providers.dart';

class TimetableScreen extends ConsumerWidget {
  const TimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetableAsync = ref.watch(timetableProvider);
    // Resolved here (not inside the lazy itemBuilder) — ref.watch is only
    // legal during build; the closure below captures the value.
    final terms = ref.watch(terminologyProvider);
    const dayOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return MainScaffold(
      title: 'My Timetable',
      body: timetableAsync.when(
        loading: () => SkeletonLoaders.listTile(),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (timetable) {
          if (timetable.isEmpty) {
            return const Center(child: Text('No timetable has been assigned to you.'));
          }

          final availableDays = dayOrder.where((day) => timetable.containsKey(day)).toList();
          
          final currentDayName = dayOrder[DateTime.now().weekday - 1];
          var initialIndex = availableDays.indexOf(currentDayName);
          if (initialIndex == -1) {
            initialIndex = 0;
          }

          return Container(
            color: Colors.grey.shade50,
            child: DefaultTabController(
              length: availableDays.length,
              initialIndex: initialIndex,
              child: Column(
                children: [
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      isScrollable: true,
                      labelColor: Theme.of(context).primaryColor,
                      unselectedLabelColor: Colors.grey.shade500,
                      indicatorColor: Theme.of(context).primaryColor,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      tabs: availableDays.map((day) => Tab(text: day)).toList(),
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: availableDays.map((day) {
                        final periods = timetable[day]!;
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          itemCount: periods.length,
                          itemBuilder: (context, index) {
                            final period = periods[index];
                            final isLast = index == periods.length - 1;
                            
                            // Generate a consistent color based on subject name
                            final colors = [Colors.blue, Colors.purple, Colors.orange, Colors.teal, Colors.indigo, Colors.red];
                            final colorIndex = period.subject.length % colors.length;
                            final accentColor = colors[colorIndex];

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Timeline Column
                                  SizedBox(
                                    width: 60,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: accentColor.shade50,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: accentColor.shade100),
                                          ),
                                          child: Text(
                                            period.startTime.split(' ')[0], // e.g. 10:00
                                            style: TextStyle(fontWeight: FontWeight.bold, color: accentColor.shade700, fontSize: 12),
                                          ),
                                        ),
                                        if (!isLast)
                                          Expanded(
                                            child: Container(
                                              width: 2,
                                              margin: const EdgeInsets.symmetric(vertical: 4),
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Card Column
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 20.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.grey.shade200),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.03),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border(left: BorderSide(color: accentColor, width: 4)),
                                            ),
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        period.subject,
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: accentColor.shade50,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(Icons.class_, size: 16, color: accentColor),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${period.startTime} - ${period.endTime}',
                                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(Icons.groups, size: 14, color: Colors.grey.shade500),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${terms.classLabel} ${period.className} • ${terms.sectionLabel} ${period.sectionName}',
                                                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}