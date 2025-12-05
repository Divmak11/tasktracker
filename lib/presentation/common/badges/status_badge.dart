import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_spacing.dart';

enum StatusType { ongoing, completed, overdue, cancelled, pending }

class StatusBadge extends StatelessWidget {
  final StatusType status;
  final String? label;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final isDark = theme.brightness == Brightness.dark;
    
    Color backgroundColor;
    Color foregroundColor;
    String text;
    IconData icon;

    switch (status) {
      case StatusType.ongoing:
        final color = isDark ? AppColors.infoDark : AppColors.infoLight;
        backgroundColor = color.withValues(alpha: 0.1);
        foregroundColor = color;
        text = 'Ongoing';
        icon = Icons.access_time_rounded;
        break;
      case StatusType.completed:
        final color = isDark ? AppColors.successDark : AppColors.successLight;
        backgroundColor = color.withValues(alpha: 0.1);
        foregroundColor = color;
        text = 'Completed';
        icon = Icons.check_circle_outline_rounded;
        break;
      case StatusType.overdue:
        final color = isDark ? AppColors.errorDark : AppColors.errorLight;
        backgroundColor = color.withValues(alpha: 0.1);
        foregroundColor = color;
        text = 'Overdue';
        icon = Icons.warning_amber_rounded;
        break;
      case StatusType.cancelled:
        backgroundColor = isDark ? AppColors.neutral700 : AppColors.neutral200;
        foregroundColor = isDark ? AppColors.neutral400 : AppColors.neutral600;
        text = 'Cancelled';
        icon = Icons.cancel_outlined;
        break;
      case StatusType.pending:
        final color = isDark ? AppColors.warningDark : AppColors.warningLight;
        backgroundColor = color.withValues(alpha: 0.1);
        foregroundColor = color;
        text = 'Pending';
        icon = Icons.hourglass_empty_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: foregroundColor,
          ),
          const SizedBox(width: 4),
          Text(
            label ?? text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
