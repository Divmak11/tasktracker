import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Update dialog widget for app updates
/// 
/// Features:
/// - Two variants: Forced (non-dismissible) and Optional (dismissible)
/// - Platform-agnostic update prompts
/// - Haptic feedback
/// - Material Design 3 styling
class UpdateDialog extends StatelessWidget {
  final String title;
  final String message;
  final bool isForced;
  final VoidCallback onUpdate;
  final VoidCallback? onDismiss;

  const UpdateDialog({
    super.key,
    required this.title,
    required this.message,
    required this.isForced,
    required this.onUpdate,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !isForced, // Prevent back button dismissal if forced
      child: AlertDialog(
        icon: Icon(
          Icons.system_update,
          color: theme.colorScheme.primary,
          size: 48,
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (isForced) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.amber.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This update is required to continue using the app.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          if (!isForced && onDismiss != null)
            OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onDismiss!();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              onUpdate();
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  /// Show forced update dialog (non-dismissible)
  static Future<void> showForcedUpdate({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onUpdate,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        title: title,
        message: message,
        isForced: true,
        onUpdate: onUpdate,
      ),
    );
  }

  /// Show optional update dialog (dismissible)
  static Future<void> showOptionalUpdate({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onUpdate,
    required VoidCallback onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => UpdateDialog(
        title: title,
        message: message,
        isForced: false,
        onUpdate: onUpdate,
        onDismiss: onDismiss,
      ),
    );
  }
}
