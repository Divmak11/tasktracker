import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/theme_provider.dart';
import '../../data/models/user_model.dart';
import '../../data/services/calendar_service.dart';
import '../common/cards/app_card.dart';
import '../common/buttons/app_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CalendarService _calendarService = CalendarService();
  bool _isCalendarLoading = false;
  bool _isTestingNotification = false;

  Future<void> _testNotification(UserModel? user) async {
    if (user == null) return;

    setState(() => _isTestingNotification = true);

    try {
      // Get current FCM token
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();

      // Check if token is stored in Firestore
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.id)
              .get();
      final storedToken = userDoc.data()?['fcmToken'];

      // Show diagnostic info
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('FCM Diagnostic'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDiagRow('User ID', user.id),
                      const SizedBox(height: 8),
                      _buildDiagRow(
                        'FCM Token (device)',
                        token != null
                            ? '${token.substring(0, 20)}...'
                            : 'NULL ❌',
                      ),
                      const SizedBox(height: 8),
                      _buildDiagRow(
                        'FCM Token (stored)',
                        storedToken != null
                            ? '${storedToken.substring(0, 20)}...'
                            : 'NULL ❌',
                      ),
                      const SizedBox(height: 8),
                      _buildDiagRow(
                        'Tokens Match',
                        token == storedToken ? 'YES ✅' : 'NO ❌',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'To test notifications:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('1. Check Firebase Console → Functions logs'),
                      const Text('2. Create a task assigned to this user'),
                      const Text('3. Look for "Notification sent to user" log'),
                      const SizedBox(height: 16),
                      if (token == null || storedToken == null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '⚠️ FCM token is missing. Notifications will NOT work. '
                            'Try logging out and back in.',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                actions: [
                  if (token != null && storedToken == null)
                    TextButton(
                      onPressed: () async {
                        // Force save token
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.id)
                            .update({'fcmToken': token});
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('FCM token saved! Try again.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text('Save Token Now'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isTestingNotification = false);
    }
  }

  Widget _buildDiagRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              color: value.contains('❌') ? Colors.red : null,
            ),
          ),
        ),
      ],
    );
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

            // Debug Section (for testing)
            Text(
              'Debug & Testing',
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
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('Test Push Notification'),
                    subtitle: const Text('Check FCM token & send test'),
                    trailing:
                        _isTestingNotification
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.chevron_right),
                    onTap:
                        _isTestingNotification
                            ? null
                            : () => _testNotification(user),
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
