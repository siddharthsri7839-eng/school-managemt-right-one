import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/core/auth/app_permission.dart';
import 'package:school_erp_staff_app/core/auth/permission_service.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';
import 'package:school_erp_staff_app/features/hr/data/hr_repository.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';

// --- State Models ---
class ReportState {
  final bool isLoading;
  final String viewMode; // 'monthly' or 'member'
  final DateTime selectedMonth;
  final String? selectedStaffId;
  
  // Monthly Data
  final List<dynamic> monthlyData;
  final int daysInMonth;
  
  // Member Data
  final Map<String, dynamic> memberStats;
  final List<dynamic> memberLogs;
  
  // Staff Selection list
  final List<dynamic> staffList;

  // Error Handling
  final String? errorMessage;

  ReportState({
    this.isLoading = false,
    this.viewMode = 'monthly',
    required this.selectedMonth,
    this.selectedStaffId,
    this.monthlyData = const [],
    this.daysInMonth = 31,
    this.memberStats = const {},
    this.memberLogs = const [],
    this.staffList = const [],
    this.errorMessage,
  });

  ReportState copyWith({
    bool? isLoading,
    String? viewMode,
    DateTime? selectedMonth,
    String? selectedStaffId,
    List<dynamic>? monthlyData,
    int? daysInMonth,
    Map<String, dynamic>? memberStats,
    List<dynamic>? memberLogs,
    List<dynamic>? staffList,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReportState(
      isLoading: isLoading ?? this.isLoading,
      viewMode: viewMode ?? this.viewMode,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedStaffId: selectedStaffId ?? this.selectedStaffId,
      monthlyData: monthlyData ?? this.monthlyData,
      daysInMonth: daysInMonth ?? this.daysInMonth,
      memberStats: memberStats ?? this.memberStats,
      memberLogs: memberLogs ?? this.memberLogs,
      staffList: staffList ?? this.staffList,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// --- Controller ---
class ReportController extends StateNotifier<ReportState> {
  final HrRepository _repository;

  ReportController(this._repository) : super(ReportState(selectedMonth: DateTime.now())) {
    _initData();
  }

  Future<void> _initData() async {
    await fetchStaffList();
    fetchReportData();
  }

  Future<void> fetchStaffList() async {
    try {
      final data = await _repository.getStaffList();
      
      // Select first staff by default if member view is accessed
      String? defaultStaffId;
      if (data.isNotEmpty) {
        defaultStaffId = data[0]['id'].toString();
      }
      
      state = state.copyWith(staffList: data, selectedStaffId: defaultStaffId, clearError: true);
    } catch (e) {
      debugPrint('Error fetching staff list: $e');
      state = state.copyWith(errorMessage: ApiException.from(e).message);
    }
  }

  Future<void> fetchReportData() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final monthStr = DateFormat('yyyy-MM').format(state.selectedMonth);
      
      final responseData = await _repository.getStaffAttendanceReport(
        viewMode: state.viewMode,
        month: monthStr,
        staffId: state.selectedStaffId,
      );
      
      if (state.viewMode == 'monthly') {
        state = state.copyWith(
          monthlyData: responseData['data'] ?? [],
          daysInMonth: responseData['days_in_month'] ?? 31,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          memberStats: responseData['stats'] ?? {},
          memberLogs: responseData['logs'] ?? [],
          isLoading: false,
        );
      }
    } catch (e) {
      debugPrint('Error fetching report data: $e');
      state = state.copyWith(isLoading: false, errorMessage: ApiException.from(e).message);
    }
  }

  void changeViewMode(String mode) {
    if (state.viewMode == mode) return;
    state = state.copyWith(viewMode: mode, monthlyData: [], memberLogs: []);
    fetchReportData();
  }

  void setMonth(DateTime month) {
    state = state.copyWith(selectedMonth: month, monthlyData: [], memberLogs: []);
    fetchReportData();
  }

  void setStaff(String staffId) {
    state = state.copyWith(selectedStaffId: staffId, memberLogs: []);
    fetchReportData();
  }
}

final reportProvider = StateNotifierProvider<ReportController, ReportState>((ref) {
  final repository = ref.watch(hrRepositoryProvider);
  return ReportController(repository);
});

// --- UI Screens ---

class StaffAttendanceReportScreen extends ConsumerWidget {
  const StaffAttendanceReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportProvider);
    final controller = ref.read(reportProvider.notifier);
    final theme = Theme.of(context);

    final perms = ref.watch(permissionProvider);
    final isAdmin = perms.can(AppPermission.hrStaffAttendanceReport);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isAdmin && state.viewMode != 'member') {
        controller.changeViewMode('member');
      }
    });

    return MainScaffold(
      title: isAdmin ? 'Staff Attendance' : 'My Attendance',
      body: Column(
        children: [
          // Header Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Context banner — makes it unmistakable these are STAFF
                // (teachers/employees) records, not student attendance.
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.20)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.badge_outlined,
                          size: 18, color: theme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAdmin
                              ? 'Staff attendance — teachers & employees (not students)'
                              : 'Your own staff attendance log',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // View Switcher (Admin Only)
                if (isAdmin)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      _buildTabButton(
                        'Monthly Overview', 
                        state.viewMode == 'monthly', 
                        () => controller.changeViewMode('monthly')
                      ),
                      _buildTabButton(
                        'Individual Staff', 
                        state.viewMode == 'member', 
                        () => controller.changeViewMode('member')
                      ),
                    ],
                  ),
                ),
                if (isAdmin) const SizedBox(height: 16),
                
                // Month Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(state.selectedMonth),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_month, color: Colors.blue),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: state.selectedMonth,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          controller.setMonth(picked);
                        }
                      },
                    ),
                  ],
                ),
                
                // Staff Selector (Only in Member view for Admins)
                if (isAdmin && state.viewMode == 'member' && state.staffList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: state.selectedStaffId,
                        hint: const Text('Select Staff'),
                        items: state.staffList.map((staff) {
                          return DropdownMenuItem<String>(
                            value: staff['id'].toString(),
                            child: Text('${staff['name']} - ${staff['designation'] ?? ''}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) controller.setStaff(val);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Content Area
          Expanded(
            child: state.errorMessage != null
                ? Center(
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
                            onPressed: () => controller.fetchReportData(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : state.isLoading
                    ? SkeletonLoaders.dashboard()
                    : (state.viewMode == 'monthly' ? _buildMonthlyGrid(state) : _buildMemberDetail(state, isAdmin)),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyGrid(ReportState state) {
    if (state.monthlyData.isEmpty) {
      return const Center(child: Text("No data available for this month."));
    }

    // Creating a Data DataTable requires knowing columns. We have up to 31 columns + total
    List<DataColumn> columns = [
      const DataColumn(label: Text('Staff', style: TextStyle(fontWeight: FontWeight.bold))),
    ];
    for (int i = 1; i <= state.daysInMonth; i++) {
      columns.add(DataColumn(
        label: Text(i.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        numeric: true,
      ));
    }
    columns.add(const DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))));

    List<DataRow> rows = state.monthlyData.map((staff) {
      List<DataCell> cells = [
        DataCell(
          SizedBox(
            width: 120, // fixed width for staff name
            child: Text(staff['name'] ?? 'Unknown', overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ),
      ];

      for (int i = 1; i <= state.daysInMonth; i++) {
        String? status = staff['days'][i.toString()];
        Widget icon = const Text('-');
        if (status != null && status.isNotEmpty) {
          if (status.toLowerCase() == 'present') {
            icon = const Icon(Icons.check, color: Colors.green, size: 16);
          } else if (status.toLowerCase() == 'absent') {
            icon = const Icon(Icons.close, color: Colors.red, size: 16);
          } else if (status.toLowerCase() == 'late') {
            icon = const Icon(Icons.access_time, color: Colors.orange, size: 16);
          } else if (status.toLowerCase() == 'half day') {
            icon = const Icon(Icons.tonality, color: Colors.blue, size: 16);
          }
        }
        cells.add(DataCell(Center(child: icon)));
      }
      
      cells.add(DataCell(
        Center(
          child: Text(
            '${staff['total_present']}/${staff['total_days']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ));

      return DataRow(cells: cells);
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          color: Colors.white,
          margin: const EdgeInsets.all(8),
          child: DataTable(
            columnSpacing: 10,
            horizontalMargin: 12,
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
            columns: columns,
            rows: rows,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberDetail(ReportState state, bool isAdmin) {
    if (isAdmin && (state.staffList.isEmpty || state.selectedStaffId == null)) {
      return const Center(child: Text("Select a staff member."));
    }

    final stats = state.memberStats;
    final logs = state.memberLogs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Row 1
          Row(
            children: [
              _buildStatCard('Present', '${stats['present'] ?? 0}', Colors.green),
              const SizedBox(width: 12),
              _buildStatCard('Absent', '${stats['absent'] ?? 0}', Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          // Stats Row 2
          Row(
            children: [
              _buildStatCard('Late', '${stats['late'] ?? 0}', Colors.orange),
              const SizedBox(width: 12),
              _buildStatCard('Working Days', '${stats['working_days'] ?? 0}', Colors.blue),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text('Detailed Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          
          if (logs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 2, strokeAlign: BorderSide.strokeAlignOutside),
              ),
              child: Column(
                children: [
                  Icon(Icons.history_toggle_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "No Punch Logs",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "There are no attendance records for this month.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                
                Color statusColor = Colors.grey;
                String status = log['status'] ?? 'Unknown';
                if (status.toLowerCase() == 'present') statusColor = Colors.green;
                if (status.toLowerCase() == 'absent') statusColor = Colors.red;
                if (status.toLowerCase() == 'late') statusColor = Colors.orange;
                if (status.toLowerCase() == 'half day') statusColor = Colors.blue;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade100, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                          child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                        ),
                        const SizedBox(width: 16),
                        // Log Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('EEEE, d MMM').format(DateTime.parse(log['date'])), style: const TextStyle(fontSize: 16, color: Colors.black87)),
                              const SizedBox(height: 6),
                              if (log['punch_in'] != null) 
                                Text('In: ${log['punch_in']} | Out: ${log['punch_out'] ?? '--:--'}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                              if (log['punch_in_ip'] != null || log['punch_in_lat'] != null)
                                _buildLocationRow(
                                  isPunchIn: true,
                                  ip: log['punch_in_ip'],
                                  lat: log['punch_in_lat']?.toString(),
                                  lng: log['punch_in_lng']?.toString()
                                ),
                              if (log['punch_out_ip'] != null || log['punch_out_lat'] != null)
                                _buildLocationRow(
                                  isPunchIn: false,
                                  ip: log['punch_out_ip'],
                                  lat: log['punch_out_lat']?.toString(),
                                  lng: log['punch_out_lng']?.toString()
                                ),
                              if (log['remarks'] != null && log['remarks'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text('Remarks: ${log['remarks']}', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey.shade600)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({required bool isPunchIn, String? ip, String? lat, String? lng}) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isPunchIn ? Icons.login : Icons.logout,
            size: 14,
            color: isPunchIn ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          if (lat != null && lng != null && lat.isNotEmpty && lng.isNotEmpty)
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 6.0),
                child: Icon(Icons.location_on, size: 16, color: Colors.blue),
              ),
            ),
          if (ip != null && ip.isNotEmpty)
            Text(ip, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
