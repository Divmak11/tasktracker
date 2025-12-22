import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/task_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/remark_model.dart';
import '../../data/models/task_assignment_model.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/remark_repository.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/cloud_functions_service.dart';
import '../common/buttons/app_button.dart';
import 'widgets/add_remark_dialog.dart';
import 'widgets/remark_item.dart';
import 'widgets/reschedule_request_dialog.dart';

class TaskDetailScreen extends StatelessWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final taskRepository = TaskRepository();
    final userRepository = UserRepository();
    final remarkRepository = RemarkRepository();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Task Details')),
      body: StreamBuilder<TaskModel?>(
        stream: taskRepository.getTaskStream(taskId),
        builder: (context, taskSnapshot) {
          if (taskSnapshot.hasError) {
            return Center(child: Text('Error: ${taskSnapshot.error}'));
          }

          if (!taskSnapshot.hasData || taskSnapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final task = taskSnapshot.data!;
          final currentUserId = currentUser?.id ?? '';
          final isCreator = task.isCreator(currentUserId);
          final isAssignee = task.isAssignee(currentUserId);
          final isAdmin = currentUser?.role == UserRole.superAdmin;
          final canSeeAllStatus = task.canSeeAllCompletionStatus(currentUserId);

          // Only allow edit/cancel for ongoing tasks
          final canEdit =
              (isCreator || isAdmin) && task.status == TaskStatus.ongoing;
          final canComplete = isAssignee && task.status == TaskStatus.ongoing;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      _buildStatusBadge(task),
                      const SizedBox(height: AppSpacing.md),

                      // Deadline Info Card
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? AppColors.neutral900
                                  : AppColors.neutral50,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.neutral800
                                    : AppColors.neutral200,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Original Deadline
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color:
                                      task.isOverdue &&
                                              task.status == TaskStatus.ongoing
                                          ? Colors.red
                                          : (isDark
                                              ? AppColors.neutral400
                                              : AppColors.neutral600),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Deadline:',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color:
                                        isDark
                                            ? AppColors.neutral400
                                            : AppColors.neutral600,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    DateFormat(
                                      'MMM d, yyyy • h:mm a',
                                    ).format(task.deadline),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          task.isOverdue &&
                                                  task.status ==
                                                      TaskStatus.ongoing
                                              ? Colors.red
                                              : theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Completed At (only for completed tasks)
                            if (task.status == TaskStatus.completed &&
                                task.completedAt != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              const Divider(height: 1),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'Completed:',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          isDark
                                              ? AppColors.neutral400
                                              : AppColors.neutral600,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      DateFormat(
                                        'MMM d, yyyy • h:mm a',
                                      ).format(task.completedAt!),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              // Show if completed on time or late
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: [
                                  const SizedBox(width: 26), // Align with text
                                  Text(
                                    task.completedAt!.isBefore(task.deadline)
                                        ? '✓ Completed on time'
                                        : '⚠ Completed after deadline',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          task.completedAt!.isBefore(
                                                task.deadline,
                                              )
                                              ? Colors.green
                                              : Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Title
                      Text(
                        task.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Subtitle/Description
                      if (task.subtitle.isNotEmpty) ...[
                        Text(
                          'Description',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          task.subtitle,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color:
                                isDark
                                    ? AppColors.neutral300
                                    : AppColors.neutral700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],

                      // People Section - Compact Layout
                      Text(
                        'People',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Compact people container
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? AppColors.neutral900
                                  : AppColors.neutral50,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(
                            color:
                                isDark
                                    ? AppColors.neutral800
                                    : AppColors.neutral200,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Assigned To Row(s) - show all assignees for multi-assignee tasks
                            if (task.isMultiAssignee) ...[
                              // Show all assignees for multi-assignee tasks
                              ...task.assigneeIds.asMap().entries.map((entry) {
                                final index = entry.key;
                                final assigneeId = entry.value;
                                return Column(
                                  children: [
                                    StreamBuilder<UserModel?>(
                                      stream: userRepository.getUserStream(
                                        assigneeId,
                                      ),
                                      builder: (context, assigneeSnapshot) {
                                        final assignee = assigneeSnapshot.data;
                                        final isSupervisor = task.supervisorIds
                                            .contains(assigneeId);
                                        return _buildCompactUserRow(
                                          context,
                                          label:
                                              index == 0
                                                  ? 'Assigned to (${task.assigneeIds.length})'
                                                  : '',
                                          user: assignee,
                                          color: theme.colorScheme.primary,
                                          icon:
                                              isSupervisor
                                                  ? Icons.supervisor_account
                                                  : Icons.person,
                                          connectionState: assigneeSnapshot.connectionState,
                                        );
                                      },
                                    ),
                                    if (index < task.assigneeIds.length - 1)
                                      const SizedBox(height: AppSpacing.xs),
                                  ],
                                );
                              }),
                            ] else ...[
                              // Single assignee
                              StreamBuilder<UserModel?>(
                                stream:
                                    task.primaryAssigneeId.isNotEmpty
                                        ? userRepository.getUserStream(
                                          task.primaryAssigneeId,
                                        )
                                        : const Stream.empty(),
                                builder: (context, assigneeSnapshot) {
                                  final assignee = assigneeSnapshot.data;
                                  return _buildCompactUserRow(
                                    context,
                                    label: 'Assigned to',
                                    user: assignee,
                                    color: theme.colorScheme.primary,
                                    icon: Icons.person,
                                    connectionState: assigneeSnapshot.connectionState,
                                  );
                                },
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            Divider(
                              height: 1,
                              color:
                                  isDark
                                      ? AppColors.neutral800
                                      : AppColors.neutral200,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            // Created By Row
                            StreamBuilder<UserModel?>(
                              stream: userRepository.getUserStream(
                                task.createdBy,
                              ),
                              builder: (context, creatorSnapshot) {
                                final creator = creatorSnapshot.data;
                                return _buildCompactUserRow(
                                  context,
                                  label: 'Created by',
                                  user: creator,
                                  color: Colors.orange,
                                  icon: Icons.create,
                                  connectionState: creatorSnapshot.connectionState,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Multi-Assignee Status Table (for creator/supervisor only)
                      if (task.isMultiAssignee && canSeeAllStatus) ...[
                        Text(
                          'Assignee Progress',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        StreamBuilder<List<TaskAssignmentModel>>(
                          stream: taskRepository.getTaskAssignmentsStream(
                            taskId,
                          ),
                          builder: (context, assignmentsSnapshot) {
                            if (!assignmentsSnapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final assignments = assignmentsSnapshot.data!;
                            if (assignments.isEmpty) {
                              return const Text('No assignments found');
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppColors.neutral900
                                        : AppColors.neutral50,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.medium,
                                ),
                                border: Border.all(
                                  color:
                                      isDark
                                          ? AppColors.neutral800
                                          : AppColors.neutral200,
                                ),
                              ),
                              child: Column(
                                children:
                                    assignments.map((assignment) {
                                      return StreamBuilder<UserModel?>(
                                        stream: userRepository.getUserStream(
                                          assignment.userId,
                                        ),
                                        builder: (context, userSnapshot) {
                                          final user = userSnapshot.data;
                                          final isSup = task.supervisorIds
                                              .contains(assignment.userId);
                                          
                                          // Determine display name
                                          final bool isLoading = userSnapshot.connectionState == ConnectionState.waiting;
                                          final bool isDeleted = userSnapshot.connectionState == ConnectionState.active && user == null;
                                          final String displayName = user?.name ?? (isLoading ? 'Loading...' : (isDeleted ? 'Deleted User' : 'Unknown'));

                                          return Container(
                                            padding: const EdgeInsets.all(
                                              AppSpacing.md,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color:
                                                      isDark
                                                          ? AppColors.neutral800
                                                          : AppColors
                                                              .neutral200,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor:
                                                      theme
                                                          .colorScheme
                                                          .primaryContainer,
                                                  backgroundImage:
                                                      user?.avatarUrl != null
                                                          ? NetworkImage(
                                                            user!.avatarUrl!,
                                                          )
                                                          : null,
                                                  child:
                                                      user?.avatarUrl == null
                                                          ? Text(
                                                            user?.name.isNotEmpty ==
                                                                    true
                                                                ? user!.name[0]
                                                                    .toUpperCase()
                                                                : '?',
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
                                                const SizedBox(
                                                  width: AppSpacing.sm,
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Flexible(
                                                            child: Text(
                                                              displayName,
                                                              style: theme
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                                                                  ),
                                                            ),
                                                          ),
                                                          if (isSup) ...[
                                                            const SizedBox(
                                                              width:
                                                                  AppSpacing.xs,
                                                            ),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        AppSpacing
                                                                            .xs,
                                                                    vertical: 2,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    theme
                                                                        .colorScheme
                                                                        .secondary,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      AppRadius
                                                                          .small,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                'S',
                                                                style: theme
                                                                    .textTheme
                                                                    .labelSmall
                                                                    ?.copyWith(
                                                                      color:
                                                                          theme
                                                                              .colorScheme
                                                                              .onSecondary,
                                                                      fontSize:
                                                                          9,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      if (assignment
                                                              .isCompleted &&
                                                          assignment
                                                                  .completedAt !=
                                                              null)
                                                        Text(
                                                          'Completed ${DateFormat('MMM d, h:mm a').format(assignment.completedAt!)}',
                                                          style: theme
                                                              .textTheme
                                                              .bodySmall
                                                              ?.copyWith(
                                                                color:
                                                                    Colors
                                                                        .green,
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(
                                                  assignment.isCompleted
                                                      ? Icons.check_circle
                                                      : (assignment.isOverdue(
                                                            task.deadline,
                                                          )
                                                          ? Icons.error
                                                          : Icons
                                                              .radio_button_unchecked),
                                                  color:
                                                      assignment.isCompleted
                                                          ? Colors.green
                                                          : (assignment.isOverdue(
                                                                task.deadline,
                                                              )
                                                              ? Colors.red
                                                              : (isDark
                                                                  ? AppColors
                                                                      .neutral500
                                                                  : AppColors
                                                                      .neutral400)),
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    }).toList(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],

                      // Remarks Section
                      Row(
                        children: [
                          Text(
                            'Remarks',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          StreamBuilder<List<RemarkModel>>(
                            stream: remarkRepository.getTaskRemarksStream(
                              taskId,
                            ),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.length ?? 0;
                              if (count == 0) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs / 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                                child: Text(
                                  count.toString(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            },
                          ),
                          const Spacer(),
                          if (isAssignee || isCreator || isAdmin)
                            TextButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder:
                                      (context) =>
                                          AddRemarkDialog(taskId: taskId),
                                );
                              },
                              icon: const Icon(Icons.add_comment, size: 18),
                              label: const Text('Add'),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Remarks List
                      StreamBuilder<List<RemarkModel>>(
                        stream: remarkRepository.getTaskRemarksStream(taskId),
                        builder: (context, remarksSnapshot) {
                          if (remarksSnapshot.hasError) {
                            return Text(
                              'Error loading remarks: ${remarksSnapshot.error}',
                            );
                          }

                          if (!remarksSnapshot.hasData) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.md),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final remarks = remarksSnapshot.data!;

                          if (remarks.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppColors.neutral900
                                        : AppColors.neutral50,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.medium,
                                ),
                                border: Border.all(
                                  color:
                                      isDark
                                          ? AppColors.neutral800
                                          : AppColors.neutral200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.comment_outlined,
                                    color:
                                        isDark
                                            ? AppColors.neutral600
                                            : AppColors.neutral300,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'No remarks yet',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color:
                                          isDark
                                              ? AppColors.neutral500
                                              : AppColors.neutral400,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    isDark
                                        ? AppColors.neutral800
                                        : AppColors.neutral200,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: remarks.length,
                              itemBuilder: (context, index) {
                                final remark = remarks[index];
                                return StreamBuilder<UserModel?>(
                                  stream: userRepository.getUserStream(
                                    remark.userId,
                                  ),
                                  builder: (context, userSnapshot) {
                                    return RemarkItem(
                                      remark: remark,
                                      user: userSnapshot.data,
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar
              if (canComplete || canEdit || isAssignee)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingMobile,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.neutral800 : AppColors.neutral200,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canComplete) ...[
                        AppButton(
                          text: 'Mark as Completed',
                          onPressed:
                              () => _handleComplete(
                                context,
                                taskRepository,
                                task,
                              ),
                          icon: Icons.check_circle_outline,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      // Secondary actions row
                      Row(
                        children: [
                          // Reschedule button
                          if (isAssignee && task.status == TaskStatus.ongoing) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (_) => RescheduleRequestDialog(task: task),
                                  );
                                },
                                icon: const Icon(Icons.schedule, size: 18),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Reschedule'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: AppSpacing.sm,
                                  ),
                                ),
                              ),
                            ),
                            if (canEdit) const SizedBox(width: AppSpacing.sm),
                          ],
                          // Edit and Cancel buttons
                          if (canEdit) ...[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.push('/task/$taskId/edit');
                                },
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Edit'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: AppSpacing.sm,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    () => _handleCancel(
                                      context,
                                      taskRepository,
                                      task,
                                    ),
                                icon: const Icon(Icons.cancel_outlined, size: 18),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Cancel'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: AppSpacing.sm,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(TaskModel task) {
    Color badgeColor;
    String badgeText;

    if (task.isOverdue) {
      badgeColor = Colors.red;
      badgeText = 'Overdue';
    } else {
      switch (task.status) {
        case TaskStatus.ongoing:
          badgeColor = Colors.blue;
          badgeText = 'Ongoing';
          break;
        case TaskStatus.completed:
          badgeColor = Colors.green;
          badgeText = 'Completed';
          break;
        case TaskStatus.cancelled:
          badgeColor = Colors.grey;
          badgeText = 'Cancelled';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: badgeColor),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCompactUserRow(
    BuildContext context, {
    required String label,
    required UserModel? user,
    required Color color,
    required IconData icon,
    required ConnectionState connectionState,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Determine what to display
    final bool isLoading = connectionState == ConnectionState.waiting;
    final bool isDeleted = connectionState == ConnectionState.active && user == null;

    return Row(
      children: [
        // Icon with color accent
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Label - fixed width to give more space to name
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? AppColors.neutral500 : AppColors.neutral500,
            ),
          ),
        ),
        // User info - takes remaining space
        Expanded(
          child:
              user != null
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              user.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                            Text(
                              _getRoleLabel(user.role),
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
                      const SizedBox(width: AppSpacing.sm),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: color.withValues(alpha: 0.2),
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
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                )
                                : null,
                      ),
                    ],
                  )
                  : Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      isLoading ? 'Loading...' : (isDeleted ? 'Deleted User' : 'Unknown'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            isDark
                                ? AppColors.neutral500
                                : AppColors.neutral400,
                        fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.teamAdmin:
        return 'Team Admin';
      case UserRole.member:
        return 'Member';
    }
  }

  Future<void> _handleComplete(
    BuildContext context,
    TaskRepository taskRepository,
    TaskModel task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Mark Complete'),
            content: const Text('Mark this task as completed?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Complete'),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      // OPTIMISTIC UPDATE: Show success immediately
      // Use different message for multi-assignee tasks
      final isMultiAssignee = task.isMultiAssignee;
      NotificationService.showInAppNotification(
        context,
        title: isMultiAssignee ? 'Assignment Completed' : 'Task Completed',
        message:
            isMultiAssignee
                ? 'Your assignment has been marked as completed'
                : 'Task marked as completed',
        icon: Icons.check_circle,
        backgroundColor: Colors.green.shade700,
      );

      // Navigate back to home for better UX
      context.pop();

      // Fire cloud function in background (don't await)
      // Firestore stream will auto-update UI with server state
      // Use completeAssignment for multi-assignee, completeTask for legacy
      final cloudFunctions = CloudFunctionsService();
      final future =
          isMultiAssignee
              ? cloudFunctions.completeAssignment(task.id)
              : cloudFunctions.completeTask(task.id);
      future.catchError((error) {
        // Show error with retry if background sync fails
        // UI will naturally revert via Firestore stream since server wasn't updated
        if (context.mounted) {
          final message =
              error is FirebaseFunctionsException
                  ? error.message ?? error.code
                  : error.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sync: $message'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _handleComplete(context, taskRepository, task),
              ),
            ),
          );
        }
        return <String, dynamic>{};
      });
    }
  }

  Future<void> _handleCancel(
    BuildContext context,
    TaskRepository taskRepository,
    TaskModel task,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Cancel Task'),
            content: const Text('Are you sure you want to cancel this task?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      // OPTIMISTIC UPDATE: Show success immediately (no loading dialog)
      NotificationService.showInAppNotification(
        context,
        title: 'Task Cancelled',
        message: 'Task has been cancelled',
        icon: Icons.cancel,
        backgroundColor: Colors.orange.shade700,
      );

      // Navigate back to home for better UX
      context.pop();

      // Fire cloud function in background (don't await)
      // Firestore stream will auto-update UI with server state
      final cloudFunctions = CloudFunctionsService();
      cloudFunctions.cancelTask(task.id).catchError((error) {
        // Show error with retry if background sync fails
        if (context.mounted) {
          final message =
              error is FirebaseFunctionsException
                  ? error.message ?? error.code
                  : error.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sync: $message'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _handleCancel(context, taskRepository, task),
              ),
            ),
          );
        }
        return <String, dynamic>{};
      });
    }
  }
}
