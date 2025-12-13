import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/approval_repository.dart';
import '../../data/models/task_model.dart';
import '../../data/models/approval_request_model.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/team_repository.dart';
import '../../data/models/user_model.dart';
import '../../data/models/team_model.dart';
import '../../data/providers/auth_provider.dart';
import '../common/cards/app_card.dart';
import 'widgets/export_report_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with AutomaticKeepAliveClientMixin {
  // Cache repositories to avoid recreating on every build
  final UserRepository _userRepository = UserRepository();
  final TeamRepository _teamRepository = TeamRepository();
  final TaskRepository _taskRepository = TaskRepository();
  final ApprovalRepository _approvalRepository = ApprovalRepository();

  // Cache streams to avoid creating new subscriptions
  late final Stream<List<UserModel>> _usersStream;
  late final Stream<List<TeamModel>> _teamsStream;
  late final Stream<List<TaskModel>> _activeTasksStream;
  late final Stream<List<ApprovalRequestModel>> _rescheduleRequestsStream;
  late final Stream<List<TaskModel>> _overdueTasksStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _usersStream = _userRepository.getAllUsersStream();
    _teamsStream = _teamRepository.getAllTeamsStream();
    _activeTasksStream = _taskRepository.getAllActiveTasksStream();
    _rescheduleRequestsStream = _approvalRepository
        .getAllRescheduleRequestsStream(status: ApprovalRequestStatus.pending);
    _overdueTasksStream = _taskRepository.getOverdueTasksStream();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
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

            // Stats Grid with Real-time Data
            StreamBuilder<List<UserModel>>(
              stream: _usersStream,
              builder: (context, usersSnapshot) {
                return StreamBuilder<List<TeamModel>>(
                  stream: _teamsStream,
                  builder: (context, teamsSnapshot) {
                    return StreamBuilder<List<TaskModel>>(
                      stream: _activeTasksStream,
                      builder: (context, tasksSnapshot) {
                        // Calculate metrics
                        final totalUsers = usersSnapshot.data?.length ?? 0;
                        final pendingRequests =
                            usersSnapshot.data
                                ?.where((u) => u.status == UserStatus.pending)
                                .length ??
                            0;
                        final activeTeams = teamsSnapshot.data?.length ?? 0;
                        final activeTasks = tasksSnapshot.data?.length ?? 0;

                        // Show loading state
                        if (!usersSnapshot.hasData ||
                            !teamsSnapshot.hasData ||
                            !tasksSnapshot.hasData) {
                          return _buildStatsGrid(
                            context,
                            screenWidth,
                            isLoading: true,
                          );
                        }

                        return _buildStatsGrid(
                          context,
                          screenWidth,
                          totalUsers: totalUsers,
                          activeTeams: activeTeams,
                          pendingRequests: pendingRequests,
                          activeTasks: activeTasks,
                        );
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Quick Actions
            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Wrap Quick Actions in StreamBuilders for badge counts
            StreamBuilder<List<UserModel>>(
              stream: _usersStream,
              builder: (context, usersSnapshot) {
                final pendingUsers =
                    usersSnapshot.data
                        ?.where((u) => u.status == UserStatus.pending)
                        .length ??
                    0;

                return StreamBuilder<List<ApprovalRequestModel>>(
                  stream: _rescheduleRequestsStream,
                  builder: (context, rescheduleSnapshot) {
                    final pendingReschedules =
                        rescheduleSnapshot.data?.length ?? 0;

                    return StreamBuilder<List<TaskModel>>(
                      stream: _overdueTasksStream,
                      builder: (context, overdueSnapshot) {
                        final overdueTasks = overdueSnapshot.data?.length ?? 0;
                        final currentUser =
                            context.watch<AuthProvider>().currentUser;

                        return StreamBuilder<List<TaskModel>>(
                          stream:
                              currentUser != null
                                  ? _taskRepository.getOngoingTasksStream(
                                    currentUser.id,
                                  )
                                  : const Stream.empty(),
                          builder: (context, myTasksSnapshot) {
                            final myOngoingTasks =
                                myTasksSnapshot.data?.length ?? 0;

                            return Column(
                              children: [
                                _buildActionCard(
                                  context,
                                  'My Tasks',
                                  'View tasks assigned to you',
                                  Icons.assignment_ind_outlined,
                                  () => context.push(AppRoutes.adminMyTasks),
                                  badgeCount: myOngoingTasks,
                                  badgeColor: Colors.blue,
                                ),
                                const SizedBox(height: AppSpacing.md),

                                _buildActionCard(
                                  context,
                                  'Approve Requests',
                                  'Review pending user access requests',
                                  Icons.person_add_alt_1,
                                  () => context.push(AppRoutes.userApproval),
                                  badgeCount: pendingUsers,
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
                                  () => context.push(
                                    AppRoutes.rescheduleApproval,
                                  ),
                                  badgeCount: pendingReschedules,
                                  badgeColor: Colors.orange,
                                ),
                                const SizedBox(height: AppSpacing.md),

                                _buildActionCard(
                                  context,
                                  'Reschedule Log',
                                  'View all reschedule requests history',
                                  Icons.history,
                                  () => context.push(AppRoutes.rescheduleLog),
                                ),
                                const SizedBox(height: AppSpacing.md),

                                _buildActionCard(
                                  context,
                                  'Overdue Tasks',
                                  'View all overdue tasks requiring attention',
                                  Icons.warning_amber_rounded,
                                  () => context.push('/admin/overdue-tasks'),
                                  badgeCount: overdueTasks,
                                  badgeColor: Colors.red,
                                ),
                                const SizedBox(height: AppSpacing.md),

                                _buildActionCard(
                                  context,
                                  'Export Report',
                                  'Generate PDF report with filters',
                                  Icons.picture_as_pdf,
                                  () => showExportReportDialog(context),
                                ),
                                const SizedBox(height: AppSpacing.md),

                                _buildActionCard(
                                  context,
                                  'Invite Users',
                                  'Send email invitations to new users',
                                  Icons.person_add_outlined,
                                  () => context.push(AppRoutes.inviteUsers),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Responsive stats grid that adapts to screen size
  Widget _buildStatsGrid(
    BuildContext context,
    double screenWidth, {
    bool isLoading = false,
    int totalUsers = 0,
    int activeTeams = 0,
    int pendingRequests = 0,
    int activeTasks = 0,
  }) {
    // Calculate responsive aspect ratio based on screen width
    // Lower ratio = taller cards to prevent overflow
    final crossAxisCount = screenWidth > 600 ? 4 : 2;
    final childAspectRatio =
        screenWidth > 600 ? 1.2 : (screenWidth > 400 ? 1.1 : 1.0);

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
          isLoading ? null : '$totalUsers',
          Icons.people_outline,
          onTap: () => context.push(AppRoutes.userManagement),
        ),
        _buildStatCard(
          context,
          'Active Teams',
          isLoading ? null : '$activeTeams',
          Icons.groups_outlined,
          onTap: () => context.push(AppRoutes.teamManagement),
        ),
        _buildStatCard(
          context,
          'Pending Requests',
          isLoading ? null : '$pendingRequests',
          Icons.person_add_outlined,
          onTap: () => context.push(AppRoutes.userApproval),
        ),
        _buildStatCard(
          context,
          'Active Tasks',
          isLoading ? null : '$activeTasks',
          Icons.task_outlined,
          onTap: () => context.push(AppRoutes.allTasks),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String? value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLoading = value == null;

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
              color:
                  isLoading
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (isLoading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
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
            // Icon with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Icon(
                    icon,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                // Badge indicator
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
                        boxShadow: [
                          BoxShadow(
                            color: effectiveBadgeColor.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
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
