import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/repositories/task_repository.dart';
import '../common/cards/app_card.dart';

class CalendarViewScreen extends StatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  final TaskRepository _taskRepository = TaskRepository();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<TaskModel>> _tasksByDate = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<TaskModel> _getTasksForDay(DateTime day) {
    return _tasksByDate[_normalizeDate(day)] ?? [];
  }

  void _updateTasksByDate(List<TaskModel> tasks) {
    final Map<DateTime, List<TaskModel>> newTasksByDate = {};
    for (final task in tasks) {
      final date = _normalizeDate(task.deadline);
      if (newTasksByDate[date] == null) {
        newTasksByDate[date] = [];
      }
      newTasksByDate[date]!.add(task);
    }
    setState(() {
      _tasksByDate = newTasksByDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
              });
            },
            tooltip: 'Today',
          ),
        ],
      ),
      body: StreamBuilder<List<TaskModel>>(
        stream: _taskRepository.getUserTasksStream(currentUser.id),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            // Update tasks by date when data changes
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateTasksByDate(snapshot.data!);
            });
          }

          return Column(
            children: [
              // Calendar Widget
              TableCalendar<TaskModel>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _getTasksForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  weekendTextStyle: TextStyle(
                    color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                  ),
                  todayDecoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 3,
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonShowsNext: false,
                  formatButtonDecoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.primary),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  formatButtonTextStyle: TextStyle(
                    color: theme.colorScheme.primary,
                  ),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
              const Divider(height: 1),

              // Selected Day Tasks
              Expanded(child: _buildSelectedDayTasks(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSelectedDayTasks(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tasks = _getTasksForDay(_selectedDay ?? DateTime.now());

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: isDark ? AppColors.neutral600 : AppColors.neutral400,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No tasks on this day',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDark ? AppColors.neutral400 : AppColors.neutral600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              DateFormat('EEEE, MMMM d').format(_selectedDay ?? DateTime.now()),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.neutral500 : AppColors.neutral500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            '${tasks.length} task${tasks.length > 1 ? 's' : ''} on ${DateFormat('MMM d').format(_selectedDay ?? DateTime.now())}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskItem(context, task);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem(BuildContext context, TaskModel task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    switch (task.status) {
      case TaskStatus.ongoing:
        statusColor = task.isOverdue ? Colors.red : Colors.blue;
        statusText = task.isOverdue ? 'Overdue' : 'Ongoing';
        break;
      case TaskStatus.completed:
        statusColor = Colors.green;
        statusText = 'Completed';
        break;
      case TaskStatus.cancelled:
        statusColor = Colors.grey;
        statusText = 'Cancelled';
        break;
    }

    return AppCard(
      type: AppCardType.standard,
      onTap: () {
        context.push('/task/${task.id}');
      },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 50,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration:
                          task.status == TaskStatus.cancelled
                              ? TextDecoration.lineThrough
                              : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color:
                            isDark
                                ? AppColors.neutral500
                                : AppColors.neutral500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(task.deadline),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              isDark
                                  ? AppColors.neutral400
                                  : AppColors.neutral600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          statusText,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
