import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/storage/sqlite_providers.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';

class DemoDatabaseScreen extends ConsumerStatefulWidget {
  const DemoDatabaseScreen({super.key});

  @override
  ConsumerState<DemoDatabaseScreen> createState() => _DemoDatabaseScreenState();
}

class _DemoDatabaseScreenState extends ConsumerState<DemoDatabaseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(sqliteSummaryProvider);
    ref.invalidate(sqliteStudentsProvider);
    ref.invalidate(sqliteStaffProvider);
    ref.invalidate(sqliteNoticesProvider);
    ref.invalidate(sqliteAttendanceProvider);
  }

  Future<void> _showAddStudentDialog() async {
    final nameController = TextEditingController();
    final rollController = TextEditingController(text: '${100 + DateTime.now().second}');
    final classController = TextEditingController(text: 'Class 10');
    final sectionController = TextEditingController(text: 'A');
    final phoneController = TextEditingController(text: '+91 98000 11223');

    final bool? created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Add Student to SQLite'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rollController,
                decoration: const InputDecoration(labelText: 'Roll Number', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: classController,
                      decoration: const InputDecoration(labelText: 'Class', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: sectionController,
                      decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Parent Phone', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final db = ref.read(sqliteServiceProvider);
              await db.addStudent({
                'name': nameController.text.trim(),
                'roll_number': rollController.text.trim(),
                'class_name': classController.text.trim(),
                'section': sectionController.text.trim(),
                'parent_phone': phoneController.text.trim(),
                'gender': 'Male',
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            child: const Text('Save to SQLite'),
          ),
        ],
      ),
    );

    if (created == true) {
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ New student record saved into SQLite database!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _showAddNoticeDialog() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');

    final bool? created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.campaign, color: Colors.orange),
            SizedBox(width: 8),
            Text('Add Notice to SQLite'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Notice Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notice Content', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              final db = ref.read(sqliteServiceProvider);
              await db.addNotice({
                'title': titleController.text.trim(),
                'content': contentController.text.trim(),
                'category': categoryController.text.trim(),
                'author': 'Staff Admin',
                'created_at': DateTime.now().toString().split('.')[0],
              });
              if (context.mounted) Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Save Notice'),
          ),
        ],
      ),
    );

    if (created == true) {
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Notice saved into SQLite database!'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _resetDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset SQLite Database?'),
        content: const Text('This will re-create all demo tables and re-populate fresh initial seed records.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reset DB'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final db = ref.read(sqliteServiceProvider);
      await db.resetAndSeedDatabase();
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚡ SQLite Database re-created & re-seeded successfully!'), backgroundColor: Colors.blue),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(sqliteSummaryProvider);
    final studentsAsync = ref.watch(sqliteStudentsProvider);
    final staffAsync = ref.watch(sqliteStaffProvider);
    final noticesAsync = ref.watch(sqliteNoticesProvider);
    final attendanceAsync = ref.watch(sqliteAttendanceProvider);

    return MainScaffold(
      title: 'SQLite Demo Database',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh Database',
          onPressed: _refreshAll,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'reset') _resetDatabase();
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  Icon(Icons.restart_alt, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Reset SQLite DB'),
                ],
              ),
            ),
          ],
        ),
      ],
      body: Column(
        children: [
          // 1. Connection Header Banner
          summaryAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, stack) => Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(12),
              child: Text('SQLite Connection Error: $err', style: const TextStyle(color: Colors.red)),
            ),
            data: (summary) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade800, Colors.indigo.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.storage, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary['db_name'] ?? 'SQLite Local DB',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('Connected (SQLite Engine)', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          'Records: ${summary['total_records']}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Path: ${summary['db_path']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),

          // 2. Tab Navigation
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.indigo,
              tabs: const [
                Tab(icon: Icon(Icons.people), text: 'Students'),
                Tab(icon: Icon(Icons.campaign), text: 'Notices'),
                Tab(icon: Icon(Icons.badge), text: 'Staff'),
                Tab(icon: Icon(Icons.check_circle_outline), text: 'Attendance'),
              ],
            ),
          ),

          // 3. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: STUDENTS
                _buildStudentsTab(studentsAsync),

                // TAB 2: NOTICES
                _buildNoticesTab(noticesAsync),

                // TAB 3: STAFF
                _buildStaffTab(staffAsync),

                // TAB 4: ATTENDANCE LOGS
                _buildAttendanceTab(attendanceAsync),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 1) {
            _showAddNoticeDialog();
          } else {
            _showAddStudentDialog();
          }
        },
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Entry', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildStudentsTab(AsyncValue<List<Map<String, dynamic>>> asyncVal) {
    return asyncVal.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading students: $err')),
      data: (students) {
        if (students.isEmpty) {
          return const Center(child: Text('No students in SQLite table.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final s = students[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: Text(s['id'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                ),
                title: Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Roll No: ${s['roll_number']} | Class: ${s['class_name']}-${s['section']} | Phone: ${s['parent_phone'] ?? 'N/A'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final db = ref.read(sqliteServiceProvider);
                    await db.deleteStudent(s['id']);
                    _refreshAll();
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNoticesTab(AsyncValue<List<Map<String, dynamic>>> asyncVal) {
    return asyncVal.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading notices: $err')),
      data: (notices) {
        if (notices.isEmpty) {
          return const Center(child: Text('No notices in SQLite table.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: notices.length,
          itemBuilder: (context, index) {
            final n = notices[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(12)),
                          child: Text(n['category'] ?? 'Notice', style: TextStyle(color: Colors.orange.shade900, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(n['content'] ?? '', style: const TextStyle(color: Colors.black87)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Author: ${n['author']} • ${n['created_at']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () async {
                            final db = ref.read(sqliteServiceProvider);
                            await db.deleteNotice(n['id']);
                            _refreshAll();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStaffTab(AsyncValue<List<Map<String, dynamic>>> asyncVal) {
    return asyncVal.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading staff: $err')),
      data: (staff) {
        if (staff.isEmpty) return const Center(child: Text('No staff in SQLite table.'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: staff.length,
          itemBuilder: (context, index) {
            final st = staff[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: const Icon(Icons.badge, color: Colors.teal),
                ),
                title: Text(st['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Role: ${st['role']} | Dept: ${st['department']}\nEmail: ${st['email']}'),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceTab(AsyncValue<List<Map<String, dynamic>>> asyncVal) {
    return asyncVal.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading attendance: $err')),
      data: (attendance) {
        if (attendance.isEmpty) return const Center(child: Text('No attendance logs in SQLite table.'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: attendance.length,
          itemBuilder: (context, index) {
            final att = attendance[index];
            final isPresent = att['status'] == 'Present';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPresent ? Colors.green.shade100 : Colors.red.shade100,
                  child: Icon(isPresent ? Icons.check : Icons.close, color: isPresent ? Colors.green : Colors.red),
                ),
                title: Text(att['student_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Class: ${att['class_section']} | Time: ${att['date_time']}'),
                trailing: Chip(
                  label: Text(att['status'] ?? ''),
                  backgroundColor: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                  labelStyle: TextStyle(color: isPresent ? Colors.green.shade900 : Colors.red.shade900, fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
