import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cloud_functions_service.dart';

/// Google Calendar integration service
class CalendarService {
  // Singleton pattern
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Google Sign-In with Calendar scope
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', calendar.CalendarApi.calendarEventsScope],
  );

  GoogleSignInAccount? _currentAccount;
  calendar.CalendarApi? _calendarApi;

  /// Check if calendar is connected
  bool get isConnected => _calendarApi != null;

  /// Connect to Google Calendar
  Future<bool> connect(String userId) async {
    try {
      // Sign in with Google (will prompt for Calendar permission)
      _currentAccount = await _googleSignIn.signIn();

      if (_currentAccount == null) {
        debugPrint('❌ Calendar: User cancelled sign-in');
        return false;
      }

      // Get auth headers
      final auth = await _currentAccount!.authentication;

      // Create authenticated HTTP client
      final authenticatedClient = _GoogleAuthClient(
        await _currentAccount!.authHeaders,
      );

      // Initialize Calendar API
      _calendarApi = calendar.CalendarApi(authenticatedClient);

      // Save connection status to Firestore
      await _firestore.collection('users').doc(userId).update({
        'googleCalendarConnected': true,
        'googleAccessToken': auth.accessToken,
      });

      debugPrint('✅ Calendar: Connected successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Calendar: Connection failed - $e');
      return false;
    }
  }

  /// Disconnect from Google Calendar via Cloud Function
  Future<void> disconnect(String userId) async {
    try {
      // Sign out locally first
      await _googleSignIn.signOut();
      _currentAccount = null;
      _calendarApi = null;

      // Call Cloud Function to delete calendar events and clear tokens
      final cloudFunctions = CloudFunctionsService();
      await cloudFunctions.disconnectCalendar();

      debugPrint('✅ Calendar: Disconnected');
    } catch (e) {
      debugPrint('❌ Calendar: Disconnect failed - $e');
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

      final event = calendar.Event(
        summary: title,
        description: description,
        start: calendar.EventDateTime(
          dateTime: startTime,
          timeZone: 'Asia/Kolkata', // Adjust based on user's timezone
        ),
        end: calendar.EventDateTime(
          dateTime: deadline,
          timeZone: 'Asia/Kolkata',
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
        existingEvent.start = calendar.EventDateTime(
          dateTime: startTime,
          timeZone: 'Asia/Kolkata',
        );
        existingEvent.end = calendar.EventDateTime(
          dateTime: deadline,
          timeZone: 'Asia/Kolkata',
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
