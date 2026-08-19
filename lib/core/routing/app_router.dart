import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_erp_staff_app/core/auth/app_permission.dart';
import 'package:school_erp_staff_app/core/auth/app_role.dart';
import 'package:school_erp_staff_app/core/auth/permission_service.dart';
import 'package:school_erp_staff_app/features/auth/presentation/auth_controller.dart';
import 'package:school_erp_staff_app/shared/widgets/scaffold_with_navbar.dart';

// Import all your screen files...
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/profile/presentation/staff_profile_screen.dart';
import '../../features/student_management/presentation/student_profile_screen.dart';
import '../../features/student_management/presentation/student_search_screen.dart';
import '../../features/student_management/presentation/students_without_photo_screen.dart';
import '../../features/academics/presentation/academics_dashboard_screen.dart';
import '../../features/system/presentation/audit_trail_screen.dart';
import '../../features/gate_pass/presentation/gate_scanner_screen.dart';
import '../../features/qr_attendance/presentation/qr_scanner_screen.dart';
import '../../features/exams/presentation/offline_exams_dashboard_screen.dart';
import '../../features/transport/presentation/transport_dashboard_screen.dart';
import '../../features/front_office/presentation/front_office_dashboard_screen.dart';
import '../../features/inventory/presentation/inventory_dashboard_screen.dart';
import '../../features/assets/presentation/asset_dashboard_screen.dart';
import '../../features/library/presentation/library_dashboard_screen.dart';
import '../../features/hostel/presentation/hostel_dashboard_screen.dart';
import '../../features/cbc/presentation/cbc_dashboard_screen.dart';
import '../../features/live_class/data/models/live_class.dart';
import '../../features/live_class/presentation/live_class_form_screen.dart';
import '../../features/live_class/presentation/live_class_list_screen.dart';
import '../../features/ptm/presentation/ptm_dashboard_screen.dart';
import '../../features/ptm/presentation/ptm_reports_screen.dart';
import '../../features/ptm/presentation/ptm_record_list_screen.dart';
import '../../features/ptm/presentation/ptm_record_roster_screen.dart';
import '../../features/lesson_plan/presentation/lesson_plan_dashboard_screen.dart';
import '../../features/online_exam/presentation/online_exam_dashboard_screen.dart';
import '../../features/online_exam/presentation/online_exam_list_screen.dart';
import '../../features/online_exam/presentation/online_exam_detail_screen.dart';
import '../../features/online_exam/presentation/exam_create_screen.dart';
import '../../features/online_exam/presentation/exam_builder_screen.dart';
import '../../features/online_exam/presentation/question_picker_screen.dart';
import '../../features/online_exam/presentation/schedule_form_screen.dart';
import '../../features/online_exam/presentation/marking_queue_screen.dart';
import '../../features/online_exam/presentation/mark_attempt_screen.dart';
import '../../features/assessment/presentation/assessment_dashboard_screen.dart';
import '../../features/assessment/presentation/assessment_list_screen.dart';
import '../../features/assessment/presentation/assessment_detail_screen.dart';
import '../../features/assessment/presentation/assessment_form_screen.dart';
import '../../features/assessment/presentation/mark_entry_screen.dart';
import '../../features/assessment/presentation/assessment_reports_screen.dart';
import '../../features/assessment/domain/assessment_models.dart';
import '../../features/fees_due/presentation/fees_due_screen.dart';
import '../../features/dashboard/presentation/staff_dashboard_screen.dart';
import '../../features/attendance/presentation/select_section_screen.dart';
import '../../features/attendance/presentation/take_attendance_screen.dart';
import '../../features/attendance/presentation/self_attendance_screen.dart';
import '../../features/attendance/presentation/student_attendance_report_screen.dart';
import '../../features/homework_management/presentation/homework_list_screen.dart';
import '../../features/homework_management/presentation/homework_details_screen.dart';
import '../../features/homework_management/presentation/create_homework_screen.dart';
import '../../features/classwork/presentation/classwork_list_screen.dart';
import '../../features/classwork/presentation/classwork_form_screen.dart';
import '../../features/classwork/presentation/classwork_details_screen.dart';
import '../../features/leave_management/presentation/my_leave_requests_screen.dart';
import '../../features/leave_management/presentation/apply_for_leave_screen.dart';
import '../../features/notice_board/presentation/notice_list_screen.dart';
import '../../features/notice_board/presentation/create_notice_screen.dart';
import '../../features/notice_board/presentation/notice_detail_screen.dart';
import '../../features/surveys/presentation/survey_inbox_screen.dart';
import '../../features/surveys/presentation/survey_respond_screen.dart';
import '../../features/chat/presentation/chat_threads_screen.dart';
import '../../features/chat/presentation/chat_contacts_screen.dart';
import '../../features/chat/presentation/chat_thread_screen.dart';
import '../../features/timetable/presentation/timetable_screen.dart';
import '../../features/exam_marks/presentation/marks_selection_screen.dart';
import '../../features/leave_management/presentation/admin_leave_approval_screen.dart';

import '../../features/hr/presentation/staff_directory_screen.dart';
import '../../features/hr/presentation/staff_list_screen.dart';
import '../../features/hr/presentation/staff_detail_screen.dart';
import '../../features/hr/presentation/mark_staff_attendance_screen.dart';
import '../../features/hr/presentation/staff_attendance_report_screen.dart';
import '../../features/fees/presentation/fees_dashboard_screen.dart';
import '../../features/fees/presentation/finance_reports_screen.dart';
import '../../features/chatbot/presentation/chatbot_screen.dart';
import '../../features/profile/presentation/staff_profile_screen.dart';
import '../../features/communicate/presentation/communicate_screen.dart';
import '../../shared/widgets/secure_pdf_viewer_screen.dart';

// Global Key for root navigator
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.value;
  final isLoading = authState.isLoading;
  final perms = ref.watch(permissionProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';

      // While auth is still initializing, stay on the splash screen
      if (isLoading) {
        return isSplash ? null : '/splash';
      }

      final isLoggedIn = user != null;

      // Auth resolved: leave splash
      if (isSplash) {
        return isLoggedIn ? '/dashboard' : '/login';
      }

      // Standard auth guard for all other routes
      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/dashboard';
      return null;
    },
    // A routing miss is almost always a transient auth transition (e.g. a deep
    // route being torn down on logout). Show a calm loader instead of the
    // default "page not found", then re-resolve through the auth guard.
    errorBuilder: (context, state) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/chatbot',
        builder: (context, state) => const ChatbotScreen(),
      ),
      GoRoute(
        path: '/pdf-viewer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return SecurePdfViewerScreen(
            title: extra?['title'] ?? 'PDF Viewer',
            pdfUrl: extra?['pdfUrl'] ?? '',
          );
        },
      ),

      // StatefulShellRoute creates the Bottom Navigation UI
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // Wrap the navigation shell in our custom ScaffoldWithNavBar
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          // ==============================
          // BRANCH 1: Dashboard (Home)
          // ==============================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const StaffDashboardScreen(),
                routes: [
                  // Sub-routes available from the Drawer or Quick Links on the Home tab
                  GoRoute(
                    path: 'self-attendance',
                    builder: (context, state) => const SelfAttendanceScreen(),
                  ),
                  // QR / barcode attendance scanner ("Plan B"). The screen renders a
                  // read-only "no permission" state itself when the operator can mark
                  // neither students nor staff, so the route needs no extra guard.
                  GoRoute(
                    path: 'qr-attendance',
                    builder: (context, state) => const QrScannerScreen(),
                  ),
                  // Gate pass verification. Like the scanner above, the screen
                  // renders its own "no permission" state from the server's
                  // config, so the route needs no extra guard.
                  GoRoute(
                    path: 'gate',
                    builder: (context, state) => const GateScannerScreen(),
                  ),
                  GoRoute(
                    path: 'student-search',
                    builder: (context, state) => const StudentSearchScreen(),
                    routes: [
                      GoRoute(
                        path: 'profile/:studentId',
                        builder: (context, state) {
                          final studentId = int.parse(state.pathParameters['studentId']!);
                          return StudentProfileScreen(studentId: studentId);
                        },
                      ),
                      GoRoute(
                        path: 'without-photo',
                        builder: (context, state) => const StudentsWithoutPhotoScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'attendance',
                    builder: (context, state) => const SelectSectionScreen(),
                    routes: [
                      GoRoute(
                        path: 'take/:sectionId',
                        builder: (context, state) {
                          final sectionId = int.parse(state.pathParameters['sectionId']!);
                          final date = state.uri.queryParameters['date']!;
                          return TakeAttendanceScreen(sectionId: sectionId, date: date);
                        },
                      ),
                      GoRoute(
                        path: 'reports',
                        builder: (context, state) => const StudentAttendanceReportScreen(),
                      )
                    ],
                  ),
                  GoRoute(
                    path: 'homework',
                    builder: (context, state) => const HomeworkListScreen(),
                    routes: [
                      GoRoute(
                        path: 'create',
                        builder: (context, state) => const CreateHomeworkScreen(),
                      ),
                      GoRoute(
                        path: 'details/:homeworkId',
                        builder: (context, state) {
                          final homeworkId = int.parse(state.pathParameters['homeworkId']!);
                          return HomeworkDetailsScreen(homeworkId: homeworkId);
                        },
                      )
                    ],
                  ),
                  GoRoute(
                    path: 'classwork',
                    builder: (context, state) => const ClassworkListScreen(),
                    routes: [
                      GoRoute(
                        path: 'details',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final data = state.extra as Map<String, dynamic>;
                          return ClassworkDetailsScreen(classwork: data);
                        },
                      ),
                      GoRoute(
                        path: 'create',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => const ClassworkFormScreen(),
                      ),
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final data = state.extra as Map<String, dynamic>;
                          return ClassworkFormScreen(initialData: data);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'my-leave',
                    builder: (context, state) => const MyLeaveRequestsScreen(),
                    routes: [
                      GoRoute(
                        path: 'apply',
                        builder: (context, state) => const ApplyForLeaveScreen(),
                      )
                    ],
                  ),
                  GoRoute(
                    path: 'chat',
                    builder: (context, state) => const ChatThreadsScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const ChatContactsScreen(),
                      ),
                      GoRoute(
                        path: 'thread/:threadId',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final threadId =
                              int.parse(state.pathParameters['threadId']!);
                          final extra = state.extra as Map<String, dynamic>?;
                          return ChatThreadScreen(
                            threadId: threadId,
                            title: extra?['title'] as String? ?? 'Conversation',
                            frozen: extra?['frozen'] == true,
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'surveys',
                    builder: (context, state) => const SurveyInboxScreen(),
                    routes: [
                      GoRoute(
                        path: ':token',
                        builder: (context, state) {
                          final token = state.pathParameters['token']!;
                          return SurveyRespondScreen(token: token);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'staff-directory',
                    builder: (context, state) => const StaffDirectoryScreen(),
                  ),
                  GoRoute(
                    path: 'staff-list',
                    builder: (context, state) => const StaffListScreen(),
                    routes: [
                      GoRoute(
                        path: 'detail/:staffId',
                        builder: (context, state) {
                          final staffId = state.pathParameters['staffId']!;
                          return StaffDetailScreen(staffId: staffId);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'exam-marks',
                    builder: (context, state) => const MarksSelectionScreen(),
                  ),
                  GoRoute(
                    path: 'fees-due',
                    builder: (context, state) => const FeesDueScreen(),
                  ),
                  // Admin specific deep links
                  GoRoute(
                    path: 'staff-leave-approval',
                    builder: (context, state) => const AdminLeaveApprovalScreen(),
                  ),
                  GoRoute(
                    path: 'fees-reports',
                    builder: (context, state) => const FeesDashboardScreen(),
                    routes: [
                      GoRoute(
                        path: 'finance-reports',
                        builder: (context, state) => const FinanceReportsScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'mark-staff-attendance',
                    builder: (context, state) => const MarkStaffAttendanceScreen(),
                  ),
                  GoRoute(
                    path: 'communication-log',
                    builder: (context, state) => const CommunicateScreen(),
                  ),
                  GoRoute(
                    path: 'academics',
                    builder: (context, state) => const AcademicsDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'audit-trail',
                    builder: (context, state) => const AuditTrailScreen(),
                  ),
                  GoRoute(
                    path: 'offline-exams',
                    builder: (context, state) => const OfflineExamsDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'transport',
                    builder: (context, state) => const TransportDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'front-office',
                    builder: (context, state) => const FrontOfficeDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'inventory',
                    builder: (context, state) => const InventoryDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'assets',
                    builder: (context, state) => const AssetDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'library',
                    builder: (context, state) => const LibraryDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'hostel',
                    builder: (context, state) => const HostelDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'cbc',
                    builder: (context, state) => const CbcDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'ptm',
                    builder: (context, state) => const PtmDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'ptm/reports',
                    builder: (context, state) => const PtmReportsScreen(),
                  ),
                  GoRoute(
                    path: 'ptm/record',
                    builder: (context, state) => const PtmRecordListScreen(),
                  ),
                  GoRoute(
                    path: 'ptm/record/:meetingId',
                    builder: (context, state) {
                      final meetingIdStr = state.pathParameters['meetingId']!;
                      return PtmRecordRosterScreen(meetingId: int.parse(meetingIdStr));
                    },
                  ),
                  GoRoute(
                    path: 'lesson-plans',
                    builder: (context, state) => const LessonPlanDashboardScreen(),
                  ),
                  // ── Live Classes ───────────────────────────────────
                  GoRoute(
                    path: 'live-classes',
                    builder: (context, state) => const LiveClassListScreen(),
                  ),
                  GoRoute(
                    path: 'live-classes/schedule',
                    builder: (context, state) => const LiveClassFormScreen(),
                  ),
                  GoRoute(
                    path: 'live-classes/:id/edit',
                    // The list passes the already-loaded class through `extra`
                    // so editing does not need a fetch-by-id endpoint.
                    builder: (context, state) =>
                        LiveClassFormScreen(existing: state.extra as LiveClass?),
                  ),
                  // ── Online Exams ───────────────────────────────────
                  // Literal segments before ':examId' so they are not swallowed
                  // by the wildcard — the same ordering rule the API routes have.
                  GoRoute(
                    path: 'online-exams',
                    builder: (context, state) => const OnlineExamDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'online-exams/papers',
                    builder: (context, state) => const OnlineExamListScreen(),
                  ),
                  GoRoute(
                    path: 'online-exams/create',
                    builder: (context, state) => const ExamCreateScreen(),
                  ),
                  GoRoute(
                    path: 'online-exams/marking',
                    builder: (context, state) => const MarkingQueueScreen(),
                  ),
                  GoRoute(
                    path: 'online-exams/marking/:attemptId',
                    builder: (context, state) => MarkAttemptScreen(
                      attemptId: int.parse(state.pathParameters['attemptId']!),
                    ),
                  ),
                  GoRoute(
                    path: 'online-exams/:examId',
                    builder: (context, state) => OnlineExamDetailScreen(
                      examId: int.parse(state.pathParameters['examId']!),
                    ),
                  ),
                  GoRoute(
                    path: 'online-exams/:examId/builder',
                    builder: (context, state) => ExamBuilderScreen(
                      examId: int.parse(state.pathParameters['examId']!),
                    ),
                  ),
                  GoRoute(
                    path: 'online-exams/:examId/questions/:sectionId',
                    builder: (context, state) => QuestionPickerScreen(
                      examId: int.parse(state.pathParameters['examId']!),
                      sectionId: int.parse(state.pathParameters['sectionId']!),
                    ),
                  ),
                  GoRoute(
                    path: 'online-exams/:examId/schedules',
                    builder: (context, state) => ScheduleFormScreen(
                      examId: int.parse(state.pathParameters['examId']!),
                    ),
                  ),
                  // ── Continuous Assessment ──────────────────────────
                  GoRoute(
                    path: 'assessment',
                    builder: (context, state) => const AssessmentDashboardScreen(),
                  ),
                  GoRoute(
                    path: 'assessment/list',
                    builder: (context, state) => const AssessmentListScreen(),
                  ),
                  GoRoute(
                    path: 'assessment/create',
                    builder: (context, state) => const AssessmentFormScreen(),
                  ),
                  GoRoute(
                    path: 'assessment/reports',
                    builder: (context, state) => const AssessmentReportsScreen(),
                  ),
                  GoRoute(
                    path: 'assessment/occurrence/:occId',
                    builder: (context, state) =>
                        MarkEntryScreen(occurrenceId: int.parse(state.pathParameters['occId']!)),
                  ),
                  GoRoute(
                    path: 'assessment/:id/edit',
                    builder: (context, state) =>
                        AssessmentFormScreen(existing: state.extra as AssessmentDetail?),
                  ),
                  GoRoute(
                    path: 'assessment/:id',
                    builder: (context, state) =>
                        AssessmentDetailScreen(assessmentId: int.parse(state.pathParameters['id']!)),
                  ),
                ],
              ),
            ],
          ),

          // ==============================
          // BRANCH 2: Role-based secondary tab
          // ==============================
          // FIXED: Always register both routes unconditionally.
          // The navbar dynamically picks the label/icon, and the screen
          // itself handles role-based content. This avoids the GoRouter
          // crash when conditional branches change at runtime.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/staff-reports',
                builder: (context, state) => const StaffAttendanceReportScreen(),
              ),
              GoRoute(
                path: '/my-timetable',
                builder: (context, state) => const TimetableScreen(),
              ),
            ],
          ),

          // ==============================
          // BRANCH 3: Notices
          // ==============================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notices',
                builder: (context, state) => const NoticeListScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const CreateNoticeScreen(),
                  ),
                  GoRoute(
                    path: 'detail',
                    builder: (context, state) {
                      final notice = state.extra as Map<String, dynamic>;
                      return NoticeDetailScreen(notice: notice);
                    },
                  ),
                ],
              ),
            ],
          ),

          // ==============================
          // BRANCH 4: Profile
          // ==============================
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-profile',
                builder: (context, state) => const StaffProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});