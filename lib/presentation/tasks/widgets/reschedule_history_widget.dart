import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/approval_request_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/approval_repository.dart';
import '../../../data/repositories/user_repository.dart';

/// Displays reschedule history for a task: count badge in a collapsible header
/// + an expandable list of all past reschedule entries (approved/rejected/pending).
///
/// Self-contained: manages its own streams and expand state.
/// Drop it in with a single line: `RescheduleHistoryWidget(taskId: taskId)`
class RescheduleHistoryWidget extends StatefulWidget {
  final String taskId;

  const RescheduleHistoryWidget({super.key, required this.taskId});

  @override
  State<RescheduleHistoryWidget> createState() =>
      _RescheduleHistoryWidgetState();
}

class _RescheduleHistoryWidgetState extends State<RescheduleHistoryWidget> {
  // Repositories and streams are STABLE — initialised once in initState.
  // Never instantiate these inside build() to avoid stream reload loops.
  late final ApprovalRepository _approvalRepository;
  late final UserRepository _userRepository;
  late final Stream<List<ApprovalRequestModel>> _historyStream;

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _approvalRepository = ApprovalRepository();
    _userRepository = UserRepository();
    _historyStream = _approvalRepository.getTaskRescheduleHistoryStream(
      widget.taskId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ApprovalRequestModel>>(
      stream: _historyStream,
      builder: (context, snapshot) {
        // Hide while loading or on error — graceful degradation.
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final entries = snapshot.data!;
        final count = entries.length;

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, theme, isDark, count),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? _buildHistoryList(context, theme, isDark, entries)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    int count,
  ) {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(
            'Reschedule History',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Count badge — same pill style as Remarks count badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs / 2,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              count.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          // Expand / collapse icon with smooth rotation
          AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 250),
            child: Icon(
              Icons.expand_more,
              size: 22,
              color: isDark ? AppColors.neutral400 : AppColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<ApprovalRequestModel> entries,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral900 : AppColors.neutral50,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: isDark ? AppColors.neutral800 : AppColors.neutral200,
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: isDark ? AppColors.neutral800 : AppColors.neutral200,
        ),
        itemBuilder: (context, index) {
          return _RescheduleHistoryEntry(
            entry: entries[index],
            userRepository: _userRepository,
            isLast: index == entries.length - 1,
          );
        },
      ),
    );
  }
}

/// A single row in the reschedule history list.
/// Stateless — all data comes from the parent stream.
class _RescheduleHistoryEntry extends StatelessWidget {
  final ApprovalRequestModel entry;
  final UserRepository userRepository;
  final bool isLast;

  const _RescheduleHistoryEntry({
    required this.entry,
    required this.userRepository,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Status badge + time-ago
          Row(
            children: [
              _buildStatusBadge(context, entry.status),
              const Spacer(),
              if (entry.createdAt != null)
                Text(
                  _formatTimeAgo(entry.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.neutral500
                        : AppColors.neutral500,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Row 2: Original deadline → New deadline
          Row(
            children: [
              _buildDateColumn(
                context,
                label: 'Was',
                date: entry.originalDeadline,
                color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                theme: theme,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                ),
                child: Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: isDark
                      ? AppColors.neutral500
                      : AppColors.neutral400,
                ),
              ),
              _buildDateColumn(
                context,
                label: 'Requested',
                date: entry.newDeadline,
                color: theme.colorScheme.primary,
                theme: theme,
              ),
            ],
          ),

          // Row 3: Requested by (async user lookup)
          const SizedBox(height: AppSpacing.xs),
          StreamBuilder<UserModel?>(
            stream: userRepository.getUserStream(entry.requesterId),
            builder: (context, userSnapshot) {
              final isLoading =
                  userSnapshot.connectionState == ConnectionState.waiting;
              final isDeleted =
                  userSnapshot.connectionState == ConnectionState.active &&
                      userSnapshot.data == null;
              final name = userSnapshot.data?.name ??
                  (isLoading ? 'Loading…' : (isDeleted ? 'Deleted User' : '—'));

              return Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 13,
                    color: isDark
                        ? AppColors.neutral500
                        : AppColors.neutral500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Requested by $name',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.neutral500
                          : AppColors.neutral500,
                      fontStyle: isDeleted ? FontStyle.italic : null,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),

          // Row 4: Reason (if present)
          if (entry.reason?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.neutral800
                    : AppColors.neutral200,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                '"${entry.reason}"',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDateColumn(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required Color color,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date != null
                ? DateFormat('MMM d, yyyy').format(date)
                : 'N/A',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          if (date != null)
            Text(
              DateFormat('h:mm a').format(date),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context,
    ApprovalRequestStatus status,
  ) {
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
        icon = Icons.check_circle_outline;
        break;
      case ApprovalRequestStatus.rejected:
        color = Colors.red;
        text = 'Rejected';
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dateTime);
  }
}
