import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/approval_request_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/approval_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../common/cards/app_card.dart';

class RescheduleLogScreen extends StatefulWidget {
  const RescheduleLogScreen({super.key});

  @override
  State<RescheduleLogScreen> createState() => _RescheduleLogScreenState();
}

class _RescheduleLogScreenState extends State<RescheduleLogScreen> {
  final _approvalRepository = ApprovalRepository();
  ApprovalRequestStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reschedule Log'),
        actions: [
          PopupMenuButton<ApprovalRequestStatus?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by status',
            onSelected: (status) => setState(() => _selectedStatus = status),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: null, child: Text('All')),
                  const PopupMenuItem(
                    value: ApprovalRequestStatus.pending,
                    child: Text('Pending'),
                  ),
                  const PopupMenuItem(
                    value: ApprovalRequestStatus.approved,
                    child: Text('Approved'),
                  ),
                  const PopupMenuItem(
                    value: ApprovalRequestStatus.rejected,
                    child: Text('Rejected'),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chip
          if (_selectedStatus != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingMobile,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Filtering by:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Chip(
                    label: Text(_getStatusLabel(_selectedStatus!)),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => setState(() => _selectedStatus = null),
                    backgroundColor: _getStatusColor(
                      _selectedStatus!,
                    ).withValues(alpha: 0.1),
                    labelStyle: TextStyle(
                      color: _getStatusColor(_selectedStatus!),
                    ),
                  ),
                ],
              ),
            ),

          // List
          Expanded(
            child: StreamBuilder<List<ApprovalRequestModel>>(
              stream: _approvalRepository.getAllRescheduleRequestsStream(
                status: _selectedStatus,
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

                final requests = snapshot.data!;

                if (requests.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenPaddingMobile),
                  itemCount: requests.length,
                  separatorBuilder:
                      (_, __) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    return _RescheduleLogCard(request: requests[index]);
                  },
                );
              },
            ),
          ),
        ],
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
            Icons.history,
            size: 80,
            color: isDark ? AppColors.neutral600 : AppColors.neutral400,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No reschedule requests',
            style: theme.textTheme.titleLarge?.copyWith(
              color: isDark ? AppColors.neutral400 : AppColors.neutral600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _selectedStatus != null
                ? 'No ${_getStatusLabel(_selectedStatus!).toLowerCase()} requests found'
                : 'Reschedule requests will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.neutral500 : AppColors.neutral500,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(ApprovalRequestStatus status) {
    switch (status) {
      case ApprovalRequestStatus.pending:
        return 'Pending';
      case ApprovalRequestStatus.approved:
        return 'Approved';
      case ApprovalRequestStatus.rejected:
        return 'Rejected';
    }
  }

  Color _getStatusColor(ApprovalRequestStatus status) {
    switch (status) {
      case ApprovalRequestStatus.pending:
        return Colors.orange;
      case ApprovalRequestStatus.approved:
        return Colors.green;
      case ApprovalRequestStatus.rejected:
        return Colors.red;
    }
  }
}

class _RescheduleLogCard extends StatelessWidget {
  final ApprovalRequestModel request;

  const _RescheduleLogCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final taskRepository = TaskRepository();
    final userRepository = UserRepository();

    return AppCard(
      type: AppCardType.standard,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                _buildStatusBadge(context, request.status),
                const Spacer(),
                if (request.createdAt != null)
                  Text(
                    DateFormat('MMM d, yyyy').format(request.createdAt!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          isDark ? AppColors.neutral500 : AppColors.neutral500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Task Title
            StreamBuilder<TaskModel?>(
              stream: taskRepository.getTaskStream(request.targetId),
              builder: (context, taskSnapshot) {
                final task = taskSnapshot.data;
                return Row(
                  children: [
                    Icon(
                      Icons.task_alt,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        task?.title ?? 'Task deleted',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            // Requester
            StreamBuilder<UserModel?>(
              stream: userRepository.getUserStream(request.requesterId),
              builder: (context, userSnapshot) {
                final requester = userSnapshot.data;
                return Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color:
                          isDark ? AppColors.neutral400 : AppColors.neutral600,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Requested by: ${userSnapshot.connectionState == ConnectionState.waiting ? 'Loading...' : (requester?.name ?? 'Deleted User')}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isDark
                                ? AppColors.neutral400
                                : AppColors.neutral600,
                        fontStyle:
                            (requester == null &&
                                    userSnapshot.connectionState ==
                                        ConnectionState.active)
                                ? FontStyle.italic
                                : null,
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
            const SizedBox(height: AppSpacing.sm),

            // Deadline Change
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              isDark
                                  ? AppColors.neutral500
                                  : AppColors.neutral500,
                        ),
                      ),
                      Text(
                        request.originalDeadline != null
                            ? DateFormat(
                              'MMM d, h:mm a',
                            ).format(request.originalDeadline!)
                            : 'N/A',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Requested',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              isDark
                                  ? AppColors.neutral500
                                  : AppColors.neutral500,
                        ),
                      ),
                      Text(
                        request.newDeadline != null
                            ? DateFormat(
                              'MMM d, h:mm a',
                            ).format(request.newDeadline!)
                            : 'N/A',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Approver info (if resolved)
            if (request.status != ApprovalRequestStatus.pending &&
                request.approverId != null) ...[
              const SizedBox(height: AppSpacing.sm),
              StreamBuilder<UserModel?>(
                stream: userRepository.getUserStream(request.approverId!),
                builder: (context, approverSnapshot) {
                  final approver = approverSnapshot.data;
                  final isDeleted =
                      approverSnapshot.connectionState ==
                          ConnectionState.active &&
                      approver == null;
                  return Text(
                    '${request.status == ApprovalRequestStatus.approved ? 'Approved' : 'Rejected'} by: ${approverSnapshot.connectionState == ConnectionState.waiting ? 'Loading...' : (approver?.name ?? 'Deleted User')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          request.status == ApprovalRequestStatus.approved
                              ? Colors.green
                              : Colors.red,
                      fontWeight: FontWeight.w500,
                      fontStyle: isDeleted ? FontStyle.italic : null,
                    ),
                  );
                },
              ),
            ],

            // Reason (if provided)
            if (request.reason?.isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Text(
                  '"${request.reason}"',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, ApprovalRequestStatus status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case ApprovalRequestStatus.pending:
        color = Colors.orange;
        text = 'Pending';
        icon = Icons.schedule;
        break;
      case ApprovalRequestStatus.approved:
        color = Colors.green;
        text = 'Approved';
        icon = Icons.check_circle;
        break;
      case ApprovalRequestStatus.rejected:
        color = Colors.red;
        text = 'Rejected';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
