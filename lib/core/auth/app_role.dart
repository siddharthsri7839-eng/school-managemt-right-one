import 'app_permission.dart';

/// Known staff roles in the system.
///
/// Each role carries:
/// - A display name for UI rendering
/// - A set of **default permissions** used as fallback when the backend
///   doesn't send a granular permissions array (backward compatibility).
///
/// To add a new role: add an enum value, set its display name and default
/// permissions. No other files need changes.
enum AppRole {
  schoolAdmin,
  teacher,
  accountant,
  librarian,
  receptionist,
  driver,
  other;

  /// Parse a raw role string from the backend into the enum.
  /// Unknown strings map to [AppRole.other] so the app never crashes.
  factory AppRole.fromString(String? raw) {
    if (raw == null || raw.isEmpty) return AppRole.other;
    final normalized = raw.toLowerCase().trim();
    return switch (normalized) {
      'school_admin' => AppRole.schoolAdmin,
      'teacher' => AppRole.teacher,
      'accountant' => AppRole.accountant,
      'librarian' => AppRole.librarian,
      'receptionist' => AppRole.receptionist,
      'driver' => AppRole.driver,
      _ => AppRole.other,
    };
  }

  /// Human-readable name shown in drawer headers, profile screens, etc.
  String get displayName => switch (this) {
        AppRole.schoolAdmin => 'Administrator',
        AppRole.teacher => 'Teacher',
        AppRole.accountant => 'Accountant',
        AppRole.librarian => 'Librarian',
        AppRole.receptionist => 'Receptionist',
        AppRole.driver => 'Driver',
        AppRole.other => 'Staff',
      };

  /// Whether this role is considered "academic" (can access student data,
  /// attendance, marks entry, etc.).
  bool get isAcademic => this == AppRole.schoolAdmin || this == AppRole.teacher;

  /// Fallback permission set used when the backend doesn't send a granular
  /// `permissions` array. Once the backend is updated, these are only used
  /// as a safety net.
  Set<AppPermission> get defaultPermissions => switch (this) {
        AppRole.schoolAdmin => {
            // Academics
            AppPermission.academicsDashboardView,
            AppPermission.studentView,
            AppPermission.attendanceTake,
            AppPermission.homeworkManage,
            AppPermission.examMarksEntry,
            AppPermission.timetableView,
            AppPermission.liveClassView,
            AppPermission.liveClassManageOwn,
            // HR
            AppPermission.hrLeaveApprove,
            AppPermission.hrStaffView,
            AppPermission.hrStaffAttendanceMark,
            AppPermission.hrStaffAttendanceReport,
            // Finance
            AppPermission.feesViewReport,
            // Communication
            AppPermission.noticeView,
            AppPermission.noticeCreate,
            AppPermission.communicationLogView,
            // System
            AppPermission.systemAuditTrailView,
            // Profile
            AppPermission.profileView,
            // Self-service
            AppPermission.selfAttendanceView,
            AppPermission.selfLeaveView,
          },
        AppRole.teacher => {
            // Academics
            AppPermission.studentView,
            AppPermission.attendanceTake,
            AppPermission.homeworkManage,
            AppPermission.examMarksEntry,
            AppPermission.timetableView,
            AppPermission.liveClassView,
            AppPermission.liveClassManageOwn,
            // Communication
            AppPermission.noticeView,
            // Profile
            AppPermission.profileView,
            AppPermission.profilePhotoUpload,
            // Self-service
            AppPermission.selfAttendanceView,
            AppPermission.selfLeaveApply,
            AppPermission.selfLeaveView,
          },
        AppRole.accountant => {
            // Finance
            AppPermission.feesViewReport,
            // Communication
            AppPermission.noticeView,
            // Profile
            AppPermission.profileView,
            AppPermission.profilePhotoUpload,
            // Self-service
            AppPermission.selfAttendanceView,
            AppPermission.selfLeaveApply,
            AppPermission.selfLeaveView,
          },
        // All other roles get minimal self-service permissions
        _ => {
            AppPermission.noticeView,
            AppPermission.profileView,
            AppPermission.profilePhotoUpload,
            AppPermission.selfAttendanceView,
            AppPermission.selfLeaveApply,
            AppPermission.selfLeaveView,
          },
      };
}
