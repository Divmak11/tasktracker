import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/data_cache_provider.dart';
import '../common/cards/app_card.dart';
import 'widgets/export_report_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/task/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create Task'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Overview', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),

            // Stats Grid with Real-time Data from Global Cache
            Consumer<DataCacheProvider>(
              builder: (context, cache, _) {
                return _buildStatsGrid(
                  context,
                  screenWidth,
                  totalUsers: cache.totalUsersCount,
                  activeTeams: cache.totalTeamsCount,
                  pendingRequests: cache.pendingUsersCount,
                  activeTasks: cache.activeTasksCount,
                );
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Use DataCacheProvider for Quick Action counts
            Consumer<DataCacheProvider>(
              builder: (context, cache, _) {
                return Column(
                  children: [
                    _buildActionCard(
                      context,
                      'My Tasks',
                      'View tasks assigned to you',
                      Icons.assignment_ind_outlined,
                      () => context.push(AppRoutes.adminMyTasks),
                      badgeCount: cache.adminMyTasksCount,
                      badgeColor: Colors.blue,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildActionCard(
                      context,
                      'Approve Requests',
                      'Review pending user access requests',
                      Icons.person_add_alt_1,
                      () => context.push(AppRoutes.userApproval),
                      badgeCount: cache.pendingUsersCount,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildActionCard(
                      context,
                      'Manage Users',
                      'View and manage all users',
                      Icons.manage_accounts,
                      () => context.push(AppRoutes.userManagement),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildActionCard(
                      context,
                      'Reschedule Requests',
                      'Review pending reschedule requests',
                      Icons.schedule,
                      () => context.push(AppRoutes.rescheduleApproval),
                      badgeCount: cache.adminPendingReschedulesCount,
                      badgeColor: Colors.orange,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildActionCard(
                      context,
                      'Overdue Tasks',
                      'View all tasks that are currently overdue',
                      Icons.notification_important,
                      () => context.push('/admin/overdue-tasks'),
                      badgeCount: cache.adminOverdueTasksCount,
                      badgeColor: Colors.red,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    _buildActionCard(
                      context,
                      'Generate Report',
                      'Export task and user data to PDF/CSV',
                      Icons.summarize_outlined,
                      () => _showExportDialog(context),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ExportReportDialog(),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    double screenWidth, {
    int totalUsers = 0,
    int activeTeams = 0,
    int pendingRequests = 0,
    int activeTasks = 0,
  }) {
    final crossAxisCount = screenWidth > 600 ? 4 : 2;
    final childAspectRatio = screenWidth > 600 ? 1.2 : (screenWidth > 400 ? 1.1 : 1.0);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: childAspectRatio,
      children: [
        _buildStatCard(
          context,
          'Total Users',
          '$totalUsers',
          Icons.people_outline,
          onTap: () => context.push(AppRoutes.userManagement),
        ),
        _buildStatCard(
          context,
          'Active Teams',
          '$activeTeams',
          Icons.groups_outlined,
          onTap: () => context.push(AppRoutes.teamManagement),
        ),
        _buildStatCard(
          context,
          'Pending Requests',
          '$pendingRequests',
          Icons.person_add_outlined,
          onTap: () => context.push(AppRoutes.userApproval),
        ),
        _buildStatCard(
          context,
          'Active Tasks',
          '$activeTasks',
          Icons.task_outlined,
          onTap: () => context.push(AppRoutes.allTasks),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      type: AppCardType.elevated,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    int badgeCount = 0,
    Color? badgeColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final effectiveBadgeColor = badgeColor ?? theme.colorScheme.primary;

    return AppCard(
      type: AppCardType.standard,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: effectiveBadgeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.neutral600 : AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }
}
