// lib/features/profile/presentation/staff_profile_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/shared/widgets/main_scaffold.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/features/profile/presentation/widgets/staff_id_card_modal.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:school_erp_staff_app/features/profile/data/staff_profile_models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:school_erp_staff_app/core/auth/app_permission.dart';
import 'package:school_erp_staff_app/core/auth/permission_service.dart';
import 'package:school_erp_staff_app/core/api/api_exception.dart';
import 'widgets/change_password_dialog.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class StaffProfileScreen extends ConsumerStatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  ConsumerState<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends ConsumerState<StaffProfileScreen> {
  bool _isLoading = true;
  StaffProfileData? _profileData;
  String? _errorMessage;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final dio = ApiClient().dio;
      final response = await dio.get('/staff/hr/my-profile');
      setState(() {
        _profileData = StaffProfileData.fromJson(response.data);
        _isLoading = false;
      });
    } on DioException catch (e) {
      final apiException = ApiException.fromDioException(e);
      if (mounted) {
        setState(() {
          _errorMessage = apiException.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile == null) return;

    setState(() { _isUploading = true; });

    try {
      final dio = ApiClient().dio;
      final file = File(pickedFile.path);

      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(file.path, filename: pickedFile.name),
      });

      final response = await dio.post('/staff/hr/my-profile/update-image', data: formData);
      
      if (response.data['photo_url'] != null) {
        await _fetchProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated successfully!'), backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() { _isUploading = false; });
      }
    }
  }

  void _showChangePasswordDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'My Profile',
      actions: [
        // Only show ID Card for staff/faculty with actual employee records
        if (_profileData?.staff != null)
          IconButton(
            icon: const Icon(Icons.badge_outlined),
            tooltip: 'ID Card',
            onPressed: () {
              if (_profileData != null) {
                showDialog(
                  context: context,
                  builder: (ctx) => StaffIdCardModal(
                    profileData: _profileData!,
                    schoolName: _profileData!.user.schoolName ?? 'School Name',
                  ),
                );
              }
            },
          ),
        IconButton(
          icon: const Icon(Icons.lock_reset),
          tooltip: 'Change Password',
          onPressed: _showChangePasswordDialog,
        ),
      ],
      body: _isLoading 
        ? SkeletonLoaders.profilePage()
        : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _profileData == null 
            ? const Center(child: Text('No profile data found.'))
              : RefreshIndicator(
                  onRefresh: _fetchProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHeaderConfig(context),
                        _buildInfoCards(context),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderConfig(BuildContext context) {
    final user = _profileData!.user;
    final staff = _profileData!.staff;
    final theme = Theme.of(context);
    final storageBaseUrl = ref.watch(apiClientProvider).storageBaseUrl;

    String? fullAvatarUrl;
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      if (user.avatar!.startsWith('http')) {
        fullAvatarUrl = user.avatar;
      } else {
        fullAvatarUrl = '$storageBaseUrl/${user.avatar!.replaceFirst(RegExp(r'^/+'), '')}';
      }
      // Add timestamp to break cache
      fullAvatarUrl = '$fullAvatarUrl?t=${DateTime.now().millisecondsSinceEpoch}';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 36, left: 20, right: 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      backgroundImage: fullAvatarUrl != null ? NetworkImage(fullAvatarUrl) : null,
                      child: fullAvatarUrl == null ? Text(user.name[0].toUpperCase(), style: TextStyle(fontSize: 32, color: theme.primaryColor)) : null,
                    ),
                  ),
                  if (_isUploading)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else if (ref.watch(permissionProvider).can(AppPermission.profilePhotoUpload))
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                    if (staff?.designation != null && staff!.designation != 'N/A')
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(staff.designation!, style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9))),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2), 
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                          SizedBox(width: 6),
                          Text('ACTIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.0)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCards(BuildContext context) {
    final staff = _profileData!.staff;
    if (staff == null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade100, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(Icons.admin_panel_settings, size: 48, color: Colors.blue.shade300),
              const SizedBox(height: 16),
              Text(
                "Internal Role",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
              ),
              const SizedBox(height: 8),
              Text(
                "Detailed staff records are only available for staff and faculty members.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blue.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildMinimalCard(
            title: 'Employment Details',
            icon: Icons.assignment_ind_outlined,
            cardColor: Colors.blue,
            children: [
              _buildDataRowIfValid('Employee Code', staff.employeeCode),
              _buildDataRowIfValid('Employment Type', staff.employmentType),
              _buildDataRowIfValid('Status', staff.status),
              _buildDataRowIfValid('Confirmation Date', staff.confirmationDate),
              // Reporting Manager ID is an int, typically you'd fetch the name, but we'll show ID if available
              if (staff.reportingManagerId != null) 
                _buildDataRowIfValid('Reporting Manager ID', staff.reportingManagerId.toString()),
            ],
          ),
          _buildMinimalCard(
            title: 'Professional Details',
            icon: Icons.work_outline,
            cardColor: Colors.indigo,
            children: [
              _buildDataRowIfValid('Staff ID', staff.staffIdCard),
              _buildDataRowIfValid('Department', staff.department),
              _buildDataRowIfValid('Designation', staff.designation),
              _buildDataRowIfValid('Basic Salary', staff.basicSalary != null ? '₹${staff.basicSalary}' : null),
              _buildDataRowIfValid(
                'Date of Joining', 
                staff.dateOfJoining != null ? DateFormat('dd MMM, yyyy').format(DateTime.parse(staff.dateOfJoining!)) : null
              ),
              _buildDataRowIfValid('Work Experience', staff.workExperience),
            ],
          ),
          _buildMinimalCard(
            title: 'Personal Details',
            icon: Icons.person_outline,
            cardColor: Colors.teal,
            children: [
              _buildDataRowIfValid(
                'Date of Birth', 
                staff.dateOfBirth != null ? DateFormat('dd MMM, yyyy').format(DateTime.parse(staff.dateOfBirth!)) : null
              ),
              _buildDataRowIfValid('Gender', staff.gender),
              _buildDataRowIfValid('Marital Status', staff.maritalStatus),
              _buildDataRowIfValid('Qualification', staff.qualification),
              _buildDataRowIfValid('Father Name', staff.fatherName),
              _buildDataRowIfValid('Mother Name', staff.motherName),
            ],
          ),
          _buildMinimalCard(
            title: 'Emergency Contact',
            icon: Icons.health_and_safety_outlined,
            cardColor: Colors.red,
            children: [
              _buildDataRowIfValid('Contact Name', staff.emergencyContactName),
              _buildDataRowIfValid('Contact Phone', staff.emergencyContactPhone ?? staff.emergencyContact),
              _buildDataRowIfValid('Blood Group', staff.bloodGroup),
            ],
          ),
          _buildMinimalCard(
            title: 'Statutory IDs',
            icon: Icons.account_balance_wallet_outlined,
            cardColor: Colors.purple,
            children: [
              _buildDataRowIfValid('PAN Number', staff.panNumber),
              _buildDataRowIfValid('Aadhaar Number', staff.aadhaarNumber),
              _buildDataRowIfValid('PF Number', staff.pfNumber),
              _buildDataRowIfValid('ESI Number', staff.esiNumber),
              _buildDataRowIfValid('UAN Number', staff.uanNumber),
            ],
          ),
          _buildMinimalCard(
            title: 'Contact Information',
            icon: Icons.contact_phone_outlined,
            cardColor: Colors.orange,
            children: [
              _buildDataRowIfValid('Phone', staff.phone),
              _buildDataRowIfValid('Emergency Contact', staff.emergencyContact),
              _buildDataRowIfValid('Email', _profileData!.user.email),
              _buildDataRowIfValid('Current Address', staff.currentAddress, isExpanded: true),
              _buildDataRowIfValid('Permanent Address', staff.permanentAddress, isExpanded: true),
            ],
          ),
          _buildMinimalCard(
            title: 'Bank Account Details',
            icon: Icons.account_balance_outlined,
            cardColor: Colors.green,
            children: [
              _buildDataRowIfValid('Account Title', staff.bankAccountTitle),
              _buildDataRowIfValid('Bank Name', staff.bankName),
              _buildDataRowIfValid('Branch Name', staff.bankBranchName),
              _buildDataRowIfValid('Account Number', staff.bankAccountNumber),
              _buildDataRowIfValid('IFSC Code', staff.bankIfscCode),
            ],
          ),
          _buildMinimalCard(
            title: 'Social Media',
            icon: Icons.link,
            cardColor: Colors.pink,
            children: [
              _buildDataRowIfValid('Facebook', staff.facebookUrl, isExpanded: true),
              _buildDataRowIfValid('Twitter', staff.twitterUrl, isExpanded: true),
              _buildDataRowIfValid('LinkedIn', staff.linkedinUrl, isExpanded: true),
              _buildDataRowIfValid('Instagram', staff.instagramUrl, isExpanded: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalCard({required String title, required IconData icon, required List<Widget?> children, MaterialColor cardColor = Colors.blue}) {
    final validChildren = children.where((child) => child != null).cast<Widget>().toList();
    
    if (validChildren.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor.shade50.withOpacity(0.5), // Very subtle pastel background
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardColor.shade100, width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: cardColor.shade700),
              ),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cardColor.shade900)),
            ],
          ),
          const SizedBox(height: 20),
          ...validChildren,
        ],
      ),
    );
  }

  Widget? _buildDataRowIfValid(String label, String? value, {bool isExpanded = false}) {
    if (value == null || value.trim().isEmpty) return null;
    return _buildDataRow(label, value, isExpanded: isExpanded);
  }

  Widget _buildDataRow(String label, String value, {bool isExpanded = false}) {
    if (isExpanded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
