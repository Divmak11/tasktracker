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

class AllTasksScreen extends StatefulWidget {
  const AllTasksScreen({super.key});

  @override
  State<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends State<AllTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TaskRepository _taskRepository = TaskRepository();
  final UserRepository _userRepository = UserRepository();
  late Stream<List<TaskModel>> _tasksStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tasksStream = _taskRepository.getAllTasksStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TaskModel> _filterTasks(List<TaskModel> tasks, int tabIndex) {
    switch (tabIndex) {
      case 0:
        return tasks; // All
      case 1:
        return tasks.where((t) => t.status == TaskStatus.ongoing).toList();
      case 2:
        return tasks.where((t) => t.status == TaskStatus.completed).toList();
      case 3:
        return tasks.where((t) => t.status == TaskStatus.cancelled).toList();
      default:
        return tasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => setState(() {}),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Ongoing'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _tasksStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Error loading tasks'),
                  const SizedBox(height: AppSpacing.sm),
                  Text('${snapshot.error}', style: theme.textTheme.bodySmall),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTasks = snapshot.data!;
          final filteredTasks = _filterTasks(allTasks, _tabController.index);

          // Sort by deadline (most recent first)
          filteredTasks.sort((a, b) => b.deadline.compareTo(a.deadline));

          if (filteredTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: isDark ? AppColors.neutral600 : AppColors.neutral300,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No Tasks Found',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
            itemCount: filteredTasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final task = filteredTasks[index];
              return _buildTaskCard(context, task, theme, isDark);
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    TaskModel task,
    ThemeData theme,
    bool isDark,
  ) {
    final isOverdue =
        task.status == TaskStatus.ongoing &&
        task.deadline.isBefore(DateTime.now());

    return StreamBuilder<UserModel?>(
      stream: _userRepository.getUserStream(task.assignedTo),
      builder: (context, assigneeSnapshot) {
        final assignee = assigneeSnapshot.data;

        return AppCard(
          type: AppCardType.standard,
          onTap: () => context.push('/task/${task.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge(status: _getStatusType(task.status, isOverdue)),
                  ],
                ),
                if (task.subtitle.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    task.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                // Metadata
                Row(
                  children: [
                    // Assignee
                    Expanded(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage:
                                assignee?.avatarUrl != null
                                    ? NetworkImage(assignee!.avatarUrl!)
                                    : null,
                            child:
                                assignee?.avatarUrl == null
                                    ? Text(
                                      assignee?.name[0] ?? '?',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color:
                                            theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                      ),
                                    )
                                    : null,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              assignee?.name ?? 'Loading...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Deadline
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
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
                            fontWeight: isOverdue ? FontWeight.bold : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
