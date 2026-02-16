import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/approval_repository.dart';
import '../../data/models/task_model.dart';
import '../../data/models/approval_request_model.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/data_cache_provider.dart';
import '../../data/repositories/notification_repository.dart';
import '../common/cards/app_card.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen>
    with AutomaticKeepAliveClientMixin {
  // Repositories
  // These repositories are now primarily used by DataCacheProvider internally,
  // but kept here if any direct calls are still needed (e.g., for specific screens).
  final TaskRepository _taskRepository = TaskRepository();
  final ApprovalRepository _approvalRepository = ApprovalRepository();
  final NotificationRepository _notificationRepository =
      NotificationRepository();

  // Counters are now managed globally by DataCacheProvider to prevent flicker
  
  @override
  bool get wantKeepAlive => true;

  // Computed stream getters for real-time updates
  // These streams are now primarily consumed by DataCacheProvider.
  Stream<List<TaskModel>> _getOngoingAssignedStream(String userId) {
    // Filter out self-assigned tasks and overdue tasks (they go to Overdue tab)
    return _taskRepository
        .getOngoingAssignedTasksStream(userId)
        .map((tasks) => tasks
            .where((t) => t.createdBy != userId && !t.isOverdue)
            .toList());
  }

  Stream<List<TaskModel>> _getActiveCreatedStream(String userId) {
    // Filter out overdue tasks (they go to Overdue tab)
    return _taskRepository
        .getCreatedTasksStream(userId)
        .map((tasks) =>
            tasks.where((t) => t.status == TaskStatus.ongoing && !t.isOverdue).toList());
  }

  Stream<List<TaskModel>> _getOverdueTasksStream(String userId) {
    // Include both assigned AND created overdue tasks
    return _taskRepository
        .getUserCalendarTasksStream(userId)
        .map((tasks) => tasks
            .where((t) => t.status == TaskStatus.ongoing && t.isOverdue)
            .toList());
  }

  Stream<List<TaskModel>> _getCompletedTasksStream(String userId) {
    return _taskRepository.getPastAssignedTasksStream(userId);
  }

  Stream<List<ApprovalRequestModel>> _getPendingReschedulesStream(String userId) {
    return _approvalRepository.getPendingRescheduleRequestsStream(userId);
  }

  Stream<int> _getUnreadCountStream(String userId) {
    return _notificationRepository.getUnreadCountStream(userId);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final currentUser = context.watch<AuthProvider>().currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Calendar View',
            onPressed: () => context.push('/calendar'),
          ),
          Consumer<DataCacheProvider>(
            builder: (context, cache, _) {
              final pendingCount = cache.pendingReschedulesCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.schedule),
                    tooltip: 'Reschedule Requests',
                    onPressed: () => context.push(AppRoutes.rescheduleApproval),
                  ),
                  if (pendingCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          pendingCount > 9 ? '9+' : '$pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Consumer<DataCacheProvider>(
            builder: (context, cache, _) {
              final unreadCount = cache.unreadCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => context.push(AppRoutes.notifications),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
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
            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Quick Actions with badge counts from Global Cache
            Consumer<DataCacheProvider>(
              builder: (context, cache, _) {
                return Column(
                  children: [
                    _buildActionCard(
                      context,
                      'Ongoing Tasks (Assigned)',
                      'View tasks assigned to you',
                      Icons.assignment_ind_outlined,
                      () => context.push('/home/assigned-tasks'),
                      badgeCount: cache.assignedCount,
                      badgeColor: Colors.blue,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildActionCard(
                      context,
                      'Ongoing Tasks (Created)',
                      'View tasks you created',
                      Icons.add_task_outlined,
                      () => context.push('/home/created-tasks'),
                      badgeCount: cache.createdCount,
                      badgeColor: Colors.green,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildActionCard(
                      context,
                      'Overdue Tasks',
                      'Tasks past their deadline',
                      Icons.running_with_errors_outlined,
                      () => context.push('/home/overdue-tasks'),
                      badgeCount: cache.overdueCount,
                      badgeColor: Colors.red,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildActionCard(
                      context,
                      'Past/Completed Tasks',
                      'History of completed tasks',
                      Icons.history_outlined,
                      () => context.push('/home/completed-tasks'),
                      badgeCount: cache.completedCount,
                      badgeColor: Colors.grey,
                    ),
                    // Team Admin only: Team Admin Panel
                    if (currentUser.role == UserRole.teamAdmin) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _buildActionCard(
                        context,
                        'Team Admin Panel',
                        'View team analytics & manage your team',
                        Icons.admin_panel_settings_outlined,
                        () => context.push(AppRoutes.teamAdminDashboard),
                      ),
                    ],
                  ],
                );
              },
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDark ? theme.colorScheme.primaryContainer : theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(
                icon,
                color: isDark ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
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
            // Badge indicator repositioned to right side
            if (badgeCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: effectiveBadgeColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: effectiveBadgeColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 24),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
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
