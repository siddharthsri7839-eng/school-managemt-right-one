import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import '../../../core/branding/branding_providers.dart';
import 'attendance_providers.dart';

class SelectSectionScreen extends ConsumerStatefulWidget {
  const SelectSectionScreen({super.key});

  @override
  ConsumerState<SelectSectionScreen> createState() => _SelectSectionScreenState();
}

class _SelectSectionScreenState extends ConsumerState<SelectSectionScreen> {
  dynamic _selectedClass;
  dynamic _selectedSection;
  List<dynamic> _sections = [];
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final classesState = ref.watch(classesProvider);
    return MainScaffold(
      title: 'Student Attendance',
      actions: [
        IconButton(
          icon: const Icon(Icons.assessment),
          tooltip: 'Attendance Reports',
          onPressed: () => context.go('/dashboard/attendance/reports'),
        ),
      ],
      body: SafeArea(
        child: classesState.when(
          loading: () => SkeletonLoaders.dashboard(),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (classes) {
            if (classes.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'You are not assigned to any ${ref.watch(terminologyProvider).classesLabel.toLowerCase()}. Please contact the school administrator to be assigned to a ${ref.watch(terminologyProvider).classLabel.toLowerCase()}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButtonFormField<dynamic>(
                    value: _selectedClass,
                    items: classes.map<DropdownMenuItem<dynamic>>((c) {
                      return DropdownMenuItem<dynamic>(value: c, child: Text(c['name']));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedClass = value;
                        _selectedSection = null;
                        _sections = value?['sections'] ?? [];
                      });
                    },
                    decoration: InputDecoration(labelText: 'Select ${ref.watch(terminologyProvider).classLabel}', border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  if (_selectedClass != null)
                    DropdownButtonFormField<dynamic>(
                      value: _selectedSection,
                      items: _sections.map<DropdownMenuItem<dynamic>>((s) {
                        return DropdownMenuItem<dynamic>(value: s, child: Text(s['name']));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSection = value;
                        });
                      },
                      decoration: InputDecoration(labelText: 'Select ${ref.watch(terminologyProvider).sectionLabel}', border: const OutlineInputBorder()),
                    ),
                  const SizedBox(height: 20),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Attendance Date'),
                    trailing: Text(DateFormat('dd MMM, yyyy').format(_selectedDate)),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(DateTime.now().year - 1), // Allow up to one year back
                        lastDate: DateTime.now(), // Do not allow future dates
                      );
                      if (pickedDate != null && pickedDate != _selectedDate) {
                        setState(() {
                          _selectedDate = pickedDate;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: _selectedSection != null
                        ? () {
                            final dateString = DateFormat('yyyy-MM-dd').format(_selectedDate);
                            context.go('/dashboard/attendance/take/${_selectedSection['id']}?date=$dateString');
                          }
                        : null,
                    child: const Text('Proceed'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.assessment),
                    label: const Text('View Attendance Reports'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    onPressed: () {
                      context.go('/dashboard/attendance/reports');
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}