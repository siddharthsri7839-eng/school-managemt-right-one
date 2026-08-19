import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:school_erp_staff_app/shared/utils/debouncer.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/core/branding/branding_providers.dart';
import 'student_search_controller.dart';
import 'student_dashboard_controller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StudentSearchScreen extends ConsumerStatefulWidget {
  const StudentSearchScreen({super.key});

  @override
  ConsumerState<StudentSearchScreen> createState() => _StudentSearchScreenState();
}

class _StudentSearchScreenState extends ConsumerState<StudentSearchScreen> {
  final _debouncer = Debouncer(milliseconds: 500);
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(studentSearchControllerProvider);
    // ✅ Correct way to get the ApiClient instance from the provider
    final apiClient = ref.watch(apiClientProvider);

    return MainScaffold(
      // The MainScaffold provides the AppBar and Drawer
      body: Column(
        children: [
          // This search bar is now a separate, clean widget
          _SearchBar(
            controller: _searchController,
            onChanged: (query) {
              _debouncer.run(() {
                ref.read(studentSearchControllerProvider.notifier).search(query);
              });
            },
          ),
          Expanded(
            child: searchState.when(
              data: (students) {
                // ✅ Show the Dashboard if query is empty
                if (_searchController.text.isEmpty) {
                  return const StudentAnalyticsDashboard();
                }
                if (students.isEmpty) {
                  return const Center(child: Text('No students found for this query.'));
                }
                // The existing ListView for results remains the same
                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final photoPath = student['photo_url'] ?? student['student_photo'];
                    String? photoUrl;
                    if (photoPath != null && photoPath.toString().isNotEmpty) {
                      if (photoPath.toString().startsWith('http')) {
                        photoUrl = photoPath.toString();
                      } else {
                        photoUrl = '${apiClient.storageBaseUrl}$photoPath';
                      }
                      final separator = photoUrl.contains('?') ? '&' : '?';
                      photoUrl = '$photoUrl${separator}t=${DateTime.now().millisecondsSinceEpoch}';
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? Text(student['full_name']?[0] ?? 'S')
                            : null,
                      ),
                      title: Text(student['full_name'] ?? 'No Name'),
                      subtitle: Text(
                          '${ref.read(terminologyProvider).classLabel}: ${student['class'] ?? 'N/A'} | Adm No: ${student['admission_no'] ?? 'N/A'}'),
                      onTap: () {
                        context.go('/dashboard/student-search/profile/${student['id']}');
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}


// A dedicated widget for the search input field
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search by name or admission no...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        ),
        onChanged: onChanged,
      ),
    );
  }
}


// ✅ THIS IS THE NEW ENHANCED WIDGET FOR THE INITIAL VIEW
class StudentAnalyticsDashboard extends ConsumerWidget {
  const StudentAnalyticsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studentDashboardControllerProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(state.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(studentDashboardControllerProvider.notifier).fetchDashboard(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = state.data;
    if (data == null) {
      return const Center(child: Text('No data available.'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(studentDashboardControllerProvider.notifier).fetchDashboard();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stat Cards
          Row(
            children: [
              Expanded(child: _StatCard(title: 'TOTAL STUDENTS', value: data['total_students'].toString(), icon: Icons.school, color: Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: 'NEW ADMISSIONS', value: data['new_admissions_this_month'].toString(), icon: Icons.person_add, color: Colors.teal)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(title: 'PRESENT TODAY', value: '${data['present_today']} / ${data['total_students']}', icon: Icons.check_circle, color: Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: 'BEHAVIOR RECORDS', value: data['behavior_this_month'].toString(), icon: Icons.warning, color: Colors.orange)),
            ],
          ),

          // Actionable prompt: students with no photo → worklist to fix them.
          if (((data['students_without_photo'] ?? 0) as int) > 0) ...[
            const SizedBox(height: 12),
            _PhotoMissingCard(count: data['students_without_photo'] as int),
          ],

          const SizedBox(height: 24),
          Text('Students by ${ref.watch(terminologyProvider).classLabel}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _ClassPieChart(data: List<Map<String, dynamic>>.from(data['class_breakdown'] ?? [])),
          
          const SizedBox(height: 24),
          const Text('Gender Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _GenderPieChart(data: List<Map<String, dynamic>>.from(data['gender_breakdown'] ?? [])),
          
          const SizedBox(height: 24),
          const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _RecentActivityList(activities: List<Map<String, dynamic>>.from(data['recent_activity'] ?? [])),

          const SizedBox(height: 24),
          const Text('Upcoming Birthdays', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _UpcomingBirthdaysList(birthdays: List<Map<String, dynamic>>.from(data['upcoming_birthdays'] ?? [])),
          const SizedBox(height: 80), // Padding for bottom
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _PhotoMissingCard extends StatelessWidget {
  final int count;
  const _PhotoMissingCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.deepPurple.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/dashboard/student-search/without-photo'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: Icon(Icons.no_photography_outlined, color: Colors.deepPurple.shade400),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$count ${count == 1 ? 'student needs' : 'students need'} a photo',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text('Tap to add photos', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _ClassPieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox(height: 100, child: Center(child: Text('No data')));
    
    final List<Color> colors = [Colors.blue, Colors.orange, Colors.teal, Colors.red, Colors.purple, Colors.green, Colors.indigo, Colors.pink, Colors.amber, Colors.cyan];

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: List.generate(data.length, (i) {
                  return PieChartSectionData(
                    color: colors[i % colors.length],
                    value: data[i]['total'].toDouble(),
                    title: '',
                    radius: 40,
                  );
                }),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, color: colors[i % colors.length]),
                      const SizedBox(width: 4),
                      Expanded(child: Text('${data[i]['label']}', style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GenderPieChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _GenderPieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox(height: 100, child: Center(child: Text('No data')));
    
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 0,
                sections: data.map((item) {
                  final isMale = item['label'].toString().toLowerCase() == 'male';
                  return PieChartSectionData(
                    color: isMale ? Colors.blue.shade400 : Colors.pink.shade300,
                    value: item['total'].toDouble(),
                    title: '${item['label']}\n${item['total']}',
                    radius: 80,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  const _RecentActivityList({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const Text('No recent activity.');
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final act = activities[i];
          final isAdmission = act['type'] == 'admission';
          final isPositive = act['behavior_type'] == 'positive';
          
          final icon = isAdmission 
              ? Icons.person_add 
              : (isPositive ? Icons.thumb_up : Icons.warning);
          final color = isAdmission 
              ? Colors.teal 
              : (isPositive ? Colors.green : Colors.red);

          return ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)),
            title: Text(act['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('${act['label']} • ${act['meta']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            trailing: Text(act['time_ago'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          );
        },
      ),
    );
  }
}

class _UpcomingBirthdaysList extends StatelessWidget {
  final List<Map<String, dynamic>> birthdays;
  const _UpcomingBirthdaysList({required this.birthdays});

  @override
  Widget build(BuildContext context) {
    if (birthdays.isEmpty) return const Text('No upcoming birthdays in 30 days.');
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: birthdays.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final bday = birthdays[i];
          return ListTile(
            leading: CircleAvatar(backgroundColor: Colors.pink.shade50, child: Icon(Icons.cake, color: Colors.pink.shade300, size: 20)),
            title: Text(bday['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(bday['meta'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            trailing: Text(bday['formatted_date'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.pink)),
          );
        },
      ),
    );
  }
}