import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Voice input status states
enum VoiceInputStatus {
  /// Ready to start listening
  idle,
  /// Actively listening for speech
  listening,
  /// Processing final result
  processing,
  /// Speech recognition not available on device
  unavailable,
  /// Permission denied
  permissionDenied,
  /// Error occurred
  error,
}

/// Enum for language preference
enum VoiceLanguage {
  /// Hindi (for Hinglish and Hindi input)
  hindi('hi-IN', 'हिन्दी'),
  /// English (India)
  englishIndia('en-IN', 'English (India)'),
  /// English (US)
  englishUS('en-US', 'English (US)');

  const VoiceLanguage(this.localeId, this.displayName);
  
  final String localeId;
  final String displayName;
}

/// Service for handling speech-to-text functionality
/// 
/// This service provides:
/// - Device-native speech recognition using speech_to_text package
/// - Microphone permission handling
/// - Locale/language management with Hinglish support
/// - Error handling for all edge cases
/// - State management for UI updates
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final SpeechToText _speechToText = SpeechToText();
  
  // State
  bool _isInitialized = false;
  bool _isAvailable = false;
  VoiceInputStatus _status = VoiceInputStatus.idle;
  VoiceLanguage _selectedLanguage = VoiceLanguage.hindi;
  List<LocaleName> _availableLocales = [];
  String _lastError = '';
  
  // Callbacks
  Function(String)? _onResult;
  Function(String)? _onError;
  Function(VoiceInputStatus)? _onStatusChanged;
  
  // Timeouts
  static const Duration _listenTimeout = Duration(seconds: 30);
  static const Duration _pauseTimeout = Duration(seconds: 3);

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAvailable => _isAvailable;
  bool get isListening => _speechToText.isListening;
  VoiceInputStatus get status => _status;
  VoiceLanguage get selectedLanguage => _selectedLanguage;
  List<LocaleName> get availableLocales => _availableLocales;
  String get lastError => _lastError;

  /// Initialize the speech recognition service
  /// 
  /// Returns true if initialization was successful.
  /// Should be called before attempting to use speech recognition.
  Future<bool> initialize() async {
    if (_isInitialized && _isAvailable) {
      return true;
    }

    try {
      _isAvailable = await _speechToText.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
        debugLogging: kDebugMode,
      );

      if (_isAvailable) {
        _isInitialized = true;
        _availableLocales = await _speechToText.locales();
        _updateStatus(VoiceInputStatus.idle);
        
        // Debug: Print available locales
        if (kDebugMode) {
          debugPrint('SpeechService: Available locales:');
          for (final locale in _availableLocales) {
            debugPrint('  - ${locale.localeId}: ${locale.name}');
          }
        }
      } else {
        _updateStatus(VoiceInputStatus.unavailable);
        _lastError = 'Speech recognition not available on this device';
      }

      return _isAvailable;
    } catch (e) {
      _lastError = 'Failed to initialize speech recognition: $e';
      _updateStatus(VoiceInputStatus.error);
      if (kDebugMode) {
        debugPrint('SpeechService Error: $_lastError');
      }
      return false;
    }
  }

  /// Check and request microphone permission
  /// 
  /// Returns true if permission is granted.
  Future<PermissionCheckResult> checkAndRequestPermission() async {
    try {
      // Check microphone permission
      final micStatus = await Permission.microphone.status;
      
      if (micStatus.isGranted) {
        return PermissionCheckResult.granted;
      }
      
      if (micStatus.isPermanentlyDenied) {
        return PermissionCheckResult.permanentlyDenied;
      }
      
      // Request permission
      final result = await Permission.microphone.request();
      
      if (result.isGranted) {
        return PermissionCheckResult.granted;
      } else if (result.isPermanentlyDenied) {
        return PermissionCheckResult.permanentlyDenied;
      } else {
        return PermissionCheckResult.denied;
      }
    } catch (e) {
      _lastError = 'Permission check failed: $e';
      if (kDebugMode) {
        debugPrint('SpeechService Permission Error: $_lastError');
      }
      return PermissionCheckResult.error;
    }
  }

  /// Start listening for speech
  /// 
  /// [onResult] - Callback with transcribed text (final result)
  /// [onPartialResult] - Optional callback for live transcription
  /// [onError] - Callback when an error occurs
  /// [onStatusChanged] - Callback when status changes
  /// [language] - Optional language to use (defaults to selected language)
  Future<bool> startListening({
    required Function(String) onResult,
    Function(String)? onPartialResult,
    Function(String)? onError,
    Function(VoiceInputStatus)? onStatusChanged,
    VoiceLanguage? language,
  }) async {
    // Check if already listening
    if (_speechToText.isListening) {
      await stopListening();
    }

    // Store callbacks
    _onResult = onResult;
    _onError = onError;
    _onStatusChanged = onStatusChanged;

    // Check permission first
    final permissionResult = await checkAndRequestPermission();
    if (permissionResult != PermissionCheckResult.granted) {
      _updateStatus(VoiceInputStatus.permissionDenied);
      _lastError = permissionResult == PermissionCheckResult.permanentlyDenied
          ? 'Microphone permission permanently denied. Please enable in Settings.'
          : 'Microphone permission denied.';
      onError?.call(_lastError);
      return false;
    }

    // Initialize if needed
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call(_lastError);
        return false;
      }
    }

    // Check availability
    if (!_isAvailable) {
      _updateStatus(VoiceInputStatus.unavailable);
      _lastError = 'Speech recognition not available on this device';
      onError?.call(_lastError);
      return false;
    }

    try {
      final localeId = (language ?? _selectedLanguage).localeId;
      
      // Find matching locale or fallback
      final targetLocaleId = _findBestLocale(localeId);
      
      if (kDebugMode) {
        debugPrint('SpeechService: Starting with locale: $targetLocaleId');
      }

      _updateStatus(VoiceInputStatus.listening);
      
      await _speechToText.listen(
        onResult: (result) => _handleResult(result, onPartialResult),
        listenFor: _listenTimeout,
        pauseFor: _pauseTimeout,
        localeId: targetLocaleId,
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
      );

      return true;
    } catch (e) {
      _lastError = 'Failed to start listening: $e';
      _updateStatus(VoiceInputStatus.error);
      onError?.call(_lastError);
      if (kDebugMode) {
        debugPrint('SpeechService Listen Error: $_lastError');
      }
      return false;
    }
  }

  /// Stop listening for speech
  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      _updateStatus(VoiceInputStatus.idle);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SpeechService Stop Error: $e');
      }
    }
  }

  /// Cancel listening without processing result
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
      _updateStatus(VoiceInputStatus.idle);
      _onResult = null;
      _onError = null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SpeechService Cancel Error: $e');
      }
    }
  }

  /// Set the preferred language for speech recognition
  void setLanguage(VoiceLanguage language) {
    _selectedLanguage = language;
  }

  /// Check if a specific locale is available
  bool isLocaleAvailable(String localeId) {
    return _availableLocales.any(
      (locale) => locale.localeId.toLowerCase() == localeId.toLowerCase(),
    );
  }

  /// Get available voice languages filtered to supported ones
  List<VoiceLanguage> getSupportedLanguages() {
    return VoiceLanguage.values.where((lang) {
      return _availableLocales.any((locale) => 
        locale.localeId.toLowerCase().startsWith(lang.localeId.split('-')[0].toLowerCase())
      );
    }).toList();
  }

  // Private methods

  String _findBestLocale(String preferredLocaleId) {
    // Check exact match
    for (final locale in _availableLocales) {
      if (locale.localeId.toLowerCase() == preferredLocaleId.toLowerCase()) {
        return locale.localeId;
      }
    }
    
    // Check language prefix match (e.g., "hi" for "hi-IN")
    final langPrefix = preferredLocaleId.split('-')[0].toLowerCase();
    for (final locale in _availableLocales) {
      if (locale.localeId.toLowerCase().startsWith(langPrefix)) {
        return locale.localeId;
      }
    }
    
    // Fallback to system default
    return _availableLocales.isNotEmpty 
        ? _availableLocales.first.localeId 
        : preferredLocaleId;
  }

  void _handleResult(SpeechRecognitionResult result, Function(String)? onPartialResult) {
    final text = result.recognizedWords.trim();
    
    if (text.isEmpty) {
      return;
    }

    if (result.finalResult) {
      _updateStatus(VoiceInputStatus.processing);
      
      // Small delay to show processing state
      Future.delayed(const Duration(milliseconds: 200), () {
        _updateStatus(VoiceInputStatus.idle);
        _onResult?.call(text);
      });
    } else {
      // Partial result for live preview
      onPartialResult?.call(text);
    }
  }

  void _handleStatus(String status) {
    if (kDebugMode) {
      debugPrint('SpeechService Status: $status');
    }

    switch (status) {
      case 'listening':
        _updateStatus(VoiceInputStatus.listening);
        break;
      case 'notListening':
        if (_status == VoiceInputStatus.listening) {
          _updateStatus(VoiceInputStatus.processing);
        }
        break;
      case 'done':
        _updateStatus(VoiceInputStatus.idle);
        break;
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (kDebugMode) {
      debugPrint('SpeechService Error: ${error.errorMsg}');
    }

    String userFriendlyError;
    
    switch (error.errorMsg) {
      case 'error_speech_timeout':
        userFriendlyError = 'Didn\'t catch that. Please try again.';
        break;
      case 'error_no_match':
        userFriendlyError = 'Didn\'t recognize that. Please speak clearly.';
        break;
      case 'error_audio':
        userFriendlyError = 'Audio error. Please check your microphone.';
        break;
      case 'error_network':
        userFriendlyError = 'Network error. Please check your connection.';
        break;
      case 'error_permission':
        userFriendlyError = 'Microphone permission denied.';
        _updateStatus(VoiceInputStatus.permissionDenied);
        break;
      case 'error_busy':
        userFriendlyError = 'Speech recognition is busy. Please try again.';
        break;
      case 'error_server':
        userFriendlyError = 'Server error. Please try again later.';
        break;
      default:
        userFriendlyError = 'Voice input failed. Please try again.';
    }

    _lastError = userFriendlyError;
    _updateStatus(VoiceInputStatus.error);
    _onError?.call(userFriendlyError);
    
    // Reset to idle after showing error
    Future.delayed(const Duration(seconds: 1), () {
      if (_status == VoiceInputStatus.error) {
        _updateStatus(VoiceInputStatus.idle);
      }
    });
  }

  void _updateStatus(VoiceInputStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _onStatusChanged?.call(newStatus);
    }
  }

  /// Dispose resources when no longer needed
  void dispose() {
    _speechToText.cancel();
    _onResult = null;
    _onError = null;
    _onStatusChanged = null;
  }
}

/// Result of permission check
enum PermissionCheckResult {
  granted,
  denied,
  permanentlyDenied,
  error,
}
