import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/utils/permission_utils.dart';
import '../../data/providers/auth_provider.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final authProvider = context.watch<AuthProvider>();
    final isSuperAdmin = PermissionUtils.isSuperAdmin(authProvider.userRole);

    // Determine current index based on route and role
    int currentIndex = 0;
    if (isSuperAdmin) {
      // Super Admin: Dashboard, Teams, Settings
      if (location == AppRoutes.adminDashboard || location == '/admin') {
        currentIndex = 0;
      } else if (location.contains('/teams') ||
          location.startsWith(AppRoutes.teamManagement)) {
        currentIndex = 1;
      } else if (location.contains('/settings') ||
          location.startsWith(AppRoutes.settings)) {
        currentIndex = 2;
      }
    } else {
      // Member/Team Admin: My Tasks, Teams, Settings
      if (location == '/' || location == AppRoutes.home) {
        currentIndex = 0;
      } else if (location.contains('/teams') ||
          location.startsWith(AppRoutes.teamManagement)) {
        currentIndex = 1;
      } else if (location.contains('/settings') ||
          location.startsWith(AppRoutes.settings)) {
        currentIndex = 2;
      }
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              // Navigate based on role
              if (isSuperAdmin) {
                context.go(AppRoutes.adminDashboard);
              } else {
                context.go(AppRoutes.home);
              }
              break;
            case 1:
              context.go(AppRoutes.teamManagement);
              break;
            case 2:
              context.go(AppRoutes.settings);
              break;
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: isSuperAdmin ? 'Dashboard' : 'My Tasks',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Teams',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
