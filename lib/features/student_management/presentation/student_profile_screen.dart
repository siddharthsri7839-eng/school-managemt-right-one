import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:school_erp_staff_app/core/auth/app_permission.dart';
import 'package:school_erp_staff_app/core/auth/permission_service.dart';
import 'package:school_erp_staff_app/core/branding/branding_providers.dart';
import 'student_profile_controller.dart';
import 'student_photo_actions.dart';
import 'package:school_erp_staff_app/shared/widgets/shimmer_loading.dart';

class StudentProfileScreen extends ConsumerWidget {
  final int studentId;
  const StudentProfileScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(studentProfileControllerProvider(studentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Student Profile')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(studentProfileControllerProvider(studentId).future),
        child: profileState.when(
          loading: () => SkeletonLoaders.profilePage(),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (profile) {
            // ✅ 2. GET API CLIENT FROM RIVERPOD
            final storageBaseUrl = ref.watch(apiClientProvider).storageBaseUrl;
            final String baseStorageUrl = storageBaseUrl.endsWith('/') ? storageBaseUrl : '$storageBaseUrl/';

            // Construct the full URL if the path exists
            final photoPath = profile['photo_url'] ?? profile['student_photo'];
            String? photoUrl;
            if (photoPath != null && photoPath.toString().isNotEmpty) {
              if (photoPath.toString().startsWith('http')) {
                photoUrl = photoPath.toString();
              } else {
                final cleanPath = photoPath.toString().startsWith('/') ? photoPath.toString().substring(1) : photoPath.toString();
                photoUrl = '$baseStorageUrl$cleanPath';
              }
              final separator = photoUrl.contains('?') ? '&' : '?';
              photoUrl = '$photoUrl${separator}t=${DateTime.now().millisecondsSinceEpoch}';
            }

            final feeSummary = profile['fee_summary'] as Map<String, dynamic>? ?? {};

            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // ✅ 3. PASS THE FULL URL TO THE HEADER
                _ProfileHeader(studentId: studentId, profile: profile, fullPhotoUrl: photoUrl),
                const SizedBox(height: 24),
                _SummaryCards(profile: profile, feeSummary: feeSummary),
                const SizedBox(height: 16),
                _ProfileDetailSection(
                  title: 'Academic Overview',
                  details: {
                    'Status': profile['status'],
                    'Admission Date': profile['admission_date'],
                    'PEN Number': profile['pen_number'],
                    'Biometric ID': profile['biometric_id'],
                    'House': profile['house'],
                  },
                ),
                _ProfileDetailSection(
                  title: 'Personal Details',
                  details: {
                    'Date of Birth': profile['date_of_birth'],
                    'Place of Birth': profile['place_of_birth'],
                    'Gender': profile['gender'],
                    'Nationality': profile['nationality'],
                    'Religion': profile['religion'],
                    'Caste': profile['caste'],
                    'Sub Caste': profile['sub_caste'],
                    'Blood Group': profile['blood_group'],
                    'Mother Tongue': profile['mother_tongue'],
                    'Category': profile['category'],
                    'Is BPL?': profile['is_bpl'],
                    'Is RTE?': profile['is_rte'],
                  },
                ),
                _ProfileDetailSection(
                  title: 'Contact & Addresses',
                  details: {
                    'Student Phone': profile['student_phone'],
                    'Student Email': profile['student_email'],
                    'Parent Email': profile['parent_email'],
                    'Current Address': profile['current_address'],
                    'Permanent Address': profile['permanent_address'],
                  },
                ),
                _ProfileDetailSection(
                  title: 'Father Details',
                  details: {
                    'Name': profile['father_name'],
                    'Phone': profile['father_phone'],
                    'Occupation': profile['father_occupation'],
                    'Qualification': profile['father_qualification'],
                    'Annual Income': profile['father_annual_income'],
                    'Aadhaar': profile['father_aadhaar'],
                  },
                ),
                _ProfileDetailSection(
                  title: 'Mother Details',
                  details: {
                    'Name': profile['mother_name'],
                    'Phone': profile['mother_phone'],
                    'Occupation': profile['mother_occupation'],
                    'Qualification': profile['mother_qualification'],
                    'Aadhaar': profile['mother_aadhaar'],
                  },
                ),
                if (profile['guardian_name'] != null && profile['guardian_name'] != 'N/A')
                  _ProfileDetailSection(
                    title: 'Guardian Details',
                    details: {
                      'Name': profile['guardian_name'],
                      'Relation': profile['guardian_relation'],
                      'Phone': profile['guardian_phone'],
                      'Email': profile['guardian_email'],
                      'Occupation': profile['guardian_occupation'],
                      'Address': profile['guardian_address'],
                    },
                  ),
                _ProfileDetailSection(
                  title: 'Health & Medical',
                  details: {
                    'Height': profile['height'],
                    'Weight': profile['weight'],
                    'Medical History': profile['medical_history'],
                  },
                ),
                _ProfileDetailSection(
                  title: 'Emergency Contact',
                  details: {
                    'Name': profile['emergency_contact_name'],
                    'Phone': profile['emergency_contact_phone'],
                  },
                ),
                _ProfileDetailSection(
                  title: 'Bank Details',
                  details: {
                    'Bank Name': profile['bank_name'],
                    'Account No': profile['bank_account_no'],
                    'IFSC Code': profile['ifsc_code'],
                    'National ID': profile['national_id_number'],
                  },
                ),
                if (profile['previous_school_details'] != null && profile['previous_school_details'] != 'N/A')
                  _ProfileDetailSection(
                    title: 'Previous School',
                    details: {
                      'Details': profile['previous_school_details'],
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  final int studentId;
  final Map<String, dynamic> profile;
  // ✅ 4. ACCEPT THE FULL URL
  final String? fullPhotoUrl;
  const _ProfileHeader({required this.studentId, required this.profile, this.fullPhotoUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionProvider);
    final canEditPhoto = perms.canAny({
      AppPermission.studentPhotoUpdate,
      AppPermission.studentPhotoUpdateOwn,
    });

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor,
                ),
                clipBehavior: Clip.antiAlias,
                child: fullPhotoUrl != null
                    ? Image.network(
                        fullPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person, size: 50, color: Colors.white);
                        },
                      )
                    : const Icon(Icons.person, size: 50, color: Colors.white),
              ),
              if (canEditPhoto)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: Theme.of(context).primaryColor,
                    shape: const CircleBorder(
                      side: BorderSide(color: Colors.white, width: 2),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _changePhoto(context, ref),
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(Icons.photo_camera, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(profile['full_name'] ?? 'N/A', style: Theme.of(context).textTheme.headlineSmall),
          Text('${ref.watch(terminologyProvider).classLabel}: ${profile['class'] ?? 'N/A'} - ${profile['section'] ?? 'N/A'}'),
          Text('Adm No: ${profile['admission_no'] ?? 'N/A'} | Roll No: ${profile['roll_no'] ?? 'N/A'}'),
        ],
      ),
    );
  }

  Future<void> _changePhoto(BuildContext context, WidgetRef ref) async {
    final newUrl = await pickAndUploadStudentPhoto(context, studentId);
    if (newUrl != null) {
      // Refetch the profile so the new photo (cache-busted) shows immediately.
      ref.invalidate(studentProfileControllerProvider(studentId));
    }
  }
}

// ... The rest of the file (_SummaryCards, _SummaryCard, _ProfileDetailSection) remains exactly the same ...
class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> profile;
  final Map<String, dynamic> feeSummary;
  const _SummaryCards({required this.profile, required this.feeSummary});

  @override
  Widget build(BuildContext context) {
    final currency = feeSummary['currency_symbol'] ?? '';
    final totalDue = feeSummary['total_due'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Attendance',
            subtitle: 'This Month',
            value: '${profile['attendance_percentage'] ?? 0}%',
            icon: Icons.check_circle_outline,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryCard(
            title: 'Fees Due',
            value: '$currency${totalDue}',
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDetailSection extends StatelessWidget {
  final String title;
  final Map<String, String?> details;
  const _ProfileDetailSection({required this.title, required this.details});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            ...details.entries
              .where((entry) => entry.value != null && entry.value!.isNotEmpty)
              .map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: TextStyle(color: Colors.grey.shade600)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        entry.value!, 
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}