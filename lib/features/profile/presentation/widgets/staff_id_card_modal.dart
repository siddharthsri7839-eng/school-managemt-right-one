import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:school_erp_staff_app/features/profile/data/staff_profile_models.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:intl/intl.dart';

class StaffIdCardModal extends ConsumerWidget {
  final StaffProfileData profileData;
  final String schoolName;

  const StaffIdCardModal({
    super.key,
    required this.profileData,
    required this.schoolName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = profileData.user;
    final staff = profileData.staff;
    final storageBaseUrl = ref.watch(apiClientProvider).storageBaseUrl;
    
    const Color headerBlue = Color(0xFF2C3E92); 
    const Color textBlue = Color(0xFF003399);
    const Color badgeOrange = Color(0xFFFF7A00);

    // Get correct barcode data (ignore 'N/A')
    String barcodeData = user.id.toString();
    if (staff?.employeeCode != null && staff!.employeeCode != 'N/A') {
      barcodeData = staff.employeeCode!;
    } else if (staff?.staffIdCard != null && staff!.staffIdCard != 'N/A') {
      barcodeData = staff.staffIdCard!;
    }
    
    // Format DOJ if valid
    String formattedDoj = 'N/A';
    if (staff?.dateOfJoining != null && staff!.dateOfJoining != 'N/A') {
      try {
        formattedDoj = DateFormat('dd-MMM-yyyy').format(DateTime.parse(staff.dateOfJoining!));
      } catch (_) {
        formattedDoj = staff.dateOfJoining!;
      }
    }

    // Resolve URLs
    String? fullAvatarUrl;
    if (user.avatar != null && user.avatar!.isNotEmpty) {
      if (user.avatar!.startsWith('http')) {
        fullAvatarUrl = user.avatar;
      } else {
        fullAvatarUrl = '$storageBaseUrl/${user.avatar!.replaceFirst(RegExp(r'^/+'), '')}';
      }
    }

    String? fullLogoUrl;
    if (user.schoolLogo != null && user.schoolLogo!.isNotEmpty) {
      if (user.schoolLogo!.startsWith('http')) {
        fullLogoUrl = user.schoolLogo;
      } else {
        fullLogoUrl = '$storageBaseUrl/${user.schoolLogo!.replaceFirst(RegExp(r'^/+'), '')}';
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 320, // Slightly narrower for better proportions
                decoration: BoxDecoration(
                  color: Colors.white, // Pure white background
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  children: [
                    // TOP BLUE HEADER
                    Container(
                      decoration: const BoxDecoration(
                        color: headerBlue,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 45),
                      child: Row(
                        children: [
                          // SCHOOL LOGO
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: fullLogoUrl != null 
                              ? Image.network(
                                  fullLogoUrl, 
                                  fit: BoxFit.contain,
                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.school, color: headerBlue),
                                )
                              : const Icon(Icons.school, color: headerBlue),
                          ),
                          const SizedBox(width: 12),
                          // SCHOOL NAME
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  schoolName.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'STAFF IDENTITY CARD',
                                  style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.0),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // BODY OF CARD
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        // Background whitespace to push content down
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(top: 65, bottom: 24, left: 24, right: 24),
                          color: const Color(0xFFF8F9FA), // Very light grey/off-white background
                          child: Column(
                            children: [
                              // NAME
                              Text(
                                user.name.toUpperCase(),
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textBlue, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 12),
                              
                              // DESIGNATION BADGE
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                decoration: BoxDecoration(
                                  color: badgeOrange,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  staff?.designation ?? 'Staff Member',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // DETAILS GRID
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Column(
                                  children: [
                                    _buildDetailRow('ID No:', staff?.staffIdCard ?? 'N/A'),
                                    const SizedBox(height: 12),
                                    _buildDetailRow('Dept:', staff?.department ?? 'N/A'),
                                    const SizedBox(height: 12),
                                    _buildDetailRow('Phone:', staff?.phone ?? 'N/A'),
                                    const SizedBox(height: 12),
                                    _buildDetailRow('DOJ:', formattedDoj),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 40),
                              
                              // BARCODE
                              BarcodeWidget(
                                barcode: Barcode.code128(),
                                data: barcodeData,
                                width: 220,
                                height: 50,
                                drawText: true,
                                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                              ),
                            ],
                          ),
                        ),
                        
                        // AVATAR OVERLAPPING THE TOP
                        Positioned(
                          top: -45, // Pull it up into the blue header
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: textBlue, width: 4),
                            ),
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.white,
                              backgroundImage: fullAvatarUrl != null ? NetworkImage(fullAvatarUrl) : null,
                              child: fullAvatarUrl == null
                                  ? Text(user.name[0].toUpperCase(), style: const TextStyle(fontSize: 36, color: textBlue))
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // ACTIONS (DOWNLOAD & CLOSE)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    heroTag: 'download_id',
                    backgroundColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID Card saved to gallery!')),
                      );
                    },
                    child: const Icon(Icons.download, color: headerBlue),
                  ),
                  const SizedBox(width: 24),
                  FloatingActionButton(
                    heroTag: 'close_id',
                    backgroundColor: Colors.white,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
