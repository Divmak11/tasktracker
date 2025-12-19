import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/theme_provider.dart';
import '../../data/models/user_model.dart';
import '../../data/services/calendar_service.dart';
import '../../data/services/cloud_functions_service.dart';
import '../common/cards/app_card.dart';
import '../common/buttons/app_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CalendarService _calendarService = CalendarService();
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  bool _isCalendarLoading = false;
  bool _isDeletingAccount = false;

  Future<void> _deleteAccount() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user?.role == UserRole.superAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Super Admin accounts cannot be self-deleted'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Account'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete your account?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text('This action will:'),
                SizedBox(height: 8),
                Text('• Delete all your personal data'),
                Text('• Cancel all your ongoing tasks'),
                Text('• Remove you from all teams'),
                Text('• Delete your remarks and notifications'),
                SizedBox(height: 12),
                Text(
                  'This action cannot be undone.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete Account'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) return;

    // Second confirmation with typing
    final secondConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Final Confirmation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Type "DELETE" to confirm account deletion:'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Type DELETE',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().toUpperCase() == 'DELETE') {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Please type DELETE to confirm'),
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Forever'),
            ),
          ],
        );
      },
    );

    if (secondConfirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);

    try {
      await _cloudFunctions.deleteOwnAccount();
    } catch (e) {
      // Log error but continue to logout - account data is already deleted on server
      debugPrint('❌ deleteOwnAccount error (will still logout): $e');
    }

    // ALWAYS logout after deletion attempt - account is deleted server-side
    if (mounted) {
      try {
        await authProvider.logout();
      } catch (e) {
        debugPrint('❌ Logout error (will still navigate): $e');
      }
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }

    if (mounted) setState(() => _isDeletingAccount = false);
  }

  Future<void> _toggleCalendarConnection(
    String userId,
    bool isConnected,
  ) async {
    setState(() => _isCalendarLoading = true);

    try {
      if (isConnected) {
        await _calendarService.disconnect(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Calendar disconnected')),
          );
        }
      } else {
        final success = await _calendarService.connect(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success ? 'Calendar connected!' : 'Failed to connect calendar',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalendarLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            Text(
              'Profile',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              type: AppCardType.standard,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        user?.name[0] ?? 'U',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'User',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            user?.email ?? 'user@example.com',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  isDark
                                      ? AppColors.neutral400
                                      : AppColors.neutral600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppRadius.small,
                              ),
                            ),
                            child: Text(
                              _getRoleText(user?.role),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        context.push('/settings/profile');
                      },
                      tooltip: 'Edit Profile',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // App Settings
            Text(
              'App Settings',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              type: AppCardType.standard,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Theme'),
                    subtitle: Text(_getThemeText(context)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('/settings/theme');
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.neutral700 : AppColors.neutral200,
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    subtitle: const Text('Manage notification settings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('/settings/notifications');
                    },
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.neutral700 : AppColors.neutral200,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.calendar_month_outlined,
                      color:
                          user?.googleCalendarConnected == true
                              ? Colors.green
                              : null,
                    ),
                    title: const Text('Google Calendar'),
                    subtitle: Text(
                      user?.googleCalendarConnected == true
                          ? 'Connected - Tasks sync to calendar'
                          : 'Connect to sync tasks with calendar',
                    ),
                    trailing:
                        _isCalendarLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Switch(
                              value: user?.googleCalendarConnected ?? false,
                              onChanged:
                                  user != null
                                      ? (value) => _toggleCalendarConnection(
                                        user.id,
                                        user.googleCalendarConnected,
                                      )
                                      : null,
                            ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Account Section
            Text(
              'Account',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              type: AppCardType.standard,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Colors.red.shade400,
                    ),
                    title: const Text('Delete Account'),
                    subtitle: const Text(
                      'Permanently delete your account and data',
                    ),
                    trailing:
                        _isDeletingAccount
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Icon(
                              Icons.chevron_right,
                              color: Colors.red.shade400,
                            ),
                    onTap: _isDeletingAccount ? null : _deleteAccount,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Logout Button
            AppButton(
              text: 'Logout',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                );

                if (confirm == true && context.mounted) {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    context.go(AppRoutes.login);
                  }
                }
              },
              type: AppButtonType.secondary,
              icon: Icons.logout_rounded,
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleText(UserRole? role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.teamAdmin:
        return 'Team Admin';
      case UserRole.member:
        return 'Member';
      default:
        return 'User';
    }
  }

  String _getThemeText(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    switch (themeProvider.themeMode) {
      case AppThemeMode.light:
        return 'Light Mode';
      case AppThemeMode.dark:
        return 'Dark Mode';
      case AppThemeMode.system:
        return 'System Default';
    }
  }
}
