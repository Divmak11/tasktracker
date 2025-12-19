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
    debugPrint('📅 [CALENDAR] [REFRESH_TOKEN] Starting for user=$userId');

    int attempt = 0;
    Exception? lastError;

    while (attempt <= maxRetries) {
      attempt++;
      debugPrint(
        '📅 [CALENDAR] [REFRESH_TOKEN] Attempt $attempt/${maxRetries + 1}',
      );

      try {
        // Attempt silent sign-in to reuse existing consent
        _currentAccount = await _googleSignIn.signInSilently();

        if (_currentAccount == null) {
          debugPrint(
            '📅 [CALENDAR] [REFRESH_TOKEN] Silent sign-in returned null',
          );
          // Silent sign-in failed - user needs to reconnect calendar
          return CalendarRefreshResult.reconnectNeeded;
        }

        debugPrint(
          '📅 [CALENDAR] [REFRESH_TOKEN] Silent sign-in SUCCESS '
          'email=${_currentAccount!.email}',
        );

        final auth = await _currentAccount!.authentication;
        if (auth.accessToken == null) {
          debugPrint('📅 [CALENDAR] [REFRESH_TOKEN] No access token available');
          return CalendarRefreshResult.reconnectNeeded;
        }

        debugPrint(
          '📅 [CALENDAR] [REFRESH_TOKEN] Got new access token '
          '(preview=${auth.accessToken!.substring(0, 20)}...)',
        );

        // Update only the access token - backend manages refresh token
        await _firestore.collection('users').doc(userId).update({
          'googleCalendarConnected': true,
          'googleAccessToken': auth.accessToken,
        });

        debugPrint(
          '✅ [CALENDAR] [REFRESH_TOKEN] SUCCESS - Saved to Firestore for '
          'user=$userId',
        );
        return CalendarRefreshResult.success;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('❌ [CALENDAR] [REFRESH_TOKEN] Attempt $attempt FAILED: $e');

        // Wait before retry (exponential backoff)
        if (attempt <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    debugPrint(
      '❌ [CALENDAR] [REFRESH_TOKEN] All $attempt attempts failed. '
      'Last error: $lastError',
    );
    return CalendarRefreshResult.failed;
  }

  /// Connect to Google Calendar using Server Auth Code flow
  ///
  /// This flow ensures the backend gets a REAL refresh_token that can be used
  /// to refresh access tokens automatically, even when the app is closed.
  Future<bool> connect(String userId) async {
    debugPrint('📅 [CALENDAR] [CONNECT] Starting for user=$userId');
    debugPrint('📅 [CALENDAR] [CONNECT] Using webClientId=$_webClientId');

    try {
      // Sign in with Google (will prompt for Calendar permission)
      debugPrint('📅 [CALENDAR] [CONNECT] Initiating GoogleSignIn...');
      _currentAccount = await _googleSignIn.signIn();

      if (_currentAccount == null) {
        debugPrint('❌ [CALENDAR] [CONNECT] User cancelled sign-in');
        return false;
      }

      debugPrint('📅 [CALENDAR] [CONNECT] GoogleSignIn SUCCESS');
      debugPrint('📅 [CALENDAR] [CONNECT] email=${_currentAccount!.email}');
      debugPrint(
        '📅 [CALENDAR] [CONNECT] '
        'hasServerAuthCode=${_currentAccount!.serverAuthCode != null}',
      );

      // Get auth headers for local calendar operations
      final auth = await _currentAccount!.authentication;
      debugPrint(
        '📅 [CALENDAR] [CONNECT] '
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
      // This is the key to getting a REAL refresh_token
      final serverAuthCode = _currentAccount!.serverAuthCode;

      if (serverAuthCode != null && serverAuthCode.isNotEmpty) {
        debugPrint(
          '📅 [CALENDAR] [CONNECT] Got serverAuthCode '
          '(length=${serverAuthCode.length})',
        );
        debugPrint(
          '📅 [CALENDAR] [CONNECT] Calling backend exchangeCalendarAuthCode...',
        );

        try {
          final result = await _cloudFunctions.exchangeCalendarAuthCode(
            serverAuthCode,
          );
          final hasRefreshToken = result['hasRefreshToken'] == true;
          debugPrint(
            '✅ [CALENDAR] [CONNECT] Backend token exchange SUCCESS '
            'hasRefreshToken=$hasRefreshToken',
          );
        } catch (e) {
          // Log but don't fail - we can still use local tokens
          debugPrint('⚠️ [CALENDAR] [CONNECT] Backend exchange FAILED: $e');
          debugPrint('📅 [CALENDAR] [CONNECT] Falling back to local tokens...');
          await _saveLocalTokens(userId, auth.accessToken);
        }
      } else {
        // No serverAuthCode received (rare edge case)
        debugPrint(
          '⚠️ [CALENDAR] [CONNECT] No serverAuthCode received! '
          'Check if webClientId is correct.',
        );
        await _saveLocalTokens(userId, auth.accessToken);
      }

      debugPrint('✅ [CALENDAR] [CONNECT] COMPLETE for user=$userId');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [CALENDAR] [CONNECT] FAILED: $e');
      debugPrint('❌ [CALENDAR] [CONNECT] StackTrace: $stackTrace');
      return false;
    }
  }

  /// Save tokens locally when serverAuthCode flow is not available
  Future<void> _saveLocalTokens(String userId, String? accessToken) async {
    if (accessToken == null) return;

    await _firestore.collection('users').doc(userId).update({
      'googleCalendarConnected': true,
      'googleAccessToken': accessToken,
    });
    debugPrint('📅 Calendar: Saved local access token for user $userId');
  }

  /// Disconnect from Google Calendar via Cloud Function
  Future<void> disconnect(String userId) async {
    debugPrint('📅 [CALENDAR] [DISCONNECT] Starting for user=$userId');

    try {
      // Sign out locally first
      debugPrint('📅 [CALENDAR] [DISCONNECT] Signing out locally...');
      await _googleSignIn.signOut();
      _currentAccount = null;
      _calendarApi = null;

      // Call Cloud Function to delete calendar events and clear tokens
      debugPrint(
        '📅 [CALENDAR] [DISCONNECT] Calling backend to delete events...',
      );
      final cloudFunctions = CloudFunctionsService();
      await cloudFunctions.disconnectCalendar();

      debugPrint('✅ [CALENDAR] [DISCONNECT] SUCCESS for user=$userId');
    } catch (e) {
      debugPrint('❌ [CALENDAR] [DISCONNECT] FAILED: $e');
      // Still update local state even if cloud function fails
      _currentAccount = null;
      _calendarApi = null;
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
      debugPrint('❌ Calendar: Not connected');
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

      debugPrint('✅ Calendar: Event created - ${createdEvent.id}');
      return createdEvent.id;
    } catch (e) {
      debugPrint('❌ Calendar: Event creation failed - $e');
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
      debugPrint('❌ Calendar: Not connected');
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

      debugPrint('✅ Calendar: Event updated - $eventId');
      return true;
    } catch (e) {
      debugPrint('❌ Calendar: Event update failed - $e');
      return false;
    }
  }

  /// Delete a calendar event
  Future<bool> deleteTaskEvent(String eventId) async {
    if (_calendarApi == null) {
      debugPrint('❌ Calendar: Not connected');
      return false;
    }

    try {
      await _calendarApi!.events.delete('primary', eventId);
      debugPrint('✅ Calendar: Event deleted - $eventId');
      return true;
    } catch (e) {
      debugPrint('❌ Calendar: Event deletion failed - $e');
      return false;
    }
  }

  /// Mark event as completed (update color/status)
  Future<bool> markEventCompleted(String eventId) async {
    if (_calendarApi == null) return false;

    try {
      final event = await _calendarApi!.events.get('primary', eventId);
      event.summary = '✅ ${event.summary}';
      event.colorId = '10'; // Green color

      await _calendarApi!.events.update(event, 'primary', eventId);
      return true;
    } catch (e) {
      debugPrint('❌ Calendar: Mark completed failed - $e');
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
