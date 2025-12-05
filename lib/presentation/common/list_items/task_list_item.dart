import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_spacing.dart';
import '../cards/app_card.dart';
import '../badges/status_badge.dart';

class TaskListItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final DateTime deadline;
  final StatusType status;
  final String? assigneeName;
  final String? assigneeAvatarUrl;
  final VoidCallback? onTap;
  final bool isOverdue;

  const TaskListItem({
    super.key,
    required this.title,
    this.subtitle,
    required this.deadline,
    required this.status,
    this.assigneeName,
    this.assigneeAvatarUrl,
    this.onTap,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM d, h:mm a');

    return AppCard(
      onTap: onTap,
      type: AppCardType.standard,
      padding: const EdgeInsets.all(AppSpacing.md),
      border: isOverdue
          ? Border.all(
              color: (isDark ? AppColors.errorDark : AppColors.errorLight)
                  .withValues(alpha: 0.5),
              width: 1)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: status == StatusType.completed
                            ? TextDecoration.lineThrough
                            : null,
                        color: status == StatusType.completed
                            ? (isDark
                                ? AppColors.neutral500
                                : AppColors.neutral400)
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.neutral400
                              : AppColors.neutral500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 14,
                color: isOverdue
                    ? (isDark ? AppColors.errorDark : AppColors.errorLight)
                    : (isDark ? AppColors.neutral400 : AppColors.neutral500),
              ),
              const SizedBox(width: 4),
              Text(
                dateFormat.format(deadline),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isOverdue
                      ? (isDark ? AppColors.errorDark : AppColors.errorLight)
                      : (isDark ? AppColors.neutral400 : AppColors.neutral500),
                  fontWeight: isOverdue ? FontWeight.w600 : null,
                ),
              ),
              const Spacer(),
              if (assigneeName != null) ...[
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                    image: assigneeAvatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(assigneeAvatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: assigneeAvatarUrl == null
                      ? Text(
                          assigneeName![0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  assigneeName!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDark ? AppColors.neutral300 : AppColors.neutral600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
