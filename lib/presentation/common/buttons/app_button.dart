import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_spacing.dart';

enum AppButtonType { primary, secondary, text, icon }

class AppButton extends StatelessWidget {
  final String? text;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final Widget? leadingWidget;
  final Color? customColor;

  const AppButton({
    super.key,
    this.text,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.leadingWidget,
    this.customColor,
  }) : assert(
         type == AppButtonType.icon ? icon != null : true,
         'Icon must be provided for icon button type',
       );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    Widget buttonContent =
        isLoading
            ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  type == AppButtonType.primary
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
                ),
              ),
            )
            : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leadingWidget != null && type != AppButtonType.icon) ...[
                  leadingWidget!,
                  const SizedBox(width: AppSpacing.sm),
                ] else if (icon != null && type != AppButtonType.icon) ...[
                  Icon(icon, size: AppIconSize.small),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (type == AppButtonType.icon)
                  Icon(icon, size: AppIconSize.medium)
                else
                  Flexible(
                    child: Text(
                      text ?? '',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color:
                            type == AppButtonType.primary
                                ? colorScheme.onPrimary
                                : (customColor ?? colorScheme.primary),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
              ],
            );

    Widget button;

    switch (type) {
      case AppButtonType.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: customColor ?? colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
            minimumSize: Size(isFullWidth ? double.infinity : 0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
          child: buttonContent,
        );
        break;

      case AppButtonType.secondary:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: customColor ?? colorScheme.primary,
            side: BorderSide(
              color:
                  customColor ??
                  (isDark ? AppColors.neutral700 : AppColors.neutral200),
            ),
            minimumSize: Size(isFullWidth ? double.infinity : 0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
          child: buttonContent,
        );
        break;

      case AppButtonType.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: customColor ?? colorScheme.primary,
            minimumSize: Size(isFullWidth ? double.infinity : 0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
          child: buttonContent,
        );
        break;

      case AppButtonType.icon:
        button = IconButton(
          onPressed: isLoading ? null : onPressed,
          icon: buttonContent,
          style: IconButton.styleFrom(
            foregroundColor: customColor ?? colorScheme.primary,
            backgroundColor:
                type == AppButtonType.primary
                    ? (customColor ?? colorScheme.primary)
                    : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
          ),
        );
        break;
    }

    return button;
  }
}
