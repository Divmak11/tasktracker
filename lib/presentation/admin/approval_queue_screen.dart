import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/user_model.dart';
import '../../data/services/notification_service.dart';
import '../../data/services/cloud_functions_service.dart';
import '../common/buttons/app_button.dart';
import '../common/cards/app_card.dart';

class ApprovalQueueScreen extends StatefulWidget {
  const ApprovalQueueScreen({super.key});

  @override
  State<ApprovalQueueScreen> createState() => _ApprovalQueueScreenState();
}

class _ApprovalQueueScreenState extends State<ApprovalQueueScreen> {
  final NotificationService _notificationService = NotificationService();
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();
  final Set<String> _processingUsers = {};

  int _previousPendingCount = 0;

  Future<void> _handleApprove(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Approve User'),
            content: Text('Approve access for ${user.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Approve'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      // Add to processing set to prevent double-clicks
      setState(() => _processingUsers.add(user.id));

      try {
        await _cloudFunctions.approveUserAccess(user.id);
        
        if (mounted) {
          NotificationService.showInAppNotification(
            context,
            title: 'User Approved',
            message: '${user.name} has been granted access',
            icon: Icons.check_circle,
            backgroundColor: Colors.green.shade700,
          );
        }
      } catch (error) {
        if (mounted) {
          final message =
              error is FirebaseFunctionsException
                  ? error.message ?? error.code
                  : error.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to approve: $message'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _handleApprove(user),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _processingUsers.remove(user.id));
        }
      }
    }
  }

  Future<void> _handleReject(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reject User'),
            content: Text('Reject access request from ${user.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reject'),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      // Add to processing set to prevent double-clicks
      setState(() => _processingUsers.add(user.id));

      // OPTIMISTIC UPDATE: Show success immediately
      NotificationService.showInAppNotification(
        context,
        title: 'User Rejected',
        message: '${user.name} access request has been rejected',
        icon: Icons.block,
        backgroundColor: Colors.orange.shade700,
      );

      // Fire cloud function in background
      _cloudFunctions.rejectUserAccess(user.id).catchError((error) {
        if (mounted) {
          final message =
              error is FirebaseFunctionsException
                  ? error.message ?? error.code
                  : error.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sync: $message'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _handleReject(user),
              ),
            ),
          );
          // Remove from processing on error so user can retry
          setState(() => _processingUsers.remove(user.id));
        }
        return <String, dynamic>{};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Queue'),
        automaticallyImplyLeading: true,
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _notificationService.listenForNewPendingUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pendingUsers = snapshot.data!;

          // Show notification if new pending users detected
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (pendingUsers.length > _previousPendingCount &&
                _previousPendingCount > 0) {
              final newCount = pendingUsers.length - _previousPendingCount;
              NotificationService.showInAppNotification(
                context,
                title: 'New Approval Request${newCount > 1 ? 's' : ''}',
                message:
                    '$newCount new user${newCount > 1 ? 's' : ''} waiting for approval',
                icon: Icons.notification_important,
                backgroundColor: Colors.blue.shade700,
              );
            }
            _previousPendingCount = pendingUsers.length;
          });

          if (pendingUsers.isEmpty) {
            return _buildEmptyState(theme);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
            itemCount: pendingUsers.length,
            separatorBuilder:
                (context, index) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final user = pendingUsers[index];
              final isProcessing = _processingUsers.contains(user.id);

              return AppCard(
                type: AppCardType.standard,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(
                              user.name.isNotEmpty
                                  ? user.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
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
                                  user.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Pending Approval',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.orange,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color:
                                isDark
                                    ? AppColors.neutral500
                                    : AppColors.neutral400,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Role: ${_getRoleText(user.role)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isDark
                                      ? AppColors.neutral500
                                      : AppColors.neutral400,
                            ),
                          ),
                          const Spacer(),
                          // Pending badge moved here for better visibility
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'PENDING',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              text: 'Approve',
                              onPressed:
                                  isProcessing
                                      ? () {}
                                      : () => _handleApprove(user),
                              type: AppButtonType.primary,
                              isLoading: isProcessing,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppButton(
                              text: 'Reject',
                              onPressed:
                                  isProcessing
                                      ? () {}
                                      : () => _handleReject(user),
                              type: AppButtonType.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('No Pending Requests', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'All user access requests have been processed',
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  theme.brightness == Brightness.dark
                      ? AppColors.neutral400
                      : AppColors.neutral600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getRoleText(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.teamAdmin:
        return 'Team Admin';
      case UserRole.member:
        return 'Member';
    }
  }
}
