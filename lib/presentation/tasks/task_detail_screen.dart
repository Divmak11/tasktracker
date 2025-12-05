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
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/remark_repository.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/cloud_functions_service.dart';
import '../common/cards/app_card.dart';
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
          final isCreator = currentUser?.id == task.createdBy;
          final isAssignee = currentUser?.id == task.assignedTo;
          final isAdmin = currentUser?.role == UserRole.superAdmin;
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
                      // Status and Deadline
                      Row(
                        children: [
                          _buildStatusBadge(task),
                          const Spacer(),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color:
                                task.isOverdue
                                    ? Colors.red
                                    : (isDark
                                        ? AppColors.neutral400
                                        : AppColors.neutral600),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            DateFormat('MMM d, h:mm a').format(task.deadline),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  task.isOverdue
                                      ? Colors.red
                                      : (isDark
                                          ? AppColors.neutral400
                                          : AppColors.neutral600),
                              fontWeight:
                                  task.isOverdue
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ],
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

                      // Assigned To
                      Text(
                        'Assigned To',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      StreamBuilder<UserModel?>(
                        stream: userRepository.getUserStream(task.assignedTo),
                        builder: (context, assigneeSnapshot) {
                          final assignee = assigneeSnapshot.data;
                          return AppCard(
                            type: AppCardType.standard,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.primaryContainer,
                                child: Text(
                                  assignee?.name.isNotEmpty == true
                                      ? assignee!.name[0]
                                      : '?',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              title: Text(assignee?.name ?? 'Loading...'),
                              subtitle: Text(
                                assignee != null
                                    ? _getRoleText(assignee.role)
                                    : '',
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Created By
                      Text(
                        'Created By',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      StreamBuilder<UserModel?>(
                        stream: userRepository.getUserStream(task.createdBy),
                        builder: (context, creatorSnapshot) {
                          final creator = creatorSnapshot.data;
                          return AppCard(
                            type: AppCardType.standard,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    theme.colorScheme.secondaryContainer,
                                child: Text(
                                  creator?.name.isNotEmpty == true
                                      ? creator!.name[0]
                                      : '?',
                                  style: TextStyle(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                              title: Text(creator?.name ?? '[Deleted User]'),
                              subtitle: Text(
                                creator != null
                                    ? _getRoleText(creator.role)
                                    : '',
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),

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
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
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
                      // Reschedule button for assignee on ongoing tasks
                      if (isAssignee && task.status == TaskStatus.ongoing) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder:
                                  (_) => RescheduleRequestDialog(task: task),
                            );
                          },
                          icon: const Icon(Icons.schedule),
                          label: const Text('Request Reschedule'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (canEdit) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  context.push('/task/$taskId/edit');
                                },
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    () => _handleCancel(
                                      context,
                                      taskRepository,
                                      task,
                                    ),
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  String _getRoleText(UserRole role) {
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
      try {
        // Call Cloud Function to complete task
        final cloudFunctions = CloudFunctionsService();
        await cloudFunctions.completeTask(task.id);

        if (context.mounted) {
          NotificationService.showInAppNotification(
            context,
            title: 'Task Completed',
            message: 'Task marked as completed',
            icon: Icons.check_circle,
            backgroundColor: Colors.green.shade700,
          );
        }
      } on FirebaseFunctionsException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message ?? e.code}')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
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
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Call Cloud Function to cancel task
        final cloudFunctions = CloudFunctionsService();
        await cloudFunctions.cancelTask(task.id);

        // Dismiss loading dialog
        if (context.mounted) Navigator.of(context).pop();

        if (context.mounted) {
          NotificationService.showInAppNotification(
            context,
            title: 'Task Cancelled',
            message: 'Task has been cancelled',
            icon: Icons.cancel,
            backgroundColor: Colors.orange.shade700,
          );
        }
      } on FirebaseFunctionsException catch (e) {
        // Dismiss loading dialog
        if (context.mounted) Navigator.of(context).pop();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message ?? e.code}')),
          );
        }
      } catch (e) {
        // Dismiss loading dialog
        if (context.mounted) Navigator.of(context).pop();
        
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
