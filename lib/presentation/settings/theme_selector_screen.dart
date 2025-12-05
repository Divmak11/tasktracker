import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/theme_provider.dart';
import '../common/cards/app_card.dart';

class ThemeSelectorScreen extends StatelessWidget {
  const ThemeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Theme')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
        children: [
          Text(
            'Choose your preferred theme',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? AppColors.neutral400 : AppColors.neutral600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildThemeOption(
            context,
            'Light Mode',
            'Always use light theme',
            Icons.light_mode_outlined,
            AppThemeMode.light,
            themeProvider.themeMode == AppThemeMode.light,
            () => themeProvider.setThemeMode(AppThemeMode.light),
          ),
          const SizedBox(height: AppSpacing.md),

          _buildThemeOption(
            context,
            'Dark Mode',
            'Always use dark theme',
            Icons.dark_mode_outlined,
            AppThemeMode.dark,
            themeProvider.themeMode == AppThemeMode.dark,
            () => themeProvider.setThemeMode(AppThemeMode.dark),
          ),
          const SizedBox(height: AppSpacing.md),

          _buildThemeOption(
            context,
            'System Default',
            'Follow system settings',
            Icons.brightness_auto_outlined,
            AppThemeMode.system,
            themeProvider.themeMode == AppThemeMode.system,
            () => themeProvider.setThemeMode(AppThemeMode.system),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    AppThemeMode mode,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      type: isSelected ? AppCardType.elevated : AppCardType.standard,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(
                icon,
                color:
                    isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
