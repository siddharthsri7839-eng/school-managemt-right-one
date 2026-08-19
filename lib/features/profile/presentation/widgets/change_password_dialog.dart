// lib/features/profile/presentation/widgets/change_password_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  ConsumerState<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ApiClient().dio;
      await dio.post('/staff/hr/my-profile/update-password', data: {
        'current_password': _currentPasswordController.text,
        'password': _newPasswordController.text,
        'password_confirmation': _confirmPasswordController.text,
      });
      
      if (!mounted) return;
      context.pop(true); // Return Success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data['errors'] != null) {
          setState(() {
            _errorMessage = data['errors'].values.first[0].toString();
          });
        } else if (data['message'] != null) {
           setState(() {
            _errorMessage = data['message'].toString();
          });
        } else {
          setState(() {
            _errorMessage = 'An error occurred. Please try again.';
          });
        }
      } else {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Change Password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.pop(),
                  )
                ],
              ),
              const SizedBox(height: 16),
              
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),

              _buildPasswordField(
                controller: _currentPasswordController,
                label: 'Current Password',
                obscureText: _obscureCurrent,
                onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _newPasswordController,
                label: 'New Password (min 8 characters)',
                obscureText: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (val) {
                  if (val == null || val.length < 8) return 'Password must be at least 8 characters';
                  return null;
                }
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password',
                obscureText: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (val) {
                  if (val != _newPasswordController.text) return 'Passwords do not match';
                  return null;
                }
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Update Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller, 
    required String label, 
    required bool obscureText, 
    required VoidCallback onToggle,
    String? Function(String?)? validator
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
      validator: validator ?? (val) {
        if (val == null || val.isEmpty) return 'This field is required';
        return null;
      },
    );
  }
}
