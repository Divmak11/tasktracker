import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_spacing.dart';

enum AppCardType { standard, elevated }

class AppCard extends StatelessWidget {
  final Widget child;
  final AppCardType type;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.type = AppCardType.standard,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardDecoration = BoxDecoration(
      color: backgroundColor ??
          (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
      borderRadius: BorderRadius.circular(AppRadius.medium),
      border: type == AppCardType.standard
          ? (border ??
              Border.all(
                color: isDark ? AppColors.neutral700 : AppColors.neutral200,
                width: 1,
              ))
          : null,
      boxShadow: type == AppCardType.elevated
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
    );

    Widget content = Container(
      decoration: cardDecoration,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: content,
        ),
      );
    }

    return content;
  }
}
