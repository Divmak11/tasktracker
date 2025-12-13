import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/user_model.dart';
import '../badges/status_badge.dart';

/// Modern task tile with all relevant information displayed cleanly
class TaskTile extends StatelessWidget {
  final TaskModel task;
  final UserModel? assignee;
  final UserModel? creator;
  final int remarksCount;
  final List<String>? additionalAssigneeNames;
  final VoidCallback? onTap;

  const TaskTile({
    super.key,
    required this.task,
    this.assignee,
    this.creator,
    this.remarksCount = 0,
    this.additionalAssigneeNames,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOverdue =
        task.status == TaskStatus.ongoing &&
        task.deadline.isBefore(DateTime.now());

    // Calculate days until/since deadline
    final daysUntil = task.deadline.difference(DateTime.now()).inDays;
    final isUrgent = daysUntil <= 1 && task.status == TaskStatus.ongoing;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.neutral800 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color:
                  isOverdue
                      ? Colors.red.withValues(alpha: 0.5)
                      : isUrgent
                      ? Colors.orange.withValues(alpha: 0.5)
                      : (isDark ? AppColors.neutral700 : AppColors.neutral200),
              width: isOverdue || isUrgent ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.black : Colors.grey).withValues(
                  alpha: 0.08,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Title + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge(status: _getStatusType(task.status, isOverdue)),
                ],
              ),

              // Row 2: Description (if exists)
              if (task.subtitle.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  task.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: AppSpacing.md),

              // Row 3: Metadata chips
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  // Due date chip
                  _buildChip(
                    context,
                    icon: Icons.schedule,
                    label: _formatDeadline(task.deadline),
                    iconColor:
                        isOverdue
                            ? Colors.red
                            : isUrgent
                            ? Colors.orange
                            : (isDark
                                ? AppColors.neutral400
                                : AppColors.neutral500),
                    textColor:
                        isOverdue
                            ? Colors.red
                            : isUrgent
                            ? Colors.orange
                            : null,
                    fontWeight: isOverdue || isUrgent ? FontWeight.w600 : null,
                  ),

                  // Remarks count (if any)
                  if (remarksCount > 0)
                    _buildChip(
                      context,
                      icon: Icons.chat_bubble_outline,
                      label: '$remarksCount',
                      iconColor: theme.colorScheme.primary,
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Row 4: Assignee and Creator
              Row(
                children: [
                  // Assignee section
                  Expanded(
                    child: Row(
                      children: [
                        _buildAvatar(theme, assignee, 14),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned to',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      isDark
                                          ? AppColors.neutral500
                                          : AppColors.neutral400,
                                  fontSize: 9,
                                ),
                              ),
                              Text(
                                _buildAssigneeLabel(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
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

                  // Creator section
                  if (creator != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'by ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                isDark
                                    ? AppColors.neutral500
                                    : AppColors.neutral400,
                          ),
                        ),
                        Text(
                          creator!.name.split(' ').first,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color:
                                isDark
                                    ? AppColors.neutral300
                                    : AppColors.neutral700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildAssigneeLabel() {
    final name = assignee?.name ?? 'Unknown';
    if (additionalAssigneeNames != null &&
        additionalAssigneeNames!.isNotEmpty) {
      return '$name +${additionalAssigneeNames!.length}';
    }
    return name;
  }

  Widget _buildAvatar(ThemeData theme, UserModel? user, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage:
          user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
      child:
          user?.avatarUrl == null
              ? Text(
                user?.name.isNotEmpty == true
                    ? user!.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              )
              : null,
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    Color? iconColor,
    Color? textColor,
    FontWeight? fontWeight,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color:
              iconColor ??
              (isDark ? AppColors.neutral400 : AppColors.neutral500),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color:
                textColor ??
                (isDark ? AppColors.neutral300 : AppColors.neutral600),
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);

    if (deadlineDate == today) {
      return 'Today ${DateFormat.jm().format(deadline)}';
    } else if (deadlineDate == tomorrow) {
      return 'Tomorrow ${DateFormat.jm().format(deadline)}';
    } else if (deadline.isBefore(now)) {
      final daysAgo = now.difference(deadline).inDays;
      if (daysAgo == 0) {
        return 'Overdue ${DateFormat.jm().format(deadline)}';
      }
      return '$daysAgo day${daysAgo > 1 ? 's' : ''} overdue';
    } else {
      return DateFormat('MMM d, h:mm a').format(deadline);
    }
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
