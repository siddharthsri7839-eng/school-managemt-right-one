// lib/features/profile/data/staff_profile_models.dart

class StaffProfileData {
  final UserProfile user;
  final StaffDetails? staff;

  StaffProfileData({required this.user, this.staff});

  factory StaffProfileData.fromJson(Map<String, dynamic> json) {
    return StaffProfileData(
      user: UserProfile.fromJson(json['user']),
      staff: json['staff'] != null ? StaffDetails.fromJson(json['staff']) : null,
    );
  }
}

class UserProfile {
  final int id;
  final String name;
  final String email;
  final String? role;
  final String? avatar;
  final String? schoolName;
  final String? schoolLogo;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.avatar,
    this.schoolName,
    this.schoolLogo,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      avatar: json['avatar'],
      schoolName: json['school_name'],
      schoolLogo: json['school_logo'],
    );
  }
}

class StaffDetails {
  final int id;
  final String? staffIdCard;
  final String? department;
  final String? designation;
  final String? dateOfJoining;
  final String? phone;
  final String? emergencyContact;
  final String? maritalStatus;
  final String? currentAddress;
  final String? permanentAddress;
  final String? basicSalary;

  // EXTENDED DATA
  final String? gender;
  final String? dateOfBirth;
  final String? fatherName;
  final String? motherName;
  final String? qualification;
  final String? workExperience;
  final String? note;

  // NEW EMPLOYMENT DETAILS
  final String? employeeCode;
  final String? employmentType;
  final String? status;
  final String? confirmationDate;
  final int? reportingManagerId;

  // NEW EMERGENCY CONTACT
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? bloodGroup;

  // NEW STATUTORY IDs
  final String? panNumber;
  final String? aadhaarNumber;
  final String? pfNumber;
  final String? esiNumber;
  final String? uanNumber;

  // BANK DETAILS
  final String? bankAccountTitle;
  final String? bankName;
  final String? bankBranchName;
  final String? bankAccountNumber;
  final String? bankIfscCode;

  // SOCIAL LINKS
  final String? facebookUrl;
  final String? twitterUrl;
  final String? linkedinUrl;
  final String? instagramUrl;

  StaffDetails({
    required this.id,
    this.staffIdCard,
    this.department,
    this.designation,
    this.dateOfJoining,
    this.phone,
    this.emergencyContact,
    this.maritalStatus,
    this.currentAddress,
    this.permanentAddress,
    this.basicSalary,
    this.gender,
    this.dateOfBirth,
    this.fatherName,
    this.motherName,
    this.qualification,
    this.workExperience,
    this.note,
    this.employeeCode,
    this.employmentType,
    this.status,
    this.confirmationDate,
    this.reportingManagerId,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.bloodGroup,
    this.panNumber,
    this.aadhaarNumber,
    this.pfNumber,
    this.esiNumber,
    this.uanNumber,
    this.bankAccountTitle,
    this.bankName,
    this.bankBranchName,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.facebookUrl,
    this.twitterUrl,
    this.linkedinUrl,
    this.instagramUrl,
  });

  factory StaffDetails.fromJson(Map<String, dynamic> json) {
    return StaffDetails(
      id: json['id'],
      staffIdCard: json['staff_id_card'],
      department: json['department'],
      designation: json['designation'],
      dateOfJoining: json['date_of_joining'],
      phone: json['phone'],
      emergencyContact: json['emergency_contact'],
      maritalStatus: json['marital_status'],
      currentAddress: json['current_address'],
      permanentAddress: json['permanent_address'],
      basicSalary: json['basic_salary']?.toString(), // Handle float/int to string

      gender: json['gender'],
      dateOfBirth: json['date_of_birth'],
      fatherName: json['father_name'],
      motherName: json['mother_name'],
      qualification: json['qualification'],
      workExperience: json['work_experience'],
      note: json['note'],

      employeeCode: json['employee_code'],
      employmentType: json['employment_type'],
      status: json['status'],
      confirmationDate: json['confirmation_date'],
      reportingManagerId: json['reporting_manager_id'],

      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
      bloodGroup: json['blood_group'],

      panNumber: json['pan_number'],
      aadhaarNumber: json['aadhaar_number'],
      pfNumber: json['pf_number'],
      esiNumber: json['esi_number'],
      uanNumber: json['uan_number'],

      bankAccountTitle: json['bank_account_title'],
      bankName: json['bank_name'],
      bankBranchName: json['bank_branch_name'],
      bankAccountNumber: json['bank_account_number'],
      bankIfscCode: json['bank_ifsc_code'],

      facebookUrl: json['facebook_url'],
      twitterUrl: json['twitter_url'],
      linkedinUrl: json['linkedin_url'],
      instagramUrl: json['instagram_url'],
    );
  }
}
