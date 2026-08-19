// lib/features/dashboard/presentation/widgets/analytics_widgets.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_erp_staff_app/core/config/app_colors.dart';
import 'package:school_erp_staff_app/core/api/api_providers.dart';
import 'package:school_erp_staff_app/core/api/api_client.dart';
import 'package:school_erp_staff_app/core/auth/app_permission.dart';
import 'package:school_erp_staff_app/core/auth/permission_service.dart';
import 'package:school_erp_staff_app/features/auth/presentation/auth_controller.dart';
import 'package:school_erp_staff_app/features/chat/presentation/chat_providers.dart';

class AnalyticsHeroHeader extends ConsumerWidget {
  final Map<String, dynamic> data;
  const AnalyticsHeroHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionProvider);
    final displayRole = perms.displayRoleName;

    final user = ref.watch(authControllerProvider).value;
    final storageBaseUrl = ref.watch(apiClientProvider).storageBaseUrl;
    final fullPhotoUrl = ApiClient.resolveMedia(storageBaseUrl, user?.profilePhotoUrl);

    final userName = (data['name'] ?? 'Staff Member').toString().toUpperCase();

    return Stack(
      children: [
        // Blue Background with Pattern
        Container(
          width: double.infinity,
          height: 135 + MediaQuery.of(context).padding.top,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary], // Dark navy gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Large overlapping translucent circles
              Positioned(
                top: -30,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(20),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                right: 80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(15),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Foreground Content — vertically centred within the blue band (above
        // the white curve) so the avatar / name / icons look balanced instead
        // of hugging the status bar.
        Positioned.fill(
          bottom: 24,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0, right: 16.0),
              child: Center(
                child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with Hamburger Badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withAlpha(50),
                      backgroundImage: fullPhotoUrl != null ? NetworkImage(fullPhotoUrl) : null,
                      child: fullPhotoUrl == null 
                        ? Text(
                            userName.isNotEmpty ? userName[0] : 'S',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0096C7),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.menu, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                
                // Name and Role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        displayRole,
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Icons (Search, Notifications)
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 28),
                  onPressed: () {
                    final links = AnalyticsQuickLinksRow.getQuickLinks(context, ref, data);
                    showSearch(context: context, delegate: MenuSearchDelegate(allLinks: links));
                  },
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                      onPressed: () => context.go('/notices'),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
          ),
        ),
        
        // White Curved Bottom Overlapping the Blue
        Positioned(
          bottom: -1, // -1 to prevent any 1px gap line
          left: 0,
          right: 0,
          child: Container(
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.background, // Match the scaffold background
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
        ),
      ],
    );
  }
}

class AnalyticsTopMetricsRow extends ConsumerWidget {
  final Map<String, dynamic> data;
  const AnalyticsTopMetricsRow({super.key, required this.data});

  List<_HeroChipData> _getMetrics(PermissionState perms) {
    if (perms.isAdmin) {
      return [
        _HeroChipData(Icons.check_circle_outline, '${data['student_attendance_percentage'] ?? 0}%', 'Attendance'),
        _HeroChipData(Icons.account_balance_wallet_outlined, '${data['currency_symbol'] ?? ''}${data['monthly_fee_collected']?.toStringAsFixed(0) ?? 0}', 'Collected'),
      ];
    } else if (perms.isTeacher) {
      return [
        _HeroChipData(Icons.class_outlined, '${data['classes_today'] ?? 0}', 'Classes'),
        _HeroChipData(Icons.group_outlined, '${data['total_assigned_students'] ?? 0}', 'Students'),
      ];
    } else {
      return [
        _HeroChipData(Icons.fingerprint, '${data['my_attendance_percentage'] ?? 100}%', 'Attendance'),
        _HeroChipData(Icons.check_circle_outline, '${data['my_approved_leave'] ?? 0}', 'Leaves'),
      ];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionProvider);
    final metrics = _getMetrics(perms);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: metrics.map((m) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: m == metrics.last ? 0 : 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(m.icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.value,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.label,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _HeroChipData {
  final IconData icon;
  final String value;
  final String label;
  const _HeroChipData(this.icon, this.value, this.label);
}

class GlassmorphicCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const GlassmorphicCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          splashColor: color.withAlpha((0.3 * 255).round()),
          highlightColor: color.withAlpha((0.1 * 255).round()),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withAlpha((0.15 * 255).round()), color.withAlpha((0.02 * 255).round())],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withAlpha((0.2 * 255).round()), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha((0.05 * 255).round()),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.chevron_right, color: color.withAlpha((0.5 * 255).round()), size: 16),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withAlpha((0.2 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(height: 8), 
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: color.withAlpha((0.9 * 255).round()),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WeeklyTrendChart extends StatelessWidget {
  final List<dynamic> trendData;
  final String title;
  final Color color;
  final bool isPercentage;

  const WeeklyTrendChart({
    super.key,
    required this.trendData,
    required this.title,
    required this.color,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.1 * 255).round()),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white24,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= trendData.length) return const SizedBox();
                        return Text(
                          trendData[value.toInt()]['day'],
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: trendData.asMap().entries.map((e) {
                      final val = isPercentage 
                          ? (e.value['percentage'] ?? 0).toDouble() 
                          : (e.value['amount'] ?? 0).toDouble();
                      return FlSpot(e.key.toDouble(), val);
                    }).toList(),
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: color,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: false, // In the reference dark theme, area is empty
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class AnalyticsQuickLinksRow extends ConsumerWidget {
  final Map<String, dynamic> data;

  const AnalyticsQuickLinksRow({super.key, required this.data});

  static List<QuickLinkItem> getQuickLinks(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final perms = ref.watch(permissionProvider);

    final List<QuickLinkItem> quickLinks = [];

    // --- SELF-SERVICE LINKS ---
    if (perms.can(AppPermission.selfAttendanceView) && !perms.isAdmin) {
      quickLinks.add(QuickLinkItem(icon: Icons.fingerprint, label: 'My Attend.', color: AppColors.iconFgNotices, kind: TileKind.doNow, actionKey: 'self_punch', onTap: () => context.go('/dashboard/self-attendance')));
    }

    // --- ACADEMIC LINKS ---
    if (perms.can(AppPermission.academicsDashboardView)) {
      quickLinks.add(QuickLinkItem(icon: Icons.school_outlined, label: 'Academics', color: AppColors.iconFgStudents, kind: TileKind.browse, onTap: () => context.go('/dashboard/academics')));
    }
    if (perms.can(AppPermission.attendanceTake)) {
      quickLinks.add(QuickLinkItem(icon: Icons.calendar_month_outlined, label: 'Attendance', color: AppColors.iconFgAttendance, kind: TileKind.doNow, actionKey: 'attendance', onTap: () => context.go('/dashboard/attendance')));
    }
    if (perms.canAny({AppPermission.qrAttendanceMark, AppPermission.qrAttendanceMarkOwn})) {
      quickLinks.add(QuickLinkItem(icon: Icons.qr_code_scanner, label: 'Scan Attend.', color: Colors.green, kind: TileKind.doNow, actionKey: 'qr_attendance', onTap: () => context.go('/dashboard/qr-attendance')));
    }
    // Gate pass verification — gated on `verify`, not `view`: a class teacher holds
    // view and must not be handed the gate scanner.
    if (perms.can(AppPermission.gatePassVerify)) {
      quickLinks.add(QuickLinkItem(icon: Icons.door_front_door_outlined, label: 'Gate', color: Colors.indigo, kind: TileKind.doNow, actionKey: 'gate_pass', onTap: () => context.go('/dashboard/gate')));
    }
    if (perms.can(AppPermission.liveClassView)) {
      quickLinks.add(QuickLinkItem(icon: Icons.videocam_outlined, label: 'Live Class', color: Colors.teal, kind: TileKind.doNow, onTap: () => context.go('/dashboard/live-classes')));
    }
    if (perms.can(AppPermission.examMarksEntry)) {
      quickLinks.add(QuickLinkItem(icon: Icons.grading_outlined, label: 'Marks', color: AppColors.iconFgHomework, onTap: () => context.go('/dashboard/exam-marks')));
      quickLinks.add(QuickLinkItem(icon: Icons.bar_chart, label: 'Exams', color: AppColors.iconFgHomework, kind: TileKind.browse, onTap: () => context.go('/dashboard/offline-exams')));
    }
    if (perms.can(AppPermission.onlineExamManage)) {
      // doNow + an actionKey, because unmarked written answers hold whole
      // attempts in "pending review" — the badge is the point, not the link.
      quickLinks.add(QuickLinkItem(icon: Icons.quiz_outlined, label: 'Online Exams', color: Colors.deepPurple, kind: TileKind.doNow, actionKey: 'online_exam_marking', onTap: () => context.go('/dashboard/online-exams')));
    }
    if (perms.can(AppPermission.transportManage)) {
      quickLinks.add(QuickLinkItem(icon: Icons.directions_bus, label: 'Transport', color: AppColors.iconFgTimetable, kind: TileKind.browse, onTap: () => context.go('/dashboard/transport')));
    }
    
    if (perms.can(AppPermission.frontOfficeManage)) {
      quickLinks.add(QuickLinkItem(icon: Icons.business, label: 'Front Office', color: Colors.blue, onTap: () => context.go('/dashboard/front-office')));
    }

    if (perms.can(AppPermission.inventoryDashboardView)) {
      quickLinks.add(QuickLinkItem(icon: Icons.inventory_2, label: 'Inventory', color: Colors.indigo, kind: TileKind.browse, onTap: () => context.go('/dashboard/inventory')));
    }

    if (perms.can(AppPermission.assetDashboardView)) {
      quickLinks.add(QuickLinkItem(icon: Icons.business_center, label: 'Assets', color: Colors.blueGrey, kind: TileKind.browse, onTap: () => context.go('/dashboard/assets')));
    }

    if (perms.can(AppPermission.libraryManage)) {
      quickLinks.add(QuickLinkItem(icon: Icons.local_library, label: 'Library', color: Colors.indigo, kind: TileKind.browse, onTap: () => context.go('/dashboard/library')));
    }

    if (perms.can(AppPermission.hostelManage)) {
      quickLinks.add(QuickLinkItem(icon: Icons.apartment, label: 'Hostel', color: Colors.orange, kind: TileKind.browse, onTap: () => context.go('/dashboard/hostel')));
    }

    if (perms.can(AppPermission.cbcManage)) {
      quickLinks.add(QuickLinkItem(icon: Icons.account_tree, label: 'CBC', color: Colors.teal, kind: TileKind.browse, onTap: () => context.go('/dashboard/cbc')));
    }

    if (perms.can(AppPermission.ptmManage) || perms.can(AppPermission.ptmAttendanceManage) || perms.can(AppPermission.ptmRemarkManage)) {
      quickLinks.add(QuickLinkItem(icon: Icons.handshake, label: 'PTM Meetings', color: Colors.indigo, onTap: () => context.go('/dashboard/ptm')));
    }

    if (perms.can(AppPermission.lessonPlanManage)) {
      quickLinks.add(QuickLinkItem(icon: Icons.menu_book, label: 'Lesson Planner', color: Colors.blueGrey, kind: TileKind.browse, onTap: () => context.go('/dashboard/lesson-plans')));
    }

    if (perms.can(AppPermission.assessmentDashboardView)) {
      quickLinks.add(QuickLinkItem(icon: Icons.fact_check_outlined, label: 'Assessment', color: Colors.deepPurple, onTap: () => context.go('/dashboard/assessment')));
    }

    if (perms.canAny({AppPermission.feesDueView, AppPermission.feesDueViewOwn})) {
      quickLinks.add(QuickLinkItem(icon: Icons.payments_outlined, label: 'Fees Due', color: Colors.red, kind: TileKind.browse, onTap: () => context.go('/dashboard/fees-due')));
    }

    if (perms.can(AppPermission.hrStaffAttendanceMark)) {
      quickLinks.add(QuickLinkItem(icon: Icons.how_to_reg_outlined, label: 'Staff Attend.', color: AppColors.accent, kind: TileKind.doNow, onTap: () => context.go('/dashboard/mark-staff-attendance')));
    } else if (perms.can(AppPermission.homeworkManage) && perms.isTeacher) {
      quickLinks.add(QuickLinkItem(icon: Icons.edit_document, label: 'Homework', color: AppColors.accent, kind: TileKind.doNow, actionKey: 'homework', onTap: () => context.go('/dashboard/homework')));
      quickLinks.add(QuickLinkItem(icon: Icons.menu_book, label: 'Classwork', color: Colors.green, onTap: () => context.go('/dashboard/classwork')));
    }

    // --- MANAGEMENT LINKS ---
    if (perms.can(AppPermission.studentView)) {
      quickLinks.add(QuickLinkItem(icon: Icons.person_search, label: 'Students', color: AppColors.iconFgStudents, kind: TileKind.browse, onTap: () => context.go('/dashboard/student-search')));
    }
    if (perms.can(AppPermission.hrStaffView)) {
      quickLinks.add(QuickLinkItem(icon: Icons.badge_outlined, label: 'Staff List', color: AppColors.iconFgStaff, kind: TileKind.browse, onTap: () => context.go('/dashboard/staff-list')));
    }
    
    // --- PERSONAL / HR LINKS ---
    if (perms.can(AppPermission.hrStaffAttendanceReport)) {
      quickLinks.add(QuickLinkItem(icon: Icons.analytics_outlined, label: 'Logs', color: AppColors.iconFgChatbot, kind: TileKind.report, onTap: () => context.go('/staff-reports')));
    } else if (perms.can(AppPermission.selfAttendanceView)) {
      quickLinks.add(QuickLinkItem(icon: Icons.analytics_outlined, label: 'My Logs', color: AppColors.iconFgChatbot, kind: TileKind.report, onTap: () => context.go('/staff-reports')));
    }
    if (perms.can(AppPermission.selfLeaveApply)) {
      quickLinks.add(QuickLinkItem(icon: Icons.check_circle_outline, label: 'Leaves', color: AppColors.iconFgLeave, onTap: () => context.go('/dashboard/my-leave')));
    }
    if (perms.can(AppPermission.hrLeaveApprove)) {
      quickLinks.add(QuickLinkItem(icon: Icons.approval_outlined, label: 'Staff Leave', color: AppColors.accent, kind: TileKind.doNow, actionKey: 'approvals', onTap: () => context.go('/dashboard/staff-leave-approval')));
    }
    quickLinks.add(QuickLinkItem(icon: Icons.person_outline, label: 'Profile', color: AppColors.iconFgProfile, onTap: () => context.go('/my-profile')));

    if (perms.can(AppPermission.timetableView) && perms.isTeacher) {
      quickLinks.add(QuickLinkItem(icon: Icons.schedule, label: 'Timetable', color: AppColors.iconFgTimetable, onTap: () => context.go('/my-timetable')));
    }
    if (perms.can(AppPermission.feesViewReport)) {
      quickLinks.add(QuickLinkItem(icon: Icons.account_balance_wallet_outlined, label: 'Fees', color: AppColors.iconFgFees, kind: TileKind.report, onTap: () => context.go('/dashboard/fees-reports')));
    }

    // --- COMMUNICATION LINKS ---
    // Chat entry is config-gated (school toggle + plan), not permission-gated.
    if (ref.watch(chatConfigProvider).valueOrNull?.enabled == true) {
      quickLinks.add(QuickLinkItem(icon: Icons.forum_outlined, label: 'Messages', color: AppColors.iconFgComms, kind: TileKind.doNow, onTap: () => context.go('/dashboard/chat')));
    }
    if (perms.can(AppPermission.communicationLogView)) {
      quickLinks.add(QuickLinkItem(icon: Icons.history, label: 'Comm. Log', color: AppColors.iconFgComms, kind: TileKind.report, onTap: () => context.go('/dashboard/communication-log')));
    }

    // --- SYSTEM LINKS ---
    if (perms.can(AppPermission.systemAuditTrailView)) {
      quickLinks.add(QuickLinkItem(icon: Icons.admin_panel_settings_outlined, label: 'Audit Trail', color: AppColors.iconFgChatbot, kind: TileKind.report, onTap: () => context.go('/dashboard/audit-trail')));
    }
    quickLinks.add(QuickLinkItem(icon: Icons.campaign_outlined, label: 'Notices', color: AppColors.iconFgComms, onTap: () => context.go('/notices')));
    quickLinks.add(QuickLinkItem(icon: Icons.poll_outlined, label: 'Surveys', color: AppColors.iconFgSurvey, onTap: () => context.go('/dashboard/surveys')));

    return quickLinks;
  }

  /// Pending counts keyed by `action_key`, from the dashboard payload.
  static Map<String, int> _pendingCounts(Map<String, dynamic> data) {
    final raw = data['action_center'];
    if (raw is! List) return const {};

    final counts = <String, int>{};
    for (final entry in raw) {
      if (entry is Map && entry['key'] is String) {
        final count = entry['count'];
        if (count is int && count > 0) counts[entry['key'] as String] = count;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quickLinks = getQuickLinks(context, ref, data);
    final counts = _pendingCounts(data);

    // Section membership is static — a tile does not move between sections as
    // counts change, because a grid that reshuffles daily is harder to learn
    // than one that stays put. Counts only drive the badge.
    final today = quickLinks
        .where((l) => l.kind == TileKind.doNow)
        .map((l) {
          final n = l.actionKey == null ? null : counts[l.actionKey];
          return n == null ? l : l.withBadge('$n');
        })
        .toList();
    final manage = quickLinks.where((l) => l.kind == TileKind.manage).toList();
    final browse = quickLinks.where((l) => l.kind == TileKind.browse).toList();
    final reports = quickLinks.where((l) => l.kind == TileKind.report).toList();

    final pendingTotal = counts.values.fold<int>(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 4;

          // Stagger runs across the whole screen, not per section, so the
          // reveal still reads as one sweep.
          var revealIndex = 0;

          final sections = <({Widget header, List<QuickLinkItem> tiles})>[
            if (today.isNotEmpty)
              (
                header: _SectionHeader(
                  title: 'Today',
                  trailing: pendingTotal > 0 ? '$pendingTotal pending' : null,
                ),
                tiles: today,
              ),
            if (manage.isNotEmpty)
              (header: const _SectionHeader(title: 'Manage'), tiles: manage),
            if (browse.isNotEmpty)
              (
                header: const _SectionHeader(
                  title: 'Browse',
                  subtitle: 'view only',
                  icon: Icons.visibility_outlined,
                ),
                tiles: browse,
              ),
            if (reports.isNotEmpty)
              (
                header: const _SectionHeader(
                  title: 'Reports and records',
                  subtitle: 'view only',
                  icon: Icons.visibility_outlined,
                ),
                tiles: reports,
              ),
          ];

          Widget tileBox(QuickLinkItem item) => SizedBox(
                width: itemWidth,
                child: _StaggeredReveal(index: revealIndex++, child: item),
              );

          // Continuous fill: a section's ragged last row is completed by
          // borrowing the leading tiles of the NEXT section, so the grid reads
          // as full from the top down (no empty cells on login). The borrowed
          // tiles sit under the previous header — a deliberate, accepted
          // trade: a full grid beats a strictly-labelled one for first
          // impression. Only the very last row of the whole grid can be ragged.
          const cols = 4;
          final flow = <Widget>[];
          var col = 0;
          var isFirst = true;

          for (final section in sections) {
            var tiles = section.tiles;

            // Backfill the previous row before starting a new header.
            if (col != 0) {
              final need = cols - col;
              final take = tiles.length < need ? tiles.length : need;
              for (var i = 0; i < take; i++) {
                flow.add(tileBox(tiles[i]));
              }
              tiles = tiles.sublist(take);
              col = (col + take) % cols;
            }

            // If borrowing consumed the whole section, it has no header of its
            // own — its tiles simply extended the previous section.
            if (tiles.isEmpty) continue;

            flow.add(SizedBox(
              width: constraints.maxWidth,
              child: Padding(
                padding: EdgeInsets.only(top: isFirst ? 0 : 8),
                child: section.header,
              ),
            ));
            isFirst = false;
            col = 0;

            for (final item in tiles) {
              flow.add(tileBox(item));
              col = (col + 1) % cols;
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(runSpacing: 20.0, children: flow),
              const SizedBox(height: 24),
              Center(
                child: TextButton.icon(
                  onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
                  label: const Text('Log out', style: TextStyle(color: AppColors.error)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Section divider for the quick-links grid. Carries the label that tells the
/// user what kind of thing sits below it.
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailing;
  final IconData? icon;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          const Spacer(),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trailing!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What a tile *does*, which drives both which section it lands in and how it
/// is painted. The visual weight is deliberate: solid tiles demand action,
/// tinted tiles are places to work, drained tiles are read-only lookups that
/// should not compete for attention.
enum TileKind {
  /// Something owed today. Promoted into the Today strip when it has a count.
  doNow,

  /// A module hub — contains both doing and viewing behind it.
  manage,

  /// A live module you can only browse on mobile — no data entry here (editing
  /// lives on the web panel). Coloured like Manage but sits flat, and lives
  /// under the "Browse · view only" header.
  browse,

  /// Read-only. Nothing here changes data.
  report,
}

/// A dashboard quick-link. The staff app's signature feel: a soft 3D/floating
/// icon (gradient + depth shadow + glossy edge) that physically "pops" on
/// press — distinct from the parent app's shimmer.
class QuickLinkItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? badge;
  final TileKind kind;

  /// Matches a `key` in the API's `action_center` list. When the backend
  /// reports a non-zero count for this key the tile is promoted into Today
  /// and shows the count as a badge.
  final String? actionKey;

  const QuickLinkItem({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badge,
    this.kind = TileKind.manage,
    this.actionKey,
  });

  /// Copy carrying a resolved pending count through as the badge.
  QuickLinkItem withBadge(String? value) => QuickLinkItem(
        icon: icon,
        label: label,
        color: color,
        onTap: onTap,
        badge: value,
        kind: kind,
        actionKey: actionKey,
      );

  @override
  State<QuickLinkItem> createState() => _QuickLinkItemState();
}

class _QuickLinkItemState extends State<QuickLinkItem> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final isDoNow = widget.kind == TileKind.doNow;
    final isReport = widget.kind == TileKind.report;
    // Browse tiles keep their module colour (so the module stays recognisable)
    // but sit flat like reports — flatness is the "not actionable" cue.
    final isBrowse = widget.kind == TileKind.browse;

    // Read-only tiles are drained of colour so they stop competing with the
    // things that actually need doing — the single biggest readability win on
    // this screen. Do-now tiles invert to a solid fill to pull the eye first.
    final Color iconColor = isDoNow
        ? Colors.white
        : isReport
            ? AppColors.textSecondary
            : color;

    Widget iconWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDoNow ? color : null,
        gradient: isDoNow
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isReport
                    ? [
                        AppColors.textSecondary.withValues(alpha: 0.08),
                        AppColors.textSecondary.withValues(alpha: 0.04),
                      ]
                    : [color.withValues(alpha: 0.22), color.withValues(alpha: 0.10)],
              ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReport
              ? AppColors.textSecondary.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.55),
          width: isReport ? 0.8 : 0.6,
        ),
        // Read-only tiles sit flat on the page; only actionable tiles float.
        boxShadow: (isReport || isBrowse)
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: _pressed ? 0.30 : (isDoNow ? 0.26 : 0.18)),
                  blurRadius: _pressed ? 5 : 14,
                  offset: Offset(0, _pressed ? 2 : 7),
                ),
              ],
      ),
      child: Icon(widget.icon, color: iconColor, size: 26),
    );

    if (widget.badge != null && widget.badge != '0' && widget.badge!.isNotEmpty) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Text(
                widget.badge!,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap();
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.86 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            const SizedBox(height: 8),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isReport ? FontWeight.w500 : FontWeight.w700,
                color: isReport ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-shot staggered entrance: tiles fade + scale + rise into place, each a
/// beat after the previous, for a premium "deal the cards" reveal.
class _StaggeredReveal extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggeredReveal({required this.index, required this.child});

  @override
  State<_StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<_StaggeredReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    // Cap the cumulative delay so a long grid still finishes quickly.
    final delayMs = (widget.index * 28).clamp(0, 600);
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final v = _curve.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 14),
            child: Transform.scale(scale: 0.85 + (0.15 * v), child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

class MenuSearchDelegate extends SearchDelegate<String> {
  final List<QuickLinkItem> allLinks;

  MenuSearchDelegate({required this.allLinks}) : super(searchFieldLabel: 'Search menus...');

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final results = allLinks
        .where((link) => link.label.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (results.isEmpty) {
      return const Center(child: Text('No menus match your search.'));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 4;
          return Wrap(
            runSpacing: 20.0,
            alignment: WrapAlignment.start,
            children: results.map((link) {
              return SizedBox(
                width: itemWidth,
                child: QuickLinkItem(
                  icon: link.icon,
                  label: link.label,
                  color: link.color,
                  badge: link.badge,
                  onTap: () {
                    close(context, link.label);
                    link.onTap();
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
