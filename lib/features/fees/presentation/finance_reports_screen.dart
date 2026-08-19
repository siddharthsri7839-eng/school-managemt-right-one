import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/features/fees/presentation/finance_report_providers.dart';

class FinanceReportsScreen extends ConsumerStatefulWidget {
  const FinanceReportsScreen({super.key});

  @override
  ConsumerState<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends ConsumerState<FinanceReportsScreen> {
  String _selectedReportType = 'daily';
  DateTime _selectedDate = DateTime.now();
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  final List<Map<String, String>> _reportTypes = [
    {'value': 'daily', 'label': 'Daily Collection'},
    {'value': 'date_range', 'label': 'Date Range Collection'},
    {'value': 'fee_type', 'label': 'Fee Type Wise Collection'},
  ];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _generateReport() {
    // Construct query parameters
    final Map<String, String> params = {
      'report_type': _selectedReportType,
    };

    final DateFormat formatter = DateFormat('MM/dd/yyyy');

    if (_selectedReportType == 'daily') {
      params['date'] = formatter.format(_selectedDate);
    } else {
      // For date_range or fee_type
      final String start = formatter.format(_selectedDateRange.start);
      final String end = formatter.format(_selectedDateRange.end);
      params['date_range'] = '$start - $end';
    }

    // Build query string
    final queryString = Uri(queryParameters: params).query;
    final pdfUrl = 'staff/reports/finance/export-pdf?$queryString';

    // Get report title
    final title = _reportTypes.firstWhere((element) => element['value'] == _selectedReportType)['label'] ?? 'Finance Report';

    // Push to PDF viewer
    context.push(
      '/pdf-viewer',
      extra: {
        'pdfUrl': pdfUrl,
        'title': title,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final optionsState = ref.watch(financeReportOptionsProvider);

    return MainScaffold(
      title: 'Finance Reports',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Fees Report',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select the report type and date range to export the collection details as a PDF document.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Report Type Dropdown
            _buildSectionLabel('Report Type'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedReportType,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                  items: _reportTypes.map((Map<String, String> type) {
                    return DropdownMenuItem<String>(
                      value: type['value'],
                      child: Text(type['label']!),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedReportType = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Dynamic Date Picker based on report type
            _buildSectionLabel(_selectedReportType == 'daily' ? 'Select Date' : 'Select Date Range'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectedReportType == 'daily' ? _selectDate(context) : _selectDateRange(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: Colors.blue),
                    const SizedBox(width: 12),
                    Text(
                      _selectedReportType == 'daily'
                          ? DateFormat('dd MMM, yyyy').format(_selectedDate)
                          : '${DateFormat('dd MMM, yyyy').format(_selectedDateRange.start)} - ${DateFormat('dd MMM, yyyy').format(_selectedDateRange.end)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // Generate Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _generateReport,
                icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                label: const Text(
                  'Generate PDF Report',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}
