import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/approval_request_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/user_model.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/repositories/approval_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../common/cards/app_card.dart';

class RescheduleApprovalScreen extends StatefulWidget {
  const RescheduleApprovalScreen({super.key});

  @override
  State<RescheduleApprovalScreen> createState() =>
      _RescheduleApprovalScreenState();
}

class _RescheduleApprovalScreenState extends State<RescheduleApprovalScreen> {
  final ApprovalRepository _approvalRepository = ApprovalRepository();
  Stream<List<ApprovalRequestModel>>? _requestsStream;

  Stream<List<ApprovalRequestModel>> _getRequestsStream(String userId) {
    _requestsStream ??= _approvalRepository.getPendingRescheduleRequestsStream(
      userId,
    );
    return _requestsStream!;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reschedule Requests')),
      body: StreamBuilder<List<ApprovalRequestModel>>(
        stream: _getRequestsStream(currentUser.id),
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

          final requests = snapshot.data!;

          if (requests.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              return _RescheduleRequestCard(
                request: requests[index],
                approverId: currentUser.id,
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
            Icons.check_circle_outline,
            size: 80,
            color: isDark ? AppColors.neutral600 : AppColors.neutral400,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No pending requests',
            style: theme.textTheme.titleLarge?.copyWith(
              color: isDark ? AppColors.neutral400 : AppColors.neutral600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'All reschedule requests have been handled',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.neutral500 : AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RescheduleRequestCard extends StatefulWidget {
  final ApprovalRequestModel request;
  final String approverId;

  const _RescheduleRequestCard({
    required this.request,
    required this.approverId,
  });

  @override
  State<_RescheduleRequestCard> createState() => _RescheduleRequestCardState();
}

class _RescheduleRequestCardState extends State<_RescheduleRequestCard> {
  final _taskRepository = TaskRepository();
  final _userRepository = UserRepository();
  final _approvalRepository = ApprovalRepository();
  bool _isProcessing = false;

  Future<void> _handleApprove() async {
    setState(() => _isProcessing = true);
    try {
      await _approvalRepository.approveRescheduleRequest(
        requestId: widget.request.id,
        approverId: widget.approverId,
        taskId: widget.request.targetId,
        newDeadline: widget.request.newDeadline!,
      );

      // Create log entry
      await _approvalRepository.createRescheduleLog(
        taskId: widget.request.targetId,
        requestedBy: widget.request.requesterId,
        originalDeadline: widget.request.originalDeadline!,
        newDeadline: widget.request.newDeadline!,
        approvedBy: widget.approverId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reschedule approved'),
            backgroundColor: Colors.green,
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reject Request'),
            content: const Text(
              'Are you sure you want to reject this reschedule request?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Reject'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await _approvalRepository.rejectRescheduleRequest(
        requestId: widget.request.id,
        approverId: widget.approverId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reschedule rejected'),
            backgroundColor: Colors.orange,
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
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      type: AppCardType.standard,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Info
            StreamBuilder<TaskModel?>(
              stream: _taskRepository.getTaskStream(widget.request.targetId),
              builder: (context, taskSnapshot) {
                final task = taskSnapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            task?.title ?? 'Loading...',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (task?.subtitle.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          task!.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                isDark
                                    ? AppColors.neutral400
                                    : AppColors.neutral600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Requester Info
            StreamBuilder<UserModel?>(
              stream: _userRepository.getUserStream(widget.request.requesterId),
              builder: (context, userSnapshot) {
                final requester = userSnapshot.data;
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Text(
                        requester?.name.isNotEmpty == true
                            ? requester!.name[0]
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Requested by',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                isDark
                                    ? AppColors.neutral500
                                    : AppColors.neutral500,
                          ),
                        ),
                        Text(
                          requester?.name ?? 'Loading...',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (widget.request.createdAt != null)
                      Text(
                        _formatTimeAgo(widget.request.createdAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              isDark
                                  ? AppColors.neutral500
                                  : AppColors.neutral500,
                        ),
                      ),
                  ],
                );
              },
            ),

            const SizedBox(height: AppSpacing.md),
            Divider(
              color: isDark ? AppColors.neutral700 : AppColors.neutral200,
            ),
            const SizedBox(height: AppSpacing.md),

            // Deadline Change
            Row(
              children: [
                Expanded(
                  child: _buildDeadlineColumn(
                    context,
                    'Current',
                    widget.request.originalDeadline!,
                    Colors.grey,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildDeadlineColumn(
                    context,
                    'Requested',
                    widget.request.newDeadline!,
                    theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            // Reason (if provided)
            if (widget.request.reason?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isDark
                                ? AppColors.neutral500
                                : AppColors.neutral500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.request.reason!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _handleReject,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _handleApprove,
                    icon:
                        _isProcessing
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineColumn(
    BuildContext context,
    String label,
    DateTime deadline,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat('MMM d, yyyy').format(deadline),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          DateFormat('h:mm a').format(deadline),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 60) {
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
