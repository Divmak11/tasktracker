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
import '../../data/repositories/notification_repository.dart';
import '../common/cards/app_card.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen>
    with AutomaticKeepAliveClientMixin {
  final TaskRepository _taskRepository = TaskRepository();
  final ApprovalRepository _approvalRepository = ApprovalRepository();
  final NotificationRepository _notificationRepository =
      NotificationRepository();

  // Cache streams
  late final Stream<List<TaskModel>> _ongoingAssignedStream;
  late final Stream<List<TaskModel>> _activeCreatedStream;
  late final Stream<List<TaskModel>> _overdueTasksStream;
  late final Stream<List<TaskModel>> _completedTasksStream;
  late final Stream<List<ApprovalRequestModel>> _pendingReschedulesStream;
  late final Stream<int> _unreadCountStream;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      // Filter out self-assigned tasks and overdue tasks (they go to Overdue tab)
      _ongoingAssignedStream = _taskRepository
          .getOngoingAssignedTasksStream(currentUser.id)
          .map((tasks) => tasks
              .where((t) => t.createdBy != currentUser.id && !t.isOverdue)
              .toList());
      // Filter out overdue tasks (they go to Overdue tab)
      _activeCreatedStream = _taskRepository
          .getCreatedTasksStream(currentUser.id)
          .map((tasks) =>
              tasks.where((t) => t.status == TaskStatus.ongoing && !t.isOverdue).toList());
      // Overdue should also exclude self-assigned for consistency
      _overdueTasksStream = _taskRepository
          .getUserCalendarTasksStream(currentUser.id)
          .map((tasks) => tasks
              .where((t) => t.status == TaskStatus.ongoing && t.isOverdue)
              .toList());
      _completedTasksStream =
          _taskRepository.getPastAssignedTasksStream(currentUser.id);
      _pendingReschedulesStream =
          _approvalRepository.getPendingRescheduleRequestsStream(currentUser.id);
      _unreadCountStream =
          _notificationRepository.getUnreadCountStream(currentUser.id);
    }
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
          StreamBuilder<List<ApprovalRequestModel>>(
            stream: _pendingReschedulesStream,
            builder: (context, snapshot) {
              final pendingCount = snapshot.data?.length ?? 0;
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
          StreamBuilder<int>(
            stream: _unreadCountStream,
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
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

            // Quick Actions with real-time badge counts
            StreamBuilder<List<TaskModel>>(
              stream: _ongoingAssignedStream,
              builder: (context, assignedSnapshot) {
                return StreamBuilder<List<TaskModel>>(
                  stream: _activeCreatedStream,
                  builder: (context, createdSnapshot) {
                    return StreamBuilder<List<TaskModel>>(
                      stream: _overdueTasksStream,
                      builder: (context, overdueSnapshot) {
                        return StreamBuilder<List<TaskModel>>(
                          stream: _completedTasksStream,
                          builder: (context, completedSnapshot) {
                            final assignedCount =
                                assignedSnapshot.data?.length ?? 0;
                            final createdCount =
                                createdSnapshot.data?.length ?? 0;
                            final overdueCount =
                                overdueSnapshot.data?.length ?? 0;
                            final completedCount =
                                completedSnapshot.data?.length ?? 0;

                            return Column(
                              children: [
                                _buildActionCard(
                                  context,
                                  'Ongoing Tasks (Assigned)',
                                  'View tasks assigned to you',
                                  Icons.assignment_ind_outlined,
                                  () => context.push('/home/assigned-tasks'),
                                  badgeCount: assignedCount,
                                  badgeColor: Colors.blue,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _buildActionCard(
                                  context,
                                  'Ongoing Tasks (Created)',
                                  'Tasks you created that are ongoing',
                                  Icons.create_outlined,
                                  () => context.push('/home/created-tasks'),
                                  badgeCount: createdCount,
                                  badgeColor: Colors.green,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _buildActionCard(
                                  context,
                                  'Overdue Tasks',
                                  'Tasks that require immediate attention',
                                  Icons.warning_amber_rounded,
                                  () => context.push('/home/overdue-tasks'),
                                  badgeCount: overdueCount,
                                  badgeColor: Colors.red,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                _buildActionCard(
                                  context,
                                  'Completed Tasks',
                                  'View your completed tasks',
                                  Icons.check_circle_outline,
                                  () => context.push('/home/completed-tasks'),
                                  badgeCount: completedCount,
                                  badgeColor: Colors.grey,
                                ),
                                // Team Admin only: Create Team
                                if (currentUser.role == UserRole.teamAdmin) ...[
                                  const SizedBox(height: AppSpacing.md),
                                  _buildActionCard(
                                    context,
                                    'Create Team',
                                    'Create a new team',
                                    Icons.group_add,
                                    () => context.push('/admin/teams/create'),
                                  ),
                                ],
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
            // Icon
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
                      color: effectiveBadgeColor.withValues(alpha: 0.2),
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
              const SizedBox(width: AppSpacing.md),
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
