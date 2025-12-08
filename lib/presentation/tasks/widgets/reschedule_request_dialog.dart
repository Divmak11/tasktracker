import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/task_model.dart';
import '../../../data/services/cloud_functions_service.dart';
import '../../common/buttons/app_button.dart';
import '../../common/inputs/app_text_field.dart';

class RescheduleRequestDialog extends StatefulWidget {
  final TaskModel task;

  const RescheduleRequestDialog({super.key, required this.task});

  @override
  State<RescheduleRequestDialog> createState() =>
      _RescheduleRequestDialogState();
}

class _RescheduleRequestDialogState extends State<RescheduleRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _cloudFunctions = CloudFunctionsService();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current deadline + 1 day, or tomorrow if overdue
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final taskTomorrow = widget.task.deadline.add(const Duration(days: 1));

    // Use the later of tomorrow or task deadline + 1 day
    _selectedDate = taskTomorrow.isAfter(tomorrow) ? taskTomorrow : tomorrow;
    _selectedTime = TimeOfDay.fromDateTime(widget.task.deadline);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  DateTime get _newDeadline {
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime?.hour ?? 23,
      _selectedTime?.minute ?? 59,
    );
  }

  bool get _isValidDeadline {
    return _selectedDate != null &&
        _newDeadline.isAfter(DateTime.now()) &&
        _newDeadline.isAfter(widget.task.deadline);
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // Ensure initialDate is not before firstDate (handles overdue tasks)
    DateTime initialDate;
    if (_selectedDate != null && _selectedDate!.isBefore(today)) {
      initialDate = tomorrow;
    } else {
      initialDate = _selectedDate ?? tomorrow;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitRequest() async {
    if (!_isValidDeadline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New deadline must be later than current deadline'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Capture values before popping
    final newDeadline = _newDeadline;
    final reason = _reasonController.text.trim().isEmpty
        ? null
        : _reasonController.text.trim();
    final taskId = widget.task.id;

    // OPTIMISTIC UPDATE: Close dialog and show success immediately
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reschedule request submitted'),
        backgroundColor: Colors.green,
      ),
    );

    // Fire cloud function in background
    _cloudFunctions.requestReschedule(
      taskId: taskId,
      newDeadline: newDeadline,
      reason: reason,
    ).catchError((error) {
      debugPrint('Failed to submit reschedule request: $error');
      return <String, dynamic>{};
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(Icons.schedule, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Request Reschedule',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Current Deadline
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_busy,
                        size: 20,
                        color:
                            isDark
                                ? AppColors.neutral400
                                : AppColors.neutral600,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Deadline',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isDark
                                      ? AppColors.neutral400
                                      : AppColors.neutral600,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'MMM d, yyyy • h:mm a',
                            ).format(widget.task.deadline),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // New Deadline Selection
                Text(
                  'New Deadline',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _selectedDate != null
                              ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                              : 'Select Date',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectTime,
                        icon: const Icon(Icons.access_time, size: 18),
                        label: Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                              : 'Select Time',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_selectedDate != null && !_isValidDeadline) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'New deadline must be later than current deadline',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.md),

                // Reason Field
                AppTextField(
                  label: 'Reason (Optional)',
                  hint: 'Why do you need more time?',
                  controller: _reasonController,
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        text: 'Submit Request',
                        onPressed:
                            _isSubmitting || !_isValidDeadline
                                ? null
                                : _submitRequest,
                        isLoading: _isSubmitting,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
