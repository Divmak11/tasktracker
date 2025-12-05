import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/signup_screen.dart';
import '../../presentation/auth/request_pending_screen.dart';
import '../../presentation/auth/onboarding_screen.dart';
import '../../presentation/navigation/main_layout.dart';
import '../../presentation/admin/admin_dashboard_screen.dart';
import '../../presentation/admin/team_management_screen.dart';
import '../../presentation/admin/create_team_screen.dart';
import '../../presentation/admin/edit_team_screen.dart';
import '../../presentation/admin/team_detail_screen.dart';
import '../../presentation/admin/approval_queue_screen.dart';
import '../../presentation/admin/user_management_screen.dart';
import '../../presentation/admin/reschedule_log_screen.dart';
import '../../presentation/admin/overdue_tasks_screen.dart';
import '../../presentation/admin/all_tasks_screen.dart';
import '../../presentation/admin/user_task_summary_screen.dart';
import '../../presentation/admin/invite_users_screen.dart';
import '../../presentation/approvals/reschedule_approval_screen.dart';
import '../../presentation/notifications/notification_center_screen.dart';
import '../../presentation/home/home_screen.dart';
import '../../presentation/tasks/create_task_screen.dart';
import '../../presentation/tasks/task_detail_screen.dart';
import '../../presentation/tasks/edit_task_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/settings/theme_selector_screen.dart';
import '../../presentation/settings/profile_edit_screen.dart';
import '../../presentation/settings/notification_preferences_screen.dart';
import '../../presentation/calendar/calendar_view_screen.dart';
import '../constants/app_routes.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/models/user_model.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppRoutes.login,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final currentUser = authProvider.currentUser;
        final isLoading = authProvider.isLoading;

        // Don't redirect while loading
        if (isLoading) return null;

        final isOnLoginPage = state.matchedLocation == AppRoutes.login;
        final isOnPendingPage =
            state.matchedLocation == AppRoutes.requestPending;

        // Not authenticated -> redirect to login
        if (!isAuthenticated) {
          return isOnLoginPage ? null : AppRoutes.login;
        }

        // Authenticated but user data not loaded yet
        if (currentUser == null) {
          return null; // Wait for user data to load
        }

        // Check user status
        if (currentUser.status == UserStatus.pending) {
          return isOnPendingPage ? null : AppRoutes.requestPending;
        }

        if (currentUser.status == UserStatus.revoked) {
          // Force logout if revoked
          authProvider.logout();
          return AppRoutes.login;
        }

        // User is active - redirect from login/pending to appropriate home
        if (isOnLoginPage || isOnPendingPage) {
          // Check if we should show onboarding (could add a flag in user doc)
          if (currentUser.role == UserRole.superAdmin) {
            return AppRoutes.adminDashboard;
          } else {
            return AppRoutes.home;
          }
        }

        return null; // No redirect needed
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.signup,
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: AppRoutes.requestPending,
          builder: (context, state) => const RequestPendingScreen(),
        ),
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        // Authenticated Routes (with Bottom Navigation)
        ShellRoute(
          builder: (context, state, child) => MainLayout(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.adminDashboard,
              builder: (context, state) => const AdminDashboardScreen(),
            ),
            GoRoute(
              path: AppRoutes.teamManagement,
              builder: (context, state) => const TeamManagementScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => const CreateTeamScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return TeamDetailScreen(teamId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        return EditTeamScreen(teamId: id);
                      },
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'theme',
                  builder: (context, state) => const ThemeSelectorScreen(),
                ),
                GoRoute(
                  path: 'profile',
                  builder: (context, state) => const ProfileEditScreen(),
                ),
                GoRoute(
                  path: 'notifications',
                  builder:
                      (context, state) => const NotificationPreferencesScreen(),
                ),
              ],
            ),
            GoRoute(
              path: AppRoutes.userApproval,
              builder: (context, state) => const ApprovalQueueScreen(),
            ),
            GoRoute(
              path: AppRoutes.userManagement,
              builder: (context, state) => const UserManagementScreen(),
            ),
            GoRoute(
              path: AppRoutes.rescheduleLog,
              builder: (context, state) => const RescheduleLogScreen(),
            ),
            GoRoute(
              path: '/admin/overdue-tasks',
              builder: (context, state) => const OverdueTasksScreen(),
            ),
            GoRoute(
              path: AppRoutes.allTasks,
              builder: (context, state) => const AllTasksScreen(),
            ),
            GoRoute(
              path: AppRoutes.inviteUsers,
              builder: (context, state) => const InviteUsersScreen(),
            ),
            GoRoute(
              path: '/admin/users/:id/tasks',
              builder: (context, state) {
                final userId = state.pathParameters['id']!;
                return UserTaskSummaryScreen(userId: userId);
              },
            ),
            GoRoute(
              path: AppRoutes.adminMyTasks,
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: AppRoutes.rescheduleApproval,
              builder: (context, state) => const RescheduleApprovalScreen(),
            ),
            GoRoute(
              path: AppRoutes.notifications,
              builder: (context, state) => const NotificationCenterScreen(),
            ),
            GoRoute(
              path: '/calendar',
              builder: (context, state) => const CalendarViewScreen(),
            ),
            // Member Home (Alternative to Admin Dashboard)
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'task/create',
                  builder: (context, state) => const CreateTaskScreen(),
                ),
                GoRoute(
                  path: 'task/:id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return TaskDetailScreen(taskId: id);
                  },
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) {
                        final id = state.pathParameters['id']!;
                        return EditTaskScreen(taskId: id);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Legacy getter for backward compatibility
  static GoRouter get router =>
      throw UnimplementedError(
        'Use AppRouter.createRouter(authProvider) instead',
      );
}
