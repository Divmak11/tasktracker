import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/data_cache_provider.dart';
import '../../data/repositories/task_repository.dart';
import '../home/widgets/task_card.dart';

class FilteredTasksScreen extends StatefulWidget {
  final String filterType; // 'assigned', 'created', 'overdue', 'completed'

  const FilteredTasksScreen({super.key, required this.filterType});

  @override
  State<FilteredTasksScreen> createState() => _FilteredTasksScreenState();
}

class _FilteredTasksScreenState extends State<FilteredTasksScreen> {
  final TaskRepository _taskRepository = TaskRepository();

  String get _title {
    switch (widget.filterType) {
      case 'assigned':
        return 'Ongoing Tasks (Assigned)';
      case 'created':
        return 'Ongoing Tasks (Created)';
      case 'overdue':
        return 'Overdue Tasks';
      case 'completed':
        return 'Completed Tasks';
      default:
        return 'Tasks';
    }
  }

  Stream<List<TaskModel>> _getTaskStream(String userId) {
    switch (widget.filterType) {
      case 'assigned':
        // Exclude self-assigned tasks and overdue tasks (they go to Overdue tab)
        return _taskRepository
            .getOngoingAssignedTasksStream(userId)
            .map((tasks) => tasks
                .where((t) => t.createdBy != userId && !t.isOverdue)
                .toList());
      case 'created':
        // Exclude overdue tasks (they go to Overdue tab)
        return _taskRepository
            .getCreatedTasksStream(userId)
            .map((tasks) =>
                tasks.where((t) => t.status == TaskStatus.ongoing && !t.isOverdue).toList());
      case 'overdue':
        // Include both assigned AND created overdue tasks (same as badge)
        return _taskRepository
            .getUserCalendarTasksStream(userId)
            .map((tasks) => tasks
                .where((t) => t.status == TaskStatus.ongoing && t.isOverdue)
                .toList());
      case 'completed':
        return _taskRepository.getPastAssignedTasksStream(userId);
      default:
        return const Stream.empty();
    }
  }

  // Prefetching is now handled globally via DataCacheProvider 
  // to ensure data persists across all sub-screens.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = context.watch<AuthProvider>().currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/task/create'),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _getTaskStream(currentUser.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!;

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.task_outlined,
                    size: 80,
                    color: isDark ? AppColors.neutral600 : AppColors.neutral400,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No tasks found',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            );
          }

          // Prefetch all unique user IDs via global provider
          final userIds = <String>{
            ...tasks.map((t) => t.createdBy),
            ...tasks.expand((t) => t.allAssigneeIds),
          };
          context.read<DataCacheProvider>().prefetchUsers(userIds);

          return Consumer<DataCacheProvider>(
            builder: (context, cache, _) {
              return RefreshIndicator(
                onRefresh: () async {
                  setState(() {});
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
                  itemCount: tasks.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return TaskCard(
                      task: task,
                      creator: cache.getUser(task.createdBy),
                      assignee: cache.getUser(task.primaryAssigneeId),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
