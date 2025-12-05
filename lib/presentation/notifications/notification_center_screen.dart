import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/notification_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/repositories/notification_repository.dart';
import '../common/cards/app_card.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final notificationRepository = NotificationRepository();

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'mark_all_read') {
                await notificationRepository.markAllAsRead(currentUser.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All marked as read')),
                  );
                }
              } else if (value == 'clear_all') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Clear All'),
                        content: const Text('Delete all notifications?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                );
                if (confirm == true) {
                  await notificationRepository.clearAllNotifications(
                    currentUser.id,
                  );
                }
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Text('Mark all as read'),
                  ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Text('Clear all'),
                  ),
                ],
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: notificationRepository.getUserNotificationsStream(
          currentUser.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: AppSpacing.md),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                onTap:
                    () => _handleNotificationTap(
                      context,
                      notification,
                      notificationRepository,
                    ),
                onDismiss:
                    () => notificationRepository.deleteNotification(
                      notification.id,
                    ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: isDark ? AppColors.neutral600 : AppColors.neutral400,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No notifications',
            style: theme.textTheme.titleLarge?.copyWith(
              color: isDark ? AppColors.neutral400 : AppColors.neutral600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You\'re all caught up!',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.neutral500 : AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(
    BuildContext context,
    NotificationModel notification,
    NotificationRepository repository,
  ) async {
    // Mark as read
    if (!notification.isRead) {
      await repository.markAsRead(notification.id);
    }

    // Navigate based on type
    if (notification.taskId != null && context.mounted) {
      context.push('/task/${notification.taskId}');
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: AppCard(
        type: AppCardType.standard,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border:
                !notification.isRead
                    ? Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 4,
                      ),
                    )
                    : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _getNotificationColor(
                    notification.type,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  size: 20,
                  color: _getNotificationColor(notification.type),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isDark
                                ? AppColors.neutral400
                                : AppColors.neutral600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatTime(notification.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isDark
                                ? AppColors.neutral500
                                : AppColors.neutral500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return Icons.assignment;
      case NotificationType.taskCompleted:
        return Icons.check_circle;
      case NotificationType.taskCancelled:
        return Icons.cancel;
      case NotificationType.rescheduleRequest:
        return Icons.schedule;
      case NotificationType.rescheduleApproved:
        return Icons.thumb_up;
      case NotificationType.rescheduleRejected:
        return Icons.thumb_down;
      case NotificationType.userApproved:
        return Icons.verified_user;
      case NotificationType.deadlineReminder:
        return Icons.alarm;
      case NotificationType.taskOverdue:
        return Icons.warning;
      case NotificationType.remark:
        return Icons.comment;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return Colors.blue;
      case NotificationType.taskCompleted:
        return Colors.green;
      case NotificationType.taskCancelled:
        return Colors.grey;
      case NotificationType.rescheduleRequest:
        return Colors.orange;
      case NotificationType.rescheduleApproved:
        return Colors.green;
      case NotificationType.rescheduleRejected:
        return Colors.red;
      case NotificationType.userApproved:
        return Colors.purple;
      case NotificationType.deadlineReminder:
        return Colors.amber;
      case NotificationType.taskOverdue:
        return Colors.red;
      case NotificationType.remark:
        return Colors.teal;
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}
