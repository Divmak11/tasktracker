import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/remark_model.dart';
import '../../../data/models/user_model.dart';

class RemarkItem extends StatelessWidget {
  final RemarkModel remark;
  final UserModel? user;

  const RemarkItem({super.key, required this.remark, this.user});

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.neutral800 : AppColors.neutral200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              user?.name.substring(0, 1).toUpperCase() ?? '?',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and timestamp
                Row(
                  children: [
                    Text(
                      user?.name ?? '[Deleted User]',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '•',
                      style: TextStyle(
                        color:
                            isDark
                                ? AppColors.neutral500
                                : AppColors.neutral400,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _formatTimestamp(remark.createdAt ?? DateTime.now()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isDark
                                ? AppColors.neutral500
                                : AppColors.neutral400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Message
                Text(remark.message, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
