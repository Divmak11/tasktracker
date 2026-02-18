import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/env_config.dart';
import 'cloud_functions_service.dart';

/// Result of calendar token refresh operation
enum CalendarRefreshResult {
  /// Token refresh succeeded
  success,

  /// Token refresh failed after retries (network/server error)
  failed,

  /// User needs to reconnect calendar (silent sign-in failed)
  reconnectNeeded,
}

/// Result of calendar connection operation with specific failure reasons
enum CalendarConnectResult {
  /// Connection successful - calendar is now connected and verified
  success,

  /// User cancelled the sign-in dialog (pressed back or cancelled)
  userCancelled,

  /// Google sign-in failed (could be network, configuration, etc.)
  signInFailed,

  /// No server auth code received (configuration issue with webClientId)
  noServerAuthCode,

  /// Backend token exchange failed
  backendExchangeFailed,

  /// Backend verification failed - tokens don't actually work
  verificationFailed,

  /// Network error during connection
  networkError,

  /// Access was revoked - user needs to logout and login again
  accessRevoked,

  /// Unknown error occurred
  unknownError,
}

/// Result of calendar disconnection operation
enum CalendarDisconnectResult {
  /// Disconnection successful - calendar is now disconnected
  success,

  /// Already disconnected - no action needed
  alreadyDisconnected,

  /// Local sign-out failed
  localSignOutFailed,

  /// Backend disconnect failed but local state was cleared
  backendFailed,

  /// Network error during disconnection
  networkError,
}

/// Google Calendar integration service
///
/// Uses Server Auth Code flow for proper token management:
/// 1. Mobile app gets serverAuthCode via GoogleSignIn
/// 2. Backend exchanges it for REAL refresh_token
/// 3. Backend can refresh tokens anytime (even when app is closed)
class CalendarService {
  // Singleton pattern
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();

  // Web Client ID from environment config (client_type: 3 from google-services.json)
  // This enables getting serverAuthCode for backend token exchange
  String get _webClientId => EnvConfig.googleWebClientId;

  // Google Sign-In with Calendar scope and serverClientId for auth code flow
  // Note: Late initialization to allow EnvConfig to load first
  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn {
    _googleSignInInstance ??= GoogleSignIn(
      scopes: ['email', calendar.CalendarApi.calendarEventsScope],
      // serverClientId enables getting serverAuthCode for backend token exchange
      serverClientId: _webClientId,
    );
    return _googleSignInInstance!;
  }

  GoogleSignInAccount? _currentAccount;
  calendar.CalendarApi? _calendarApi;

  /// Check if calendar is connected
  bool get isConnected => _calendarApi != null;

  /// Resets all local calendar state. Call this on logout to prevent
  /// stale sessions from being used by a different user.
  /// 
  /// NOTE: This does NOT call signOut() because AuthRepository.signOut() 
  /// already clears the Google session. We only need to clear local state here.
  /// The double signOut was causing consent screen to appear on every login.
  Future<void> reset() async {
    debugPrint('[CALENDAR] [RESET] Clearing local state...');
    _currentAccount = null;
    _calendarApi = null;
    
    // NOTE: signOut() removed - AuthRepository.signOut() already clears the
    // Google session when user logs out. Calling it twice was causing the
    // consent screen to appear on every subsequent login.
    
    // Nullify the GoogleSignIn instance so a fresh one is created next time
    _googleSignInInstance = null;
    debugPrint('[CALENDAR] [RESET] Complete');
  }

  /// Clears stale session aggressively. Call this when we detect
  /// that the user's access has been revoked externally.
  /// 
  /// This uses disconnect() which revokes tokens at OS level,
  /// ensuring a completely fresh session on next attempt.
  Future<void> clearStaleSession() async {
    debugPrint('[CALENDAR] [CLEAR_STALE] Clearing stale session aggressively...');
    _currentAccount = null;
    _calendarApi = null;
    
    try {
      // disconnect() is more aggressive than signOut() - it revokes OS-level tokens
      await _googleSignIn.disconnect();
      debugPrint('[CALENDAR] [CLEAR_STALE] Disconnected from Google');
    } catch (e) {
      debugPrint('[CALENDAR] [CLEAR_STALE] disconnect error (ignoring): $e');
    }
    
    // Nullify instance to force fresh creation
    _googleSignInInstance = null;
    debugPrint('[CALENDAR] [CLEAR_STALE] Complete');
  }

  /// Verifies if the current calendar connection is still valid.
  /// Call this on app startup/login if user has googleCalendarConnected = true.
  /// 
  /// Returns true if connection is valid, false if it needs reconnection.
  /// If invalid, backend automatically sets googleCalendarConnected = false.
  Future<bool> verifyConnectionStatus() async {
    debugPrint('[CALENDAR] [VERIFY] Verifying connection status...');
    try {
      final result = await _cloudFunctions.reconnectCalendar();
      if (result['success'] == true) {
        debugPrint('[CALENDAR] [VERIFY] Connection is valid');
        return true;
      } else {
        debugPrint('[CALENDAR] [VERIFY] Connection invalid, requiresReauth=${result['requiresReauth']}');
        // Backend already set googleCalendarConnected = false
        return false;
      }
    } catch (e) {
      debugPrint('[CALENDAR] [VERIFY] Error: $e');
      return false;
    }
  }

  /// Refresh and persist latest Google access token if user already connected.
  ///
  /// This is a fallback for when the app is active. The backend handles
  /// automatic token refresh using the refresh_token obtained via serverAuthCode.
  ///
  /// Returns a [CalendarRefreshResult] indicating success, failure, or if
  /// reconnection is needed (when silent sign-in fails).
  Future<CalendarRefreshResult> refreshAccessToken(
    String userId, {
    int maxRetries = 2,
  }) async {
    debugPrint('[CALENDAR] [REFRESH_TOKEN] Starting for user=$userId');

    int attempt = 0;
    Exception? lastError;

    while (attempt <= maxRetries) {
      attempt++;
      debugPrint(
        '[CALENDAR] [REFRESH_TOKEN] Attempt $attempt/${maxRetries + 1}',
      );

      try {
        // Attempt silent sign-in to reuse existing consent
        _currentAccount = await _googleSignIn.signInSilently();

        if (_currentAccount == null) {
          debugPrint(
            '[CALENDAR] [REFRESH_TOKEN] Silent sign-in returned null',
          );
          // Silent sign-in failed - user needs to reconnect calendar
          return CalendarRefreshResult.reconnectNeeded;
        }

        debugPrint(
          '[CALENDAR] [REFRESH_TOKEN] Silent sign-in SUCCESS '
          'email=${_currentAccount!.email}',
        );

        final auth = await _currentAccount!.authentication;
        if (auth.accessToken == null) {
          debugPrint('[CALENDAR] [REFRESH_TOKEN] No access token available');
          return CalendarRefreshResult.reconnectNeeded;
        }

        debugPrint(
          '[CALENDAR] [REFRESH_TOKEN] Got new access token '
          '(preview=${auth.accessToken!.substring(0, 20)}...)',
        );

        // Update only the access token - backend manages refresh token
        await _firestore.collection('users').doc(userId).update({
          'googleCalendarConnected': true,
          'googleAccessToken': auth.accessToken,
        });

        debugPrint(
          '[CALENDAR] [REFRESH_TOKEN] SUCCESS - Saved to Firestore for '
          'user=$userId',
        );
        return CalendarRefreshResult.success;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('[CALENDAR] [REFRESH_TOKEN] Attempt $attempt FAILED: $e');

        // Wait before retry (exponential backoff)
        if (attempt <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    debugPrint(
      '[CALENDAR] [REFRESH_TOKEN] All $attempt attempts failed. '
      'Last error: $lastError',
    );
    return CalendarRefreshResult.failed;
  }

  /// Connect to Google Calendar using Server Auth Code flow
  ///
  /// This flow ensures the backend gets a REAL refresh_token that can be used
  /// to refresh access tokens automatically, even when the app is closed.
  ///
  /// IMPORTANT: This method now waits for backend verification before returning
  /// success. It does NOT fall back to local tokens as that was causing false
  /// positive "connected" status.
  ///
  /// Returns a [CalendarConnectResult] with specific failure reason if failed.
  Future<CalendarConnectResult> connect(String userId) async {
    debugPrint('[CALENDAR] [CONNECT] Starting for user=$userId');
    debugPrint('[CALENDAR] [CONNECT] Using webClientId=$_webClientId');

    try {
      // SMART RECONNECT: Try to use existing backend tokens first
      // This avoids showing the Google Sign-In dialog for returning users
      debugPrint('[CALENDAR] [CONNECT] Attempting Smart Reconnect...');
      bool requiresReauth = false;
      try {
        final reconnectResult = await _cloudFunctions.reconnectCalendar();
        if (reconnectResult['success'] == true) {
          debugPrint('[CALENDAR] [CONNECT] Smart Reconnect SUCCESS!');
          
          // Try to restore local session to match backend state
          // This is optional - backend connection is what matters for sync
          try {
            _currentAccount = await _googleSignIn.signInSilently();
            if (_currentAccount != null) {
              debugPrint('[CALENDAR] [CONNECT] Local session restored');
              final authenticatedClient = _GoogleAuthClient(await _currentAccount!.authHeaders);
              _calendarApi = calendar.CalendarApi(authenticatedClient);
            } else {
              // iOS: signInSilently often returns null even with valid consent
              // Backend has valid tokens so calendar sync will work via Cloud Functions
              debugPrint('[CALENDAR] [CONNECT] Local session null (iOS), but backend connected - calendar sync will work');
            }
          } catch (e) {
            debugPrint('[CALENDAR] [CONNECT] Local restore failed, but backend is connected: $e');
          }
          // Return success regardless of local session - backend is the source of truth
          return CalendarConnectResult.success;
        } else {
          requiresReauth = reconnectResult['requiresReauth'] == true;
          debugPrint('[CALENDAR] [CONNECT] Smart Reconnect failed. requiresReauth=$requiresReauth');
        }
      } catch (e) {
         debugPrint('[CALENDAR] [CONNECT] Smart Reconnect error (ignoring): $e');
         // Fall through to full sign-in
      }

      // FULL SIGN-IN FLOW:
      // If we reach here, either we have no tokens or they are invalid
      
      // iOS-SPECIFIC FIX: On iOS, the cached Google session interferes with getting
      // a fresh serverAuthCode. When reauth is required (e.g., user revoked access),
      // we must disconnect() first to clear the stale session. This forces a fresh
      // OAuth flow that shows consent screen and returns serverAuthCode.
      // Android doesn't have this issue - it handles incremental scopes properly.
      if (Platform.isIOS && requiresReauth) {
        debugPrint('[CALENDAR] [CONNECT] iOS: requiresReauth=true, clearing stale session...');
        try {
          await _googleSignIn.disconnect();
          debugPrint('[CALENDAR] [CONNECT] iOS: Session cleared, will show fresh consent');
        } catch (e) {
          debugPrint('[CALENDAR] [CONNECT] iOS: disconnect() error (ignoring): $e');
        }
      }
      
      // Try silent sign-in first to avoid showing account picker
      debugPrint('[CALENDAR] [CONNECT] Trying signInSilently first...');

      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.signInSilently();
        // CRITICAL: On iOS, signInSilently() NEVER returns serverAuthCode
        // even if the user has previously granted access. We must check for it
        // and force a full signIn() if missing. Android is unaffected since
        // its signInSilently() already returns serverAuthCode.
        if (account != null && account.serverAuthCode != null) {
          debugPrint('[CALENDAR] [CONNECT] signInSilently SUCCESS with serverAuthCode');
        } else {
          if (account != null) {
            debugPrint('[CALENDAR] [CONNECT] signInSilently succeeded but no serverAuthCode (iOS), forcing signIn()...');
          } else {
            debugPrint('[CALENDAR] [CONNECT] signInSilently returned null, showing dialog...');
          }
          account = await _googleSignIn.signIn();
          
          // iOS-SPECIFIC FALLBACK: If signIn() still doesn't return serverAuthCode,
          // disconnect to clear the cached session and try once more.
          // This handles edge cases where the OS session interferes.
          if (Platform.isIOS && account != null && account.serverAuthCode == null) {
            debugPrint('[CALENDAR] [CONNECT] iOS: signIn() returned no serverAuthCode, disconnecting and retrying...');
            try {
              await _googleSignIn.disconnect();
              account = await _googleSignIn.signIn();
              debugPrint('[CALENDAR] [CONNECT] iOS: Retry signIn() hasServerAuthCode=${account?.serverAuthCode != null}');
            } catch (retryError) {
              debugPrint('[CALENDAR] [CONNECT] iOS: Retry failed: $retryError');
            }
          }
        }
      } catch (signInError) {
          debugPrint(
            '[CALENDAR] [CONNECT] GoogleSignIn threw error: $signInError',
          );
        // Check if it's a network error
        if (signInError.toString().contains('network') ||
            signInError.toString().contains('SocketException') ||
            signInError.toString().contains('Failed host lookup')) {
          return CalendarConnectResult.networkError;
        }
        return CalendarConnectResult.signInFailed;

      }

      if (account == null) {
        debugPrint('[CALENDAR] [CONNECT] User cancelled sign-in');
        return CalendarConnectResult.userCancelled;
      }

      _currentAccount = account;
      debugPrint('[CALENDAR] [CONNECT] GoogleSignIn SUCCESS');
      debugPrint('[CALENDAR] [CONNECT] email=${_currentAccount!.email}');
      debugPrint(
        '[CALENDAR] [CONNECT] '
        'hasServerAuthCode=${_currentAccount!.serverAuthCode != null}',
      );


      // Get auth headers for local calendar operations
      final auth = await _currentAccount!.authentication;
      debugPrint(
        '[CALENDAR] [CONNECT] '
        'hasAccessToken=${auth.accessToken != null}, '
        'hasIdToken=${auth.idToken != null}',
      );

      // Create authenticated HTTP client for local use
      final authenticatedClient = _GoogleAuthClient(
        await _currentAccount!.authHeaders,
      );

      // Initialize Calendar API for local operations
      _calendarApi = calendar.CalendarApi(authenticatedClient);

      // SERVER AUTH CODE FLOW:
      // If we have a serverAuthCode, send it to backend for proper token exchange
      // This is the ONLY path that properly sets googleCalendarConnected = true
      final serverAuthCode = _currentAccount!.serverAuthCode;

      if (serverAuthCode == null || serverAuthCode.isEmpty) {
        // No serverAuthCode received - this is a configuration issue
        debugPrint(
          '[CALENDAR] [CONNECT] No serverAuthCode received! '
          'Check if webClientId is correct.',
        );
        // Clean up partial state
        _calendarApi = null;
        return CalendarConnectResult.noServerAuthCode;
      }

      debugPrint(
        '[CALENDAR] [CONNECT] Got serverAuthCode '
        '(length=${serverAuthCode.length})',
      );
      debugPrint(
        '[CALENDAR] [CONNECT] Calling backend exchangeCalendarAuthCode...',
      );

      // CRITICAL: Wait for backend to exchange AND verify the tokens
      // The backend now verifies the token works before setting connected=true
      try {
        final result = await _cloudFunctions.exchangeCalendarAuthCode(
          serverAuthCode,
        );

        // Check the backend response
        final success = result['success'] == true;
        final hasRefreshToken = result['hasRefreshToken'] == true;

        if (!success) {
          final errorMessage = result['message'] as String? ?? 'Unknown error';
          debugPrint(
            '[CALENDAR] [CONNECT] Backend returned failure: $errorMessage',
          );

          // Clean up partial state
          _calendarApi = null;

          // Check if it's a verification failure
          if (errorMessage.contains('verification failed')) {
            return CalendarConnectResult.verificationFailed;
          }
          return CalendarConnectResult.backendExchangeFailed;
        }

        debugPrint(
          '[CALENDAR] [CONNECT] Backend token exchange AND verification SUCCESS '
          'hasRefreshToken=$hasRefreshToken',
        );
      } catch (e) {
        debugPrint('[CALENDAR] [CONNECT] Backend exchange FAILED: $e');

        // Clean up partial state - don't leave calendar API initialized
        // when connection actually failed
        _calendarApi = null;
        _currentAccount = null;

        // Parse error message for specific failure reason
        final errorStr = e.toString().toLowerCase();
        
        // CRITICAL: If auth code is expired/already used, user needs to logout and login again
        // This happens when user revoked access in Google Settings
        if (errorStr.contains('expired') || errorStr.contains('already used')) {
          debugPrint('[CALENDAR] [CONNECT] Auth code expired - clearing stale session');
          // Clear the stale session so next login attempt gets fresh credentials
          await clearStaleSession();
          return CalendarConnectResult.accessRevoked;
        }
        
        if (errorStr.contains('network') ||
            errorStr.contains('socket') ||
            errorStr.contains('timeout')) {
          return CalendarConnectResult.networkError;
        }
        if (errorStr.contains('verification')) {
          return CalendarConnectResult.verificationFailed;
        }
        return CalendarConnectResult.backendExchangeFailed;
      }

      debugPrint('[CALENDAR] [CONNECT] COMPLETE for user=$userId');
      return CalendarConnectResult.success;
    } catch (e, stackTrace) {
      debugPrint('[CALENDAR] [CONNECT] FAILED: $e');
      debugPrint('[CALENDAR] [CONNECT] StackTrace: $stackTrace');

      // Clean up any partial state
      _calendarApi = null;
      _currentAccount = null;

      return CalendarConnectResult.unknownError;
    }
  }

  /// Disconnect from Google Calendar via Cloud Function
  ///
  /// IMPORTANT: This method calls backend FIRST to ensure cleanup happens while
  /// tokens are still valid. Local sign-out happens only after backend confirms.
  ///
  /// Returns a [CalendarDisconnectResult] with specific status.
  Future<CalendarDisconnectResult> disconnect(String userId) async {
    debugPrint('[CALENDAR] [DISCONNECT] Starting for user=$userId');

    try {
      // Call Cloud Function FIRST to delete calendar events and set flag to false
      // This must happen before local sign-out so tokens are still valid for cleanup
      debugPrint(
        '[CALENDAR] [DISCONNECT] Calling backend to disconnect...',
      );

      try {
        final result = await _cloudFunctions.disconnectCalendar();
        final success = result['success'] == true;
        final message = result['message'] as String? ?? '';

        if (!success) {
          debugPrint('[CALENDAR] [DISCONNECT] Backend returned failure');
          return CalendarDisconnectResult.backendFailed;
        }

        // Check if it was already disconnected
        if (message.contains('already disconnected')) {
          debugPrint('[CALENDAR] [DISCONNECT] Was already disconnected');
          // Clean up local calendar state only (don't sign out of Google)
          _currentAccount = null;
          _calendarApi = null;
          return CalendarDisconnectResult.alreadyDisconnected;
        }

        debugPrint('[CALENDAR] [DISCONNECT] Backend confirmed disconnection');
      } catch (backendError) {
        debugPrint(
          '[CALENDAR] [DISCONNECT] Backend call failed: $backendError',
        );
        debugPrint('[CALENDAR] [DISCONNECT] Error type: ${backendError.runtimeType}');

        // Check for timeout specifically
        if (backendError is CloudFunctionTimeoutException) {
          debugPrint('[CALENDAR] [DISCONNECT] Function timed out after ${(backendError as CloudFunctionTimeoutException).timeout.inSeconds}s');
          // Timeout means operation might still be running
          // For disconnect, this is usually okay - backend will complete eventually
          // But we should tell user differently than network error
          return CalendarDisconnectResult.networkError; // TODO: Add timeout-specific result
        }

        // Check for actual network errors
        final errorStr = backendError.toString().toLowerCase();
        if (errorStr.contains('network') ||
            errorStr.contains('socket') ||
            errorStr.contains('failed host lookup')) {
          return CalendarDisconnectResult.networkError;
        }

        return CalendarDisconnectResult.backendFailed;
      }

      // Clear local calendar state (backend already revoked tokens)
      // DON'T sign out of Google - that would log user out of the entire app!
      debugPrint('[CALENDAR] [DISCONNECT] Clearing local calendar state...');
      _currentAccount = null;
      _calendarApi = null;

      debugPrint('[CALENDAR] [DISCONNECT] SUCCESS for user=$userId');
      return CalendarDisconnectResult.success;
    } catch (e) {
      debugPrint('[CALENDAR] [DISCONNECT] FAILED: $e');

      // Ensure local state is cleared even on error
      _currentAccount = null;
      _calendarApi = null;

      return CalendarDisconnectResult.backendFailed;
    }
  }

  /// Create a calendar event for a task
  Future<String?> createTaskEvent({
    required String title,
    required String description,
    required DateTime deadline,
    String? attendeeEmail,
  }) async {
    if (_calendarApi == null) {
      debugPrint('Calendar: Not connected');
      return null;
    }

    try {
      // Create event with deadline as end time, 1 hour duration
      final startTime = deadline.subtract(const Duration(hours: 1));

      // Get device timezone
      final timeZone = DateTime.now().timeZoneName;

      final event = calendar.Event(
        summary: title,
        description: description,
        start: calendar.EventDateTime(
          dateTime: startTime.toUtc(),
          timeZone: timeZone,
        ),
        end: calendar.EventDateTime(
          dateTime: deadline.toUtc(),
          timeZone: timeZone,
        ),
        reminders: calendar.EventReminders(
          useDefault: false,
          overrides: [
            calendar.EventReminder(method: 'popup', minutes: 30),
            calendar.EventReminder(method: 'email', minutes: 60),
          ],
        ),
      );

      // Add attendee if provided
      if (attendeeEmail != null && attendeeEmail.isNotEmpty) {
        event.attendees = [calendar.EventAttendee(email: attendeeEmail)];
      }

      final createdEvent = await _calendarApi!.events.insert(event, 'primary');

      debugPrint('Calendar: Event created - ${createdEvent.id}');
      return createdEvent.id;
    } catch (e) {
      debugPrint('Calendar: Event creation failed - $e');
      return null;
    }
  }

  /// Update a calendar event
  Future<bool> updateTaskEvent({
    required String eventId,
    String? title,
    String? description,
    DateTime? deadline,
  }) async {
    if (_calendarApi == null) {
      debugPrint('Calendar: Not connected');
      return false;
    }

    try {
      // Get existing event
      final existingEvent = await _calendarApi!.events.get('primary', eventId);

      // Update fields
      if (title != null) existingEvent.summary = title;
      if (description != null) existingEvent.description = description;
      if (deadline != null) {
        final startTime = deadline.subtract(const Duration(hours: 1));
        final timeZone = DateTime.now().timeZoneName;
        existingEvent.start = calendar.EventDateTime(
          dateTime: startTime.toUtc(),
          timeZone: timeZone,
        );
        existingEvent.end = calendar.EventDateTime(
          dateTime: deadline.toUtc(),
          timeZone: timeZone,
        );
      }

      await _calendarApi!.events.update(existingEvent, 'primary', eventId);

      debugPrint('Calendar: Event updated - $eventId');
      return true;
    } catch (e) {
      debugPrint('Calendar: Event update failed - $e');
      return false;
    }
  }

  /// Delete a calendar event
  Future<bool> deleteTaskEvent(String eventId) async {
    if (_calendarApi == null) {
      debugPrint('Calendar: Not connected');
      return false;
    }

    try {
      await _calendarApi!.events.delete('primary', eventId);
      debugPrint('Calendar: Event deleted - $eventId');
      return true;
    } catch (e) {
      debugPrint('Calendar: Event deletion failed - $e');
      return false;
    }
  }

  /// Mark event as completed (update color/status)
  Future<bool> markEventCompleted(String eventId) async {
    if (_calendarApi == null) return false;

    try {
      final event = await _calendarApi!.events.get('primary', eventId);
      event.summary = '${event.summary}';
      event.colorId = '10'; // Green color

      await _calendarApi!.events.update(event, 'primary', eventId);
      return true;
    } catch (e) {
      debugPrint('Calendar: Mark completed failed - $e');
      return false;
    }
  }
}

/// Custom HTTP client with Google auth headers
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
