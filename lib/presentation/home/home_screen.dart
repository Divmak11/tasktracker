import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/approval_request_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/approval_repository.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/calendar_service.dart';
import 'widgets/task_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TaskRepository _taskRepository = TaskRepository();
  final UserRepository _userRepository = UserRepository();
  final NotificationRepository _notificationRepository =
      NotificationRepository();
  final ApprovalRepository _approvalRepository = ApprovalRepository();
  final CalendarService _calendarService = CalendarService();

  // Cache streams to avoid recreating subscriptions on rebuild
  Stream<List<TaskModel>>? _ongoingTasksStream;
  Stream<List<TaskModel>>? _pastTasksStream;
  Stream<List<TaskModel>>? _createdTasksStream;
  Stream<int>? _unreadCountStream;
  Stream<List<ApprovalRequestModel>>? _pendingReschedulesStream;

  // Cache user data to avoid N+1 queries
  final Map<String, UserModel?> _userCache = {};

  static const String _calendarGuideShownKey = 'calendar_guide_shown';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Show calendar guide dialog on first visit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCalendarGuideIfNeeded();
      _refreshCalendarTokenIfNeeded();
    });
  }

  Future<void> _refreshCalendarTokenIfNeeded() async {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser?.googleCalendarConnected == true) {
      await _calendarService.refreshAccessToken(currentUser!.id);
    }
  }

  Future<void> _showCalendarGuideIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(_calendarGuideShownKey) ?? false;

    if (hasShown || !mounted) return;

    // Check if user already has calendar connected
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser?.googleCalendarConnected == true) {
      // Already connected, mark as shown and skip
      await prefs.setBool(_calendarGuideShownKey, true);
      return;
    }

    if (!mounted) return;

    // Show the guide dialog
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              icon: Icon(
                Icons.calendar_month,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Connect Your Calendar'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Stay organized by syncing your tasks with Google Calendar!',
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Get reminders for task deadlines\n'
                    '• See tasks in your calendar app\n'
                    '• Never miss an important task',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Maybe Later'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(AppRoutes.settings);
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('Go to Settings'),
                ),
              ],
            ),
      );

      // Mark as shown regardless of user choice
      await prefs.setBool(_calendarGuideShownKey, true);
    }
  }

  // Get or create cached streams
  Stream<List<TaskModel>> _getOngoingStream(String userId) {
    _ongoingTasksStream ??= _taskRepository.getOngoingTasksStream(userId);
    return _ongoingTasksStream!;
  }

  Stream<List<TaskModel>> _getPastStream(String userId) {
    _pastTasksStream ??= _taskRepository.getPastTasksStream(userId);
    return _pastTasksStream!;
  }

  Stream<List<TaskModel>> _getCreatedStream(String userId) {
    _createdTasksStream ??= _taskRepository.getCreatedTasksStream(userId);
    return _createdTasksStream!;
  }

  Stream<int> _getUnreadCountStream(String userId) {
    _unreadCountStream ??= _notificationRepository.getUnreadCountStream(userId);
    return _unreadCountStream!;
  }

  Stream<List<ApprovalRequestModel>> _getPendingReschedulesStream(
    String userId,
  ) {
    _pendingReschedulesStream ??= _approvalRepository
        .getPendingRescheduleRequestsStream(userId);
    return _pendingReschedulesStream!;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Calendar View',
            onPressed: () {
              context.push('/calendar');
            },
          ),
          StreamBuilder<List<ApprovalRequestModel>>(
            stream: _getPendingReschedulesStream(currentUser.id),
            builder: (context, snapshot) {
              final pendingCount = snapshot.data?.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.schedule),
                    tooltip: 'Reschedule Requests',
                    onPressed: () {
                      context.push(AppRoutes.rescheduleApproval);
                    },
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
            stream: _getUnreadCountStream(currentUser.id),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {
                      context.push(AppRoutes.notifications);
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'Past'),
            Tab(text: 'Created'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/task/create');
        },
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Ongoing Tasks Tab
          _buildTaskList(
            context,
            stream: _getOngoingStream(currentUser.id),
            emptyMessage: 'No ongoing tasks',
          ),

          // Past Tasks Tab
          _buildTaskList(
            context,
            stream: _getPastStream(currentUser.id),
            emptyMessage: 'No past tasks',
          ),

          // Created Tasks Tab
          _buildTaskList(
            context,
            stream: _getCreatedStream(currentUser.id),
            emptyMessage: 'No tasks created by you',
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context, {
    required Stream<List<TaskModel>> stream,
    required String emptyMessage,
  }) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        // Force stream refresh
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: StreamBuilder<List<TaskModel>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Error loading tasks',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${snapshot.error}',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data!;

          if (tasks.isEmpty) {
            return _buildEmptyState(context, emptyMessage);
          }

          // Prefetch all unique creator IDs to avoid N+1 queries
          final creatorIds = tasks.map((t) => t.createdBy).toSet();

          return FutureBuilder<void>(
            future: _prefetchUsers(creatorIds),
            builder: (context, _) {
              return ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
                itemCount: tasks.length,
                separatorBuilder:
                    (context, index) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  // Use cached user instead of creating new StreamBuilder
                  return TaskCard(
                    task: task,
                    creator: _userCache[task.createdBy],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Batch fetch users to avoid N+1 queries
  Future<void> _prefetchUsers(Set<String> userIds) async {
    final uncachedIds =
        userIds.where((id) => !_userCache.containsKey(id)).toList();
    if (uncachedIds.isEmpty) return;

    // Fetch all uncached users in parallel
    final futures = uncachedIds.map((id) => _userRepository.getUser(id));
    final users = await Future.wait(futures);

    for (int i = 0; i < uncachedIds.length; i++) {
      _userCache[uncachedIds[i]] = users[i];
    }
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            message,
            style: theme.textTheme.titleLarge?.copyWith(
              color: isDark ? AppColors.neutral400 : AppColors.neutral600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Create a new task to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.neutral500 : AppColors.neutral500,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: () {
              context.push('/task/create');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Task'),
          ),
        ],
      ),
    );
  }
}
