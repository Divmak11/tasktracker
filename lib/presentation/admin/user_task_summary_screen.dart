import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../common/cards/app_card.dart';
import '../common/badges/status_badge.dart';

class UserTaskSummaryScreen extends StatefulWidget {
  final String userId;

  const UserTaskSummaryScreen({super.key, required this.userId});

  @override
  State<UserTaskSummaryScreen> createState() => _UserTaskSummaryScreenState();
}

class _UserTaskSummaryScreenState extends State<UserTaskSummaryScreen> {
  final TaskRepository _taskRepository = TaskRepository();
  final UserRepository _userRepository = UserRepository();
  late Stream<UserModel?> _userStream;
  late Stream<List<TaskModel>> _tasksStream;

  @override
  void initState() {
    super.initState();
    _userStream = _userRepository.getUserStream(widget.userId);
    _tasksStream = _taskRepository.getUserTasksStream(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<UserModel?>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        final user = userSnapshot.data;

        return Scaffold(
          appBar: AppBar(title: Text(user?.name ?? 'User Tasks')),
          body: StreamBuilder<List<TaskModel>>(
            stream: _tasksStream,
            builder: (context, tasksSnapshot) {
              if (tasksSnapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text('Error loading tasks'),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${tasksSnapshot.error}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }

              if (!tasksSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tasks = tasksSnapshot.data!;
              final ongoingTasks =
                  tasks.where((t) => t.status == TaskStatus.ongoing).toList();
              final completedTasks =
                  tasks.where((t) => t.status == TaskStatus.completed).toList();
              final overdueTasks =
                  ongoingTasks
                      .where((t) => t.deadline.isBefore(DateTime.now()))
                      .toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User Info Card
                    if (user != null)
                      _buildUserInfoCard(context, user, theme, isDark),
                    const SizedBox(height: AppSpacing.lg),

                    // Stats Summary
                    _buildStatsSummary(
                      context,
                      theme,
                      isDark,
                      totalTasks: tasks.length,
                      ongoingTasks: ongoingTasks.length,
                      completedTasks: completedTasks.length,
                      overdueTasks: overdueTasks.length,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Task List
                    Text(
                      'All Tasks (${tasks.length})',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (tasks.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color:
                                    isDark
                                        ? AppColors.neutral600
                                        : AppColors.neutral300,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No tasks assigned',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color:
                                      isDark
                                          ? AppColors.neutral400
                                          : AppColors.neutral600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tasks.length,
                        separatorBuilder:
                            (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildTaskItem(context, task, theme, isDark);
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildUserInfoCard(
    BuildContext context,
    UserModel user,
    ThemeData theme,
    bool isDark,
  ) {
    return AppCard(
      type: AppCardType.elevated,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child:
                  user.avatarUrl == null
                      ? Text(
                        user.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      user.role.name.replaceAll('_', ' ').toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary(
    BuildContext context,
    ThemeData theme,
    bool isDark, {
    required int totalTasks,
    required int ongoingTasks,
    required int completedTasks,
    required int overdueTasks,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            theme,
            isDark,
            'Total',
            '$totalTasks',
            Icons.assignment_outlined,
            theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatItem(
            theme,
            isDark,
            'Ongoing',
            '$ongoingTasks',
            Icons.access_time_rounded,
            Colors.blue,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatItem(
            theme,
            isDark,
            'Done',
            '$completedTasks',
            Icons.check_circle_outline,
            Colors.green,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _buildStatItem(
            theme,
            isDark,
            'Overdue',
            '$overdueTasks',
            Icons.warning_amber_rounded,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    ThemeData theme,
    bool isDark,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return AppCard(
      type: AppCardType.standard,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isDark ? AppColors.neutral500 : AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(
    BuildContext context,
    TaskModel task,
    ThemeData theme,
    bool isDark,
  ) {
    final isOverdue =
        task.status == TaskStatus.ongoing &&
        task.deadline.isBefore(DateTime.now());

    return AppCard(
      type: AppCardType.standard,
      onTap: () => context.push('/task/${task.id}'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color:
                          isOverdue
                              ? Colors.red
                              : (isDark
                                  ? AppColors.neutral500
                                  : AppColors.neutral500),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(task.deadline),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            isOverdue
                                ? Colors.red
                                : (isDark
                                    ? AppColors.neutral500
                                    : AppColors.neutral500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          StatusBadge(status: _getStatusType(task.status, isOverdue)),
        ],
      ),
    );
  }

  StatusType _getStatusType(TaskStatus status, bool isOverdue) {
    if (isOverdue) return StatusType.overdue;
    switch (status) {
      case TaskStatus.ongoing:
        return StatusType.ongoing;
      case TaskStatus.completed:
        return StatusType.completed;
      case TaskStatus.cancelled:
        return StatusType.cancelled;
    }
  }
}
