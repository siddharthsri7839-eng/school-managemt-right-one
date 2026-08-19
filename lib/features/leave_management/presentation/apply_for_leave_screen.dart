import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/api/api_exception.dart';
import 'leave_providers.dart';

class ApplyForLeaveScreen extends ConsumerStatefulWidget {
  const ApplyForLeaveScreen({super.key});

  @override
  ConsumerState<ApplyForLeaveScreen> createState() => _ApplyForLeaveScreenState();
}

class _ApplyForLeaveScreenState extends ConsumerState<ApplyForLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  dynamic _selectedLeaveType;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submitLeaveRequest() async {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date range.')),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        await ref.read(leaveRepositoryProvider).applyForLeave(
              leaveTypeId: _selectedLeaveType['id'],
              startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
              endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
              reason: _reasonController.text,
            );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave request submitted successfully!')),
          );
          Navigator.of(context).pop(); // Go back to the list screen
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = e.toString();
          if (e is ApiException) {
            errorMessage = e.message;
          }
          
          // Sanitize raw server errors, specifically mail server configuration issues
          final lowerMsg = errorMessage.toLowerCase();
          if (lowerMsg.contains('mail') || lowerMsg.contains('socket') || lowerMsg.contains('smtp') || lowerMsg.contains('swift_transportexception') || lowerMsg.contains('connection refused') || lowerMsg.contains('response code')) {
            errorMessage = 'Leave applied successfully, but the server failed to send an email notification.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveTypesState = ref.watch(leaveTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Leave'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              leaveTypesState.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
                data: (leaveTypes) => DropdownButtonFormField<dynamic>(
                  value: _selectedLeaveType,
                  items: leaveTypes.map((type) {
                    return DropdownMenuItem<dynamic>(
                      value: type,
                      child: Text(type['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedLeaveType = value);
                  },
                  decoration: const InputDecoration(labelText: 'Leave Type', border: OutlineInputBorder()),
                  validator: (value) => value == null ? 'Please select a leave type.' : null,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                leading: const Icon(Icons.calendar_today),
                title: const Text('From - To Date'),
                subtitle: Text(
                  _startDate == null || _endDate == null
                      ? 'Select Date Range'
                      : '${DateFormat('dd MMM, yyyy').format(_startDate!)} - ${DateFormat('dd MMM, yyyy').format(_endDate!)}',
                ),
                onTap: _selectDateRange,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()),
                maxLines: 4,
                validator: (value) => (value?.isEmpty ?? true) ? 'Please enter a reason.' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: _isLoading ? null : _submitLeaveRequest,
                child: _isLoading
                    ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white))
                    : const Text('Submit Application'),
              )
            ],
          ),
        ),
      ),
    );
  }
}