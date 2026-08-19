/// All known permission keys the backend can grant via Spatie.
///
/// Each enum value maps 1:1 to a Spatie permission string.
/// Adding a new backend permission? Add it here and it's immediately
/// available for `PermissionService.can()` checks with compile-time safety.
enum AppPermission {
  // ── Academics ──────────────────────────────────────────────
  academicsDashboardView('academics.dashboard.view'),
  studentView('student.view'),
  // Student photo update: whole-school vs own-allotted-sections (teacher).
  studentPhotoUpdate('student.photo.update'),
  studentPhotoUpdateOwn('student.photo.update.own'),
  attendanceTake('attendance.take'),
  homeworkManage('homework.manage'),
  examMarksEntry('exam_marks.entry'),
  timetableView('timetable.view'),

  // ── QR / Barcode Attendance (staff-app scanner "Plan B") ───
  // REAL Spatie rows: mark (whole-school gate), mark.own (section-scoped
  // classroom), mark.staff (mark staff, admin only), view (read-only). Created by
  // 2026_06_11_100100 + 2026_08_02_120000 migrations — never fake these strings.
  qrAttendanceView('qr_attendance.view'),
  qrAttendanceMark('qr_attendance.mark'),
  qrAttendanceMarkOwn('qr_attendance.mark.own'),
  qrAttendanceMarkStaff('qr_attendance.mark.staff'),

  // ── HR / Administration ────────────────────────────────────
  hrLeaveApprove('hr.leave.approve'),
  hrStaffView('hr.staff.view'),
  hrStaffAttendanceMark('hr.staff_attendance.mark'),
  hrStaffAttendanceReport('hr.staff_attendance.report'),

  // ── Finance ────────────────────────────────────────────────
  feesViewReport('fees.view_report'),
  feesDueView('fees.due.view'),        // admin/accountant — whole school
  feesDueViewOwn('fees.due.view.own'), // teacher — own allotted classes

  // ── Communication ──────────────────────────────────────────
  noticeView('notice.view'),
  noticeCreate('notice.create'),
  communicationLogView('communication.log.view'),

  // ── Profile ────────────────────────────────────────────────
  profileView('profile.view'),
  profilePhotoUpload('profile.photo_upload'),

  // ── System ────────────────────────────────────────────────
  systemAuditTrailView('system.audit_trail.view'),
  
  // ── Transport ─────────────────────────────────────────────
  transportManage('transport.manage'),

  // ── Front Office ─────────────────────────────────────────
  frontOfficeManage('frontoffice.dashboard.view'),

  // ── Gate Pass ────────────────────────────────────────────
  // REAL Spatie rows, created by 2026_08_02_190000. `verify` is the gate itself
  // (scan out / scan in) and grants nothing else — it is what the `security` role
  // holds. `view` is read-only and is also held by class teachers, who must NOT be
  // shown the scanner. Never fake these strings.
  gatePassView('frontoffice.gatepass.view'),
  gatePassVerify('frontoffice.gatepass.verify'),
  gatePassManage('frontoffice.gatepass.manage'),

  // ── Inventory ────────────────────────────────────────────
  inventoryDashboardView('inventory.dashboard.view'),

  // ── Asset Management ─────────────────────────────────────
  assetDashboardView('asset.dashboard.view'),

  // ── Library Management ───────────────────────────────────
  libraryManage('library.manage'),

  // ── Hostel Management ────────────────────────────────────
  hostelManage('hostel.manage'),

  // ── CBC Academics ────────────────────────────────────────
  cbcManage('cbc.strand.manage'),

  // ── PTM Meetings ─────────────────────────────────────────
  ptmManage('ptm.meeting.manage'),
  ptmAttendanceManage('ptm.attendance.manage'),
  ptmRemarkManage('ptm.remark.manage'),

  // ── Lesson Planner ─────────────────────────────────────────
  lessonPlanManage('lesson_plan.dashboard.view'),

  // ── Live Classes ───────────────────────────────────────────
  // These two DO exist as Spatie permission rows (verified 2026-07-20),
  // unlike some older entries in this enum.
  liveClassView('live_class.view'),
  liveClassManageOwn('live_class.manage_own'),

  // ── Online Exams ───────────────────────────────────────────
  // Both are REAL Spatie permission names, matching the rows the seeder
  // creates. `manage` reaches the module and marks answers; `settings` is the
  // authoring gate the builder routes sit behind.
  onlineExamManage('exam.online_exam.manage'),
  onlineExamSettings('exam.online_exam.settings'),

  // ── Continuous Assessment ──────────────────────────────────
  assessmentDashboardView('assessment.dashboard.view'),
  assessmentManage('assessment.manage'),
  assessmentMarksEnter('assessment.marks.enter'),
  assessmentMarksPublish('assessment.marks.publish'),
  assessmentReportView('assessment.report.view'),

  // ── Knowledge Base ────────────────────────────────────────
  kbManage('knowledge_base.manage'),

  // ── Self-service (available to all staff) ──────────────────
  selfAttendanceView('self.attendance.view'),
  selfLeaveApply('self.leave.apply'),
  selfLeaveView('self.leave.view');

  /// The exact key string used in the backend Spatie permissions table.
  final String backendKey;

  const AppPermission(this.backendKey);

  /// Resolve a backend permission string to the enum value, or null if unknown.
  static AppPermission? fromBackendKey(String key) {
    for (final p in values) {
      if (p.backendKey == key) return p;
    }
    return null;
  }

  /// Batch-convert a list of backend permission strings to a set of enums.
  /// Unknown keys are silently skipped — this keeps the app forward-compatible
  /// when the backend adds permissions the current app version doesn't know about.
  static Set<AppPermission> fromBackendKeys(List<String> keys) {
    final result = <AppPermission>{};
    for (final key in keys) {
      final p = fromBackendKey(key);
      if (p != null) result.add(p);
    }
    return result;
  }
}
