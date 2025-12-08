import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/services/cloud_functions_service.dart';
import '../common/cards/app_card.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();

  bool _isSaving = false;

  // Notification preferences
  late bool _taskAssignments;
  late bool _taskCompletions;
  late bool _deadlineReminders;
  late bool _rescheduleRequests;
  late bool _teamUpdates;
  late bool _approvalUpdates;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() {
    final user = context.read<AuthProvider>().currentUser;
    final prefs = user?.notificationPreferences ?? {};

    setState(() {
      _taskAssignments = prefs['taskAssignments'] ?? true;
      _taskCompletions = prefs['taskCompletions'] ?? true;
      _deadlineReminders = prefs['deadlineReminders'] ?? true;
      _rescheduleRequests = prefs['rescheduleRequests'] ?? true;
      _teamUpdates = prefs['teamUpdates'] ?? true;
      _approvalUpdates = prefs['approvalUpdates'] ?? true;
    });
  }

  Future<void> _savePreferences() async {
    // Capture current preference values
    final prefs = {
      'taskAssignments': _taskAssignments,
      'taskCompletions': _taskCompletions,
      'deadlineReminders': _deadlineReminders,
      'rescheduleRequests': _rescheduleRequests,
      'teamUpdates': _teamUpdates,
      'approvalUpdates': _approvalUpdates,
    };

    // OPTIMISTIC UPDATE: Show success and navigate back immediately
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preferences saved'),
        backgroundColor: Colors.green,
      ),
    );
    context.pop();

    // Fire cloud function in background
    _cloudFunctions.updateProfile(
      notificationPreferences: prefs,
    ).catchError((error) {
      debugPrint('Failed to save preferences: $error');
      return <String, dynamic>{};
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(onPressed: _savePreferences, child: const Text('Save')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Choose which notifications you want to receive',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Task Notifications
            Text(
              'Task Notifications',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              type: AppCardType.standard,
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Task Assignments',
                    subtitle: 'When a new task is assigned to you',
                    value: _taskAssignments,
                    onChanged: (v) => setState(() => _taskAssignments = v),
                    icon: Icons.assignment_outlined,
                  ),
                  _buildDivider(isDark),
                  _buildSwitchTile(
                    title: 'Task Completions',
                    subtitle: 'When tasks you created are completed',
                    value: _taskCompletions,
                    onChanged: (v) => setState(() => _taskCompletions = v),
                    icon: Icons.check_circle_outline,
                  ),
                  _buildDivider(isDark),
                  _buildSwitchTile(
                    title: 'Deadline Reminders',
                    subtitle: 'Reminders before task deadlines',
                    value: _deadlineReminders,
                    onChanged: (v) => setState(() => _deadlineReminders = v),
                    icon: Icons.schedule_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Workflow Notifications
            Text(
              'Workflow Notifications',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              type: AppCardType.standard,
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Reschedule Requests',
                    subtitle: 'When someone requests to reschedule',
                    value: _rescheduleRequests,
                    onChanged: (v) => setState(() => _rescheduleRequests = v),
                    icon: Icons.update_outlined,
                  ),
                  _buildDivider(isDark),
                  _buildSwitchTile(
                    title: 'Team Updates',
                    subtitle: 'When you\'re added/removed from teams',
                    value: _teamUpdates,
                    onChanged: (v) => setState(() => _teamUpdates = v),
                    icon: Icons.group_outlined,
                  ),
                  _buildDivider(isDark),
                  _buildSwitchTile(
                    title: 'Approval Updates',
                    subtitle: 'When your requests are approved/rejected',
                    value: _approvalUpdates,
                    onChanged: (v) => setState(() => _approvalUpdates = v),
                    icon: Icons.approval_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Reset to defaults
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _taskAssignments = true;
                    _taskCompletions = true;
                    _deadlineReminders = true;
                    _rescheduleRequests = true;
                    _teamUpdates = true;
                    _approvalUpdates = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset to defaults')),
                  );
                },
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Defaults'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? AppColors.neutral700 : AppColors.neutral200,
    );
  }
}
