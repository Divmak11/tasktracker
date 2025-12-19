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

class OverdueTasksScreen extends StatelessWidget {
  const OverdueTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final taskRepository = TaskRepository();
    final userRepository = UserRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Overdue Tasks')),
      body: StreamBuilder<List<TaskModel>>(
        stream: taskRepository.getOverdueTasksStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error loading tasks'),
                  const SizedBox(height: AppSpacing.sm),
                  Text('${snapshot.error}', style: theme.textTheme.bodySmall),
                ],
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
                    Icons.check_circle_outline,
                    size: 80,
                    color: Colors.green.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No Overdue Tasks',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'All tasks are on track!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          isDark ? AppColors.neutral500 : AppColors.neutral500,
                    ),
                  ),
                ],
              ),
            );
          }

          // Sort by most overdue first
          tasks.sort((a, b) => a.deadline.compareTo(b.deadline));

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final task = tasks[index];
              final daysOverdue =
                  DateTime.now().difference(task.deadline).inDays;

              return StreamBuilder<UserModel?>(
                stream:
                    task.primaryAssigneeId.isNotEmpty
                        ? userRepository.getUserStream(task.primaryAssigneeId)
                        : const Stream.empty(),
                builder: (context, assigneeSnapshot) {
                  final assignee = assigneeSnapshot.data;

                  return StreamBuilder<UserModel?>(
                    stream: userRepository.getUserStream(task.createdBy),
                    builder: (context, creatorSnapshot) {
                      final creator = creatorSnapshot.data;

                      return AppCard(
                        type: AppCardType.standard,
                        onTap: () {
                          context.push('/task/${task.id}');
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with overdue badge
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.small,
                                      ),
                                      border: Border.all(
                                        color: Colors.red.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      daysOverdue == 0
                                          ? 'Due today'
                                          : '$daysOverdue day${daysOverdue > 1 ? 's' : ''} overdue',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (task.subtitle.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  task.subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color:
                                        isDark
                                            ? AppColors.neutral400
                                            : AppColors.neutral600,
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
                                          radius: 14,
                                          backgroundColor:
                                              theme
                                                  .colorScheme
                                                  .primaryContainer,
                                          backgroundImage:
                                              assignee?.avatarUrl != null
                                                  ? NetworkImage(
                                                    assignee!.avatarUrl!,
                                                  )
                                                  : null,
                                          child:
                                              assignee?.avatarUrl == null
                                                  ? Text(
                                                    assignee?.name[0] ?? '?',
                                                    style: TextStyle(
                                                      fontSize: 12,
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
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Assigned to',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color:
                                                          isDark
                                                              ? AppColors
                                                                  .neutral500
                                                              : AppColors
                                                                  .neutral500,
                                                    ),
                                              ),
                                              Text(
                                                assignee?.name ?? 'Loading...',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Deadline
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Original deadline',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color:
                                                  isDark
                                                      ? AppColors.neutral500
                                                      : AppColors.neutral500,
                                            ),
                                      ),
                                      Text(
                                        DateFormat(
                                          'MMM d, h:mm a',
                                        ).format(task.deadline),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              // Creator info
                              Text(
                                'Created by: ${creator?.name ?? 'Loading...'}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      isDark
                                          ? AppColors.neutral500
                                          : AppColors.neutral500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
