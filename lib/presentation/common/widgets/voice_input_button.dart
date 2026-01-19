import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/speech_service.dart';

/// A voice input button widget that enables speech-to-text functionality.
/// 
/// Features:
/// - Three visual states: idle, listening, processing
/// - Pulsing animation while listening
/// - Haptic feedback on interaction
/// - Permission handling with user-friendly dialogs
/// - Confirmation dialog before inserting text
/// 
/// Usage:
/// ```dart
/// VoiceInputButton(
///   fieldName: 'Title',
///   controller: _titleController,
///   maxLength: 100,
///   onTextConfirmed: (text) {
///     _titleController.text = text;
///   },
/// )
/// ```
class VoiceInputButton extends StatefulWidget {
  /// The name of the field (for accessibility and dialogs)
  final String fieldName;
  
  /// Text controller for the target field (to check existing text)
  final TextEditingController? controller;
  
  /// Maximum length for the transcribed text
  final int? maxLength;
  
  /// Callback when user confirms the transcribed text
  final Function(String text, TextInsertMode mode)? onTextConfirmed;
  
  /// Callback for partial results (live preview)
  final Function(String)? onPartialResult;
  
  /// Whether the button is enabled
  final bool enabled;
  
  /// Size of the button icon
  final double iconSize;

  const VoiceInputButton({
    super.key,
    required this.fieldName,
    this.controller,
    this.maxLength,
    this.onTextConfirmed,
    this.onPartialResult,
    this.enabled = true,
    this.iconSize = 22,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  final SpeechService _speechService = SpeechService();
  
  VoiceInputStatus _status = VoiceInputStatus.idle;
  
  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup pulsing animation for listening state
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        if (_status == VoiceInputStatus.listening) {
          _pulseController.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _updateStatus(VoiceInputStatus status) {
    if (mounted) {
      setState(() => _status = status);
      
      if (status == VoiceInputStatus.listening) {
        _pulseController.forward();
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  Future<void> _handleTap() async {
    if (!widget.enabled) return;

    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // If already listening, stop
    if (_speechService.isListening) {
      await _speechService.stopListening();
      _updateStatus(VoiceInputStatus.idle);
      return;
    }

    // Start listening
    final success = await _speechService.startListening(
      onResult: _handleResult,
      onPartialResult: _handlePartialResult,
      onError: _handleError,
      onStatusChanged: _updateStatus,
    );

    if (!success && mounted) {
      // Show error based on status
      if (_status == VoiceInputStatus.permissionDenied) {
        _showPermissionDeniedDialog();
      } else if (_status == VoiceInputStatus.unavailable) {
        _showUnavailableDialog();
      }
    }
  }

  void _handleResult(String text) {
    if (text.isEmpty) {
      _showSnackBar('Didn\'t catch that. Please try again.');
      return;
    }

    // Apply max length restriction
    String truncatedText = text;
    if (widget.maxLength != null && text.length > widget.maxLength!) {
      truncatedText = text.substring(0, widget.maxLength!);
    }

    // Haptic feedback for success
    HapticFeedback.mediumImpact();
    
    // Check if field has existing text
    final hasExistingText = widget.controller?.text.isNotEmpty ?? false;
    
    if (hasExistingText) {
      // Show dialog with replace/append options
      _showInsertOptionsDialog(truncatedText);
    } else {
      // Show confirmation dialog
      _showConfirmationDialog(truncatedText);
    }
  }

  void _handlePartialResult(String text) {
    if (mounted) {
      widget.onPartialResult?.call(text);
    }
  }

  void _handleError(String error) {
    HapticFeedback.heavyImpact();
    _showSnackBar(error);
  }

  void _showConfirmationDialog(String text) {
    final textController = TextEditingController(text: text);
    
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.mic,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Voice Input - ${widget.fieldName}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transcribed text:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                maxLines: 4,
                maxLength: widget.maxLength,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  hintText: 'Edit text before inserting...',
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                textController.dispose();
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final finalText = textController.text.trim();
                textController.dispose();
                Navigator.of(context).pop(true);
                
                if (finalText.isNotEmpty) {
                  widget.onTextConfirmed?.call(finalText, TextInsertMode.replace);
                }
              },
              child: const Text('Use This Text'),
            ),
          ],
        );
      },
    );
  }

  void _showInsertOptionsDialog(String text) {
    final textController = TextEditingController(text: text);
    
    showDialog<TextInsertMode?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.mic,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Voice Input - ${widget.fieldName}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Field already has text. Choose how to insert:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Transcribed text:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.neutral400 : AppColors.neutral600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textController,
                maxLines: 3,
                maxLength: widget.maxLength,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  hintText: 'Edit text before inserting...',
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () {
                textController.dispose();
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () {
                    final finalText = textController.text.trim();
                    textController.dispose();
                    Navigator.of(context).pop(TextInsertMode.append);
                    
                    if (finalText.isNotEmpty) {
                      widget.onTextConfirmed?.call(finalText, TextInsertMode.append);
                    }
                  },
                  child: const Text('Append'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final finalText = textController.text.trim();
                    textController.dispose();
                    Navigator.of(context).pop(TextInsertMode.replace);
                    
                    if (finalText.isNotEmpty) {
                      widget.onTextConfirmed?.call(finalText, TextInsertMode.replace);
                    }
                  },
                  child: const Text('Replace'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.mic_off,
          color: theme.colorScheme.error,
          size: 48,
        ),
        title: const Text('Microphone Access Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Voice input requires microphone permission to convert your speech to text.',
            ),
            const SizedBox(height: 16),
            Text(
              'To enable:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Tap "Open Settings" below\n'
              '2. Find "Todo Planner" app\n'
              '3. Enable "Microphone" permission\n'
              '4. Return to the app',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showUnavailableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: 48,
        ),
        title: const Text('Voice Input Unavailable'),
        content: const Text(
          'Speech recognition is not available on this device. Please ensure you have Google Voice services installed.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color iconColor;
    Widget iconWidget;
    
    switch (_status) {
      case VoiceInputStatus.listening:
        iconColor = Colors.red;
        iconWidget = AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Icon(
                Icons.mic,
                color: iconColor,
                size: widget.iconSize,
                semanticLabel: 'Listening... Tap to stop',
              ),
            );
          },
        );
        break;
      case VoiceInputStatus.processing:
        iconColor = theme.colorScheme.primary;
        iconWidget = SizedBox(
          width: widget.iconSize,
          height: widget.iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
          ),
        );
        break;
      case VoiceInputStatus.error:
        iconColor = theme.colorScheme.error;
        iconWidget = Icon(
          Icons.mic_off,
          color: iconColor,
          size: widget.iconSize,
          semanticLabel: 'Voice input error',
        );
        break;
      case VoiceInputStatus.permissionDenied:
        iconColor = theme.colorScheme.error;
        iconWidget = Icon(
          Icons.mic_off,
          color: iconColor,
          size: widget.iconSize,
          semanticLabel: 'Microphone permission denied',
        );
        break;
      case VoiceInputStatus.unavailable:
        iconColor = isDark ? AppColors.neutral600 : AppColors.neutral400;
        iconWidget = Icon(
          Icons.mic_off,
          color: iconColor,
          size: widget.iconSize,
          semanticLabel: 'Voice input unavailable',
        );
        break;
      case VoiceInputStatus.idle:
        iconColor = widget.enabled
            ? (isDark ? AppColors.neutral400 : AppColors.neutral600)
            : (isDark ? AppColors.neutral700 : AppColors.neutral300);
        iconWidget = Icon(
          Icons.mic,
          color: iconColor,
          size: widget.iconSize,
          semanticLabel: 'Voice input for ${widget.fieldName}',
        );
    }

    return Semantics(
      button: true,
      label: 'Voice input for ${widget.fieldName}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? _handleTap : null,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: iconWidget,
          ),
        ),
      ),
    );
  }
}

/// How to insert text when field has existing content
enum TextInsertMode {
  /// Replace all existing text
  replace,
  /// Append to existing text
  append,
}
