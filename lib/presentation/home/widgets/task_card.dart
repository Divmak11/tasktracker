import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/user_model.dart';
import '../../common/cards/app_card.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final UserModel? creator;
  final UserModel? assignee;

  const TaskCard({super.key, required this.task, this.creator, this.assignee});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOverdue = task.isOverdue;

    return AppCard(
      type: AppCardType.standard,
      onTap: () {
        context.push('/task/${task.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          border:
              isOverdue
                  ? Border(left: BorderSide(color: Colors.red, width: 4))
                  : null,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                _buildStatusBadge(context, task.status, isOverdue),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),

            // Subtitle (if available)
            if (task.subtitle.isNotEmpty) ...[
              Text(
                task.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Deadline
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color:
                      isOverdue
                          ? Colors.red
                          : (isDark
                              ? AppColors.neutral400
                              : AppColors.neutral600),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _formatDeadline(task.deadline),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          isOverdue
                              ? Colors.red
                              : (isDark
                                  ? AppColors.neutral400
                                  : AppColors.neutral600),
                      fontWeight:
                          isOverdue ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            // Creator and Assignee Row
            if (creator != null || assignee != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  // Created by
                  if (creator != null) ...[
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color:
                          isDark ? AppColors.neutral500 : AppColors.neutral500,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        creator!.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              isDark
                                  ? AppColors.neutral400
                                  : AppColors.neutral600,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                  // Separator
                  if (creator != null && assignee != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.arrow_forward,
                      size: 12,
                      color:
                          isDark ? AppColors.neutral600 : AppColors.neutral400,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // Assigned to
                  if (assignee != null) ...[
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color:
                          isDark ? AppColors.neutral500 : AppColors.neutral500,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        assignee!.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              isDark
                                  ? AppColors.neutral400
                                  : AppColors.neutral600,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    TaskStatus status,
    bool isOverdue,
  ) {
    final theme = Theme.of(context);
    Color badgeColor;
    String badgeText;

    if (isOverdue) {
      badgeColor = Colors.red;
      badgeText = 'Overdue';
    } else {
      switch (status) {
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
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        badgeText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) {
      // Overdue
      if (difference.inDays.abs() == 0) {
        return 'Due ${DateFormat('h:mm a').format(deadline)}';
      } else {
        return 'Due ${DateFormat('MMM d, h:mm a').format(deadline)}';
      }
    } else if (difference.inDays == 0) {
      // Today
      return 'Due today at ${DateFormat('h:mm a').format(deadline)}';
    } else if (difference.inDays == 1) {
      // Tomorrow
      return 'Due tomorrow at ${DateFormat('h:mm a').format(deadline)}';
    } else {
      // Future date
      return 'Due ${DateFormat('MMM d, h:mm a').format(deadline)}';
    }
  }
}
