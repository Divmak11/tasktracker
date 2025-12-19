import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../common/list_items/task_tile.dart';

class AllTasksScreen extends StatefulWidget {
  /// Initial tab index: 0=All, 1=Ongoing, 2=Completed, 3=Cancelled
  final int initialTabIndex;

  const AllTasksScreen({super.key, this.initialTabIndex = 1});

  @override
  State<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends State<AllTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TaskRepository _taskRepository = TaskRepository();
  final UserRepository _userRepository = UserRepository();
  late Stream<List<TaskModel>> _tasksStream;

  // Filter state
  String? _selectedAssigneeId;
  String? _selectedAssigneeName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _tasksStream = _taskRepository.getAllTasksStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<TaskModel> _filterTasks(List<TaskModel> tasks, int tabIndex) {
    List<TaskModel> filtered;
    switch (tabIndex) {
      case 0:
        filtered = tasks; // All
        break;
      case 1:
        filtered = tasks.where((t) => t.status == TaskStatus.ongoing).toList();
        break;
      case 2:
        filtered =
            tasks.where((t) => t.status == TaskStatus.completed).toList();
        break;
      case 3:
        filtered =
            tasks.where((t) => t.status == TaskStatus.cancelled).toList();
        break;
      default:
        filtered = tasks;
    }

    // Apply assignee filter if selected (supports both legacy and multi-assignee)
    if (_selectedAssigneeId != null) {
      filtered =
          filtered.where((t) => t.isAssignee(_selectedAssigneeId!)).toList();
    }

    return filtered;
  }

  void _showAssigneeFilter(List<UserModel> users) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.neutral600 : AppColors.neutral300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Text(
                        'Filter by Assignee',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedAssigneeId != null)
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedAssigneeId = null;
                              _selectedAssigneeName = null;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // User list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isSelected = _selectedAssigneeId == user.id;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primaryContainer,
                          backgroundImage:
                              user.avatarUrl != null
                                  ? NetworkImage(user.avatarUrl!)
                                  : null,
                          child:
                              user.avatarUrl == null
                                  ? Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : theme
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                    ),
                                  )
                                  : null,
                        ),
                        title: Text(user.name),
                        subtitle: null,
                        trailing:
                            isSelected
                                ? Icon(
                                  Icons.check_circle,
                                  color: theme.colorScheme.primary,
                                )
                                : null,
                        onTap: () {
                          setState(() {
                            _selectedAssigneeId = user.id;
                            _selectedAssigneeName = user.name;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
        actions: [
          // Filter button
          StreamBuilder<List<UserModel>>(
            stream: _userRepository.getAllUsersStream(),
            builder: (context, snapshot) {
              final users =
                  snapshot.data
                      ?.where((u) => u.status == UserStatus.active)
                      .toList() ??
                  [];

              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    tooltip: 'Filter by assignee',
                    onPressed:
                        users.isNotEmpty
                            ? () => _showAssigneeFilter(users)
                            : null,
                  ),
                  if (_selectedAssigneeId != null)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            _selectedAssigneeName != null ? 84 : 48,
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Ongoing'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
              // Active filter chip
              if (_selectedAssigneeName != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_alt,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Filtered by: $_selectedAssigneeName',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAssigneeId = null;
                            _selectedAssigneeName = null;
                          });
                        },
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _tasksStream,
        builder: (context, taskSnapshot) {
          if (taskSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Error loading tasks'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${taskSnapshot.error}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          if (!taskSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allTasks = taskSnapshot.data!;

          // Build TabBarView for swipeable tabs
          return StreamBuilder<List<UserModel>>(
            stream: _userRepository.getAllUsersStream(),
            builder: (context, usersSnapshot) {
              final usersMap = <String, UserModel>{};
              if (usersSnapshot.hasData) {
                for (final user in usersSnapshot.data!) {
                  usersMap[user.id] = user;
                }
              }

              return TabBarView(
                controller: _tabController,
                children: List.generate(4, (tabIndex) {
                  final filteredTasks = _filterTasks(allTasks, tabIndex);
                  // Sort by deadline (most recent first)
                  filteredTasks.sort(
                    (a, b) => b.deadline.compareTo(a.deadline),
                  );

                  if (filteredTasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 80,
                            color:
                                isDark
                                    ? AppColors.neutral600
                                    : AppColors.neutral300,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            _selectedAssigneeId != null
                                ? 'No tasks for this assignee'
                                : 'No Tasks Found',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color:
                                  isDark
                                      ? AppColors.neutral400
                                      : AppColors.neutral600,
                            ),
                          ),
                          if (_selectedAssigneeId != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedAssigneeId = null;
                                  _selectedAssigneeName = null;
                                });
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear filter'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(
                      AppSpacing.screenPaddingMobile,
                    ),
                    itemCount: filteredTasks.length,
                    separatorBuilder:
                        (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final task = filteredTasks[index];
                      final assignee = usersMap[task.primaryAssigneeId];
                      final creator = usersMap[task.createdBy];

                      return TaskTile(
                        task: task,
                        assignee: assignee,
                        creator: creator,
                        onTap: () => context.push('/task/${task.id}'),
                      );
                    },
                  );
                }),
              );
            },
          );
        },
      ),
    );
  }
}
