import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/remark_model.dart';
import '../../../data/repositories/remark_repository.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/services/notification_service.dart';
import '../../common/inputs/app_text_field.dart';
import '../../common/buttons/app_button.dart';

class AddRemarkDialog extends StatefulWidget {
  final String taskId;

  const AddRemarkDialog({super.key, required this.taskId});

  @override
  State<AddRemarkDialog> createState() => _AddRemarkDialogState();
}

class _AddRemarkDialogState extends State<AddRemarkDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _remarkRepository = RemarkRepository();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSubmitting = true);

      try {
        final authProvider = context.read<AuthProvider>();
        final userId = authProvider.currentUser?.id;

        if (userId == null) {
          throw Exception('User not authenticated');
        }

        await _remarkRepository.addRemark(
          taskId: widget.taskId,
          userId: userId,
          message: _messageController.text.trim(),
        );

        if (mounted) {
          Navigator.of(context).pop(true); // Return true on success
          NotificationService.showInAppNotification(
            context,
            title: 'Remark Added',
            message: 'Your remark has been added successfully',
            icon: Icons.check_circle,
            backgroundColor: Colors.green.shade700,
          );
        }
      } catch (e) {
        debugPrint('Error adding remark: $e');
        if (mounted) {
          setState(() => _isSubmitting = false);
          // Show error in dialog instead of snackbar
          showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Error'),
                  content: Text(
                    'Failed to add remark: ${e.toString().replaceAll('Exception: ', '')}',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: screenHeight * 0.7,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Add Remark',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppTextField(
                        controller: _messageController,
                        label: 'Message',
                        hint: 'Enter your remark...',
                        maxLines: 5,
                        maxLength: 300,
                        validator:
                            (value) => RemarkModel.validateMessage(value),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Character count
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _messageController,
                        builder: (context, value, child) {
                          final count = value.text.length;
                          final isNearLimit = count > 250;

                          return Text(
                            '$count / 300',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  isNearLimit
                                      ? Colors.orange
                                      : isDark
                                      ? AppColors.neutral500
                                      : AppColors.neutral400,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton(
                      text: 'Submit',
                      onPressed: _handleSubmit,
                      isLoading: _isSubmitting,
                      isFullWidth: false,
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
