// lib/features/hr/presentation/mark_staff_attendance_screen.dart

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/shared/widgets/api_error_widget.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import 'package:intl/intl.dart';

class AttendanceItem {
  final String staffId;
  final String employeeCode;
  final String name;
  final String designation;
  final String? photoUrl;
  String status;
  String remarks;
  final bool hasPunch;

  AttendanceItem({
    required this.staffId,
    required this.employeeCode,
    required this.name,
    required this.designation,
    this.photoUrl,
    this.status = 'Not Marked',
    this.remarks = '',
    this.hasPunch = false,
  });

  factory AttendanceItem.fromJson(Map<String, dynamic> json) {
    return AttendanceItem(
      staffId: json['id'].toString(),
      employeeCode: json['employee_code'] ?? json['staff_id_card'] ?? 'EMP-${json['id']}',
      name: json['name'] ?? 'Unknown',
      designation: json['designation'] ?? 'Staff',
      photoUrl: json['photo_url'],
      status: json['status'] ?? 'Not Marked',
      remarks: json['remarks'] ?? '',
      hasPunch: json['has_punch'] ?? false,
    );
  }
}

class StaffAttendanceState {
  final List<AttendanceItem> allStaff;
  final List<AttendanceItem> filteredStaff;
  final DateTime selectedDate;
  final bool isLoading;
  final bool isSaving;
  final String searchQuery;
  final String? errorMessage;

  StaffAttendanceState({
    this.allStaff = const [],
    this.filteredStaff = const [],
    required this.selectedDate,
    this.isLoading = false,
    this.isSaving = false,
    this.searchQuery = '',
    this.errorMessage,
  });

  StaffAttendanceState copyWith({
    List<AttendanceItem>? allStaff,
    List<AttendanceItem>? filteredStaff,
    DateTime? selectedDate,
    bool? isLoading,
    bool? isSaving,
    String? searchQuery,
    String? errorMessage,
  }) {
    return StaffAttendanceState(
      allStaff: allStaff ?? this.allStaff,
      filteredStaff: filteredStaff ?? this.filteredStaff,
      selectedDate: selectedDate ?? this.selectedDate,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage, // We don't want to carry over error messages unless specified
    );
  }
}

class StaffAttendanceController extends StateNotifier<StaffAttendanceState> {
  StaffAttendanceController() : super(StaffAttendanceState(selectedDate: DateTime.now())) {
    fetchStaff();
  }

  Future<void> fetchStaff() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dio = ApiClient().dio;
      final dateStr = DateFormat('yyyy-MM-dd').format(state.selectedDate);
      
      final response = await dio.get('/staff/hr/staff-attendance', queryParameters: {
        'date': dateStr,
      });

      final List<dynamic> rawData = response.data['data'] ?? [];
      final staff = rawData.map((e) => AttendanceItem.fromJson(e)).toList();

      state = state.copyWith(
        allStaff: staff,
        filteredStaff: _filterStaff(staff, state.searchQuery),
        isLoading: false,
      );
    } catch (e) {
      final message = ApiException.from(e).message;
      state = state.copyWith(isLoading: false, errorMessage: message);
    }
  }

  void onSearchChanged(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredStaff: _filterStaff(state.allStaff, query),
    );
  }

  void onStatusChanged(String staffId, String status) {
    final updatedAll = state.allStaff.map((s) {
      if (s.staffId == staffId) s.status = status;
      return s;
    }).toList();

    state = state.copyWith(
      allStaff: updatedAll,
      filteredStaff: _filterStaff(updatedAll, state.searchQuery),
    );
  }

  void onDateChanged(DateTime date) {
    state = state.copyWith(selectedDate: date, allStaff: [], filteredStaff: []);
    fetchStaff();
  }

  List<AttendanceItem> _filterStaff(List<AttendanceItem> staff, String query) {
    if (query.isEmpty) return staff;
    return staff.where((s) => s.name.toLowerCase().contains(query.toLowerCase())).toList();
  }

  Future<void> saveAttendance(BuildContext context) async {
    state = state.copyWith(isSaving: true);
    try {
      final dio = ApiClient().dio;
      
      final attendances = state.allStaff
          .where((s) => s.status != 'Not Marked' && !s.hasPunch)
          .map((s) => {
                'staff_id': s.staffId,
                'status': s.status,
                'remarks': s.remarks,
              })
          .toList();

      if (attendances.isEmpty) {
        throw const ApiException(message: 'No new attendance records to submit.');
      }

      final payload = {
        'date': DateFormat('yyyy-MM-dd').format(state.selectedDate),
        'attendances': attendances,
      };

      await dio.post('/staff/hr/staff-attendance', data: payload);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully'), backgroundColor: Colors.green),
      );
      fetchStaff(); // Refresh to remove submitted records
    } catch (e) {
      final message = e is ApiException ? e.message : (e is DioException ? ApiException.fromDioException(e).message : 'Failed to save attendance');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final staffAttendanceProvider = StateNotifierProvider<StaffAttendanceController, StaffAttendanceState>((ref) {
  return StaffAttendanceController();
});

class MarkStaffAttendanceScreen extends ConsumerWidget {
  const MarkStaffAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(staffAttendanceProvider);
    final controller = ref.read(staffAttendanceProvider.notifier);

    return MainScaffold(
      title: 'Staff Attendance',
      actions: [
        IconButton(
          onPressed: () => _selectDate(context, ref),
          icon: const Icon(Icons.calendar_today),
        ),
      ],
      body: Column(
        children: [
          // 1. Date & Search Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.event, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy').format(state.selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: controller.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search staff by name...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                ),
              ],
            ),
          ),

          // 2. Main Content
          Expanded(
            child: _buildBody(state, controller),
          ),
          
          // 3. Save Button (Only show if no errors and staff list is not empty)
          if (state.errorMessage == null && state.allStaff.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    )
                  ),
                  onPressed: state.isSaving ? null : () => controller.saveAttendance(context),
                  child: state.isSaving
                      ? const SizedBox(
                          width: 24, height: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text('Save Attendance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildBody(StaffAttendanceState state, StaffAttendanceController controller) {
    if (state.isLoading && state.allStaff.isEmpty) {
      return SkeletonLoaders.listTile();
    }
    
    if (state.errorMessage != null) {
      return ApiErrorWidget(
        error: ApiException.server(state.errorMessage!),
        onRetry: () => controller.fetchStaff(),
      );
    }
    
    if (state.filteredStaff.isEmpty) {
      return const Center(child: Text('No staff found'));
    }
    
    return ListView.separated(
      padding: const EdgeInsets.all(16).copyWith(bottom: 80),
      itemCount: state.filteredStaff.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final staff = state.filteredStaff[index];
        return _StaffAttendanceCard(staff: staff);
      },
    );
  }

  Future<void> _selectDate(BuildContext context, WidgetRef ref) async {
    final current = ref.read(staffAttendanceProvider).selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(staffAttendanceProvider.notifier).onDateChanged(picked);
    }
  }
}

class _StaffAttendanceCard extends ConsumerWidget {
  final AttendanceItem staff;
  const _StaffAttendanceCard({required this.staff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-use logic from StudentAttendanceTile to color Segments based on selection
    Color getStatusColor(String status) {
      switch (status.toLowerCase()) {
        case 'present': return Colors.green.shade600;
        case 'absent': return Colors.red.shade600;
        case 'late': return Colors.orange.shade600;
        case 'half day': return Colors.blue.shade600;
        default: return Colors.grey.shade600;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blue.shade50,
                backgroundImage: staff.photoUrl != null ? NetworkImage(staff.photoUrl!) : null,
                child: staff.photoUrl == null ? const Icon(Icons.person, color: Colors.blue, size: 20) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${staff.name} (ID: ${staff.employeeCode})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (staff.hasPunch) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.phone_android, size: 10, color: Colors.green.shade800),
                                const SizedBox(width: 4),
                                Text('Punched', style: TextStyle(fontSize: 9, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(staff.designation, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            emptySelectionAllowed: true,
            segments: [
              ButtonSegment<String>(
                value: 'Present',
                label: const Text('Present', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<String>(
                value: 'Absent',
                label: const Text('Absent', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<String>(
                value: 'Late',
                label: const Text('Late', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<String>(
                value: 'Half Day',
                label: const Text('Half Day', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: staff.status == 'Not Marked' ? <String>{} : {staff.status},
            onSelectionChanged: staff.hasPunch ? null : (Set<String> newSelection) {
              final newStatus = newSelection.isEmpty ? 'Not Marked' : newSelection.first;
              ref.read(staffAttendanceProvider.notifier).onStatusChanged(staff.staffId, newStatus);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return getStatusColor(staff.status).withValues(alpha: 0.15);
                }
                return null;
              }),
              foregroundColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return getStatusColor(staff.status);
                }
                return null;
              }),
              side: WidgetStateProperty.resolveWith<BorderSide?>((Set<WidgetState> states) {
                if (states.contains(WidgetState.selected)) {
                  return BorderSide(color: getStatusColor(staff.status).withValues(alpha: 0.5));
                }
                return null;
              }),
            ),
          ),
        ],
      ),
    );
  }
}
