import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_erp_staff_app/core/auth/permission_service.dart';

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  /// The navigation shell and container for the branch Navigators.
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar> {
  DateTime? _lastBackPress;

  StatefulNavigationShell get _shell => widget.navigationShell;

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionProvider);

    return PopScope(
      // We own the back gesture so it never silently closes the app from a
      // deep page or a non-Home tab.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        body: _shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _shell.currentIndex,
          onDestinationSelected: (int index) => _onTap(context, index),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home',
            ),

            // DYNAMIC 2nd TAB — driven by permission state, not raw strings
            if (perms.isAdmin)
              const NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: 'Attendance', // Admin views Staff Attendance
              )
            else if (perms.isTeacher)
              const NavigationDestination(
                icon: Icon(Icons.schedule_outlined),
                selectedIcon: Icon(Icons.schedule),
                label: 'Timetable', // Teachers view their Timetable
              )
            else
              const NavigationDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: 'My Logs', // Other staff view their own logs
              ),

            const NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Notices',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  /// Android back: pop within the current tab if possible, otherwise return to
  /// the Home tab, and only exit when already at the dashboard root (with a
  /// double-press confirmation).
  void _handleBack(BuildContext context) {
    final router = GoRouter.of(context);

    // 1. A deeper page inside the current tab — go back one step.
    if (router.canPop()) {
      router.pop();
      return;
    }

    // 2. A secondary tab at its root — jump back to Home.
    if (_shell.currentIndex != 0) {
      _shell.goBranch(0);
      return;
    }

    // 3. Home tab but not the dashboard root (e.g. a go() deep link) — go home.
    final location = GoRouterState.of(context).uri.path;
    if (location != '/dashboard') {
      context.go('/dashboard');
      return;
    }

    // 4. Dashboard root — confirm before exiting.
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)),
      );
      return;
    }
    SystemNavigator.pop();
  }

  void _onTap(BuildContext context, int index) {
    if (index == 1) {
      final perms = ref.read(permissionProvider);
      if (perms.isTeacher && !perms.isAdmin) {
        context.go('/my-timetable');
        return;
      } else {
        context.go('/staff-reports');
        return;
      }
    }

    _shell.goBranch(
      index,
      initialLocation: index == _shell.currentIndex,
    );
  }
}
