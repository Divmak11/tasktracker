# Google Calendar Integration - Complete Developer Guide

> **Module Version:** 2.1 (Upfront Calendar Consent Flow)  
> **Last Updated:** January 2026  
> **Platforms:** Flutter (iOS/Android) + Firebase Cloud Functions v2
>
> **Key Changes in v2.1:**
> - Calendar consent moved to initial Google Sign-In flow
> - iOS-specific platform handling for serverAuthCode
> - New `CalendarRefreshResult` enum for token refresh operations

This guide provides step-by-step instructions to implement Google Calendar integration identical to the Taskiya app. A 10-year-old should be able to follow this.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Google Cloud Console Setup](#2-google-cloud-console-setup)
3. [Environment Configuration](#3-environment-configuration)
4. [Backend Implementation](#4-backend-implementation)
5. [Frontend Implementation](#5-frontend-implementation)
6. [User Flows](#6-user-flows)
7. [Platform-Specific Considerations](#7-platform-specific-considerations)
8. [Edge Case Handling](#8-edge-case-handling)
9. [Testing Checklist](#9-testing-checklist)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Prerequisites

Before starting, ensure you have:

- [ ] Firebase project created
- [ ] Cloud Functions enabled (Blaze plan)
- [ ] Flutter app with `google_sign_in` package
- [ ] Firestore database set up
- [ ] A Google Cloud Console account

---

## 2. Google Cloud Console Setup

### Step 2.1: Enable Google Calendar API

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project (same project!)
3. Navigate to **APIs & Services → Library**
4. Search for "Google Calendar API"
5. Click **Enable**

### Step 2.2: Configure OAuth Consent Screen

1. Go to **APIs & Services → OAuth consent screen**
2. Select **External** (unless you're G Suite)
3. Fill in the form:
   - **App name:** Your App Name
   - **User support email:** Your email
   - **Developer contact email:** Your email
4. Click **Save and Continue**
5. **Scopes:** Click "Add or remove scopes"
   - Add: `https://www.googleapis.com/auth/calendar.events`
   - This allows reading/writing calendar events
6. Click **Save and Continue**
7. **Test users:** Add your test email addresses
8. Click **Save and Continue**

### Step 2.3: Create OAuth 2.0 Credentials

1. Go to **APIs & Services → Credentials**
2. Click **Create Credentials → OAuth client ID**
3. Select **Web application** (yes, even for mobile!)
4. Name it: "Web Client for Mobile Auth"
5. Leave redirect URIs empty (not needed for mobile)
6. Click **Create**
7. **IMPORTANT:** Copy these values:
   - **Client ID:** `1234567890-abc.apps.googleusercontent.com`
   - **Client Secret:** `GOCSPX-xxxxxxxxxxxxx`

### Step 2.4: Download google-services.json (Android)

1. Go to Firebase Console → Project Settings
2. Under "Your apps", find Android app
3. Download `google-services.json`
4. Look for `client_type: 3` (Web) entry → This is your **Web Client ID**
5. Place in `android/app/google-services.json`

### Step 2.5: iOS Configuration

1. Go to Firebase Console → Project Settings
2. Under "Your apps", find iOS app
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/GoogleService-Info.plist`

5. Open `ios/Runner/Info.plist` and add URL scheme:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <!-- Reversed Client ID from GoogleService-Info.plist -->
      <string>com.googleusercontent.apps.1234567890-abc</string>
    </array>
  </dict>
</array>
```

6. Find `REVERSED_CLIENT_ID` in `GoogleService-Info.plist` and use that value above.

---

## 3. Environment Configuration

### 3.1: Backend Environment (.env)

Create `functions/.env`:

```bash
# Google OAuth Credentials (from Step 2.3)
GOOGLE_CLIENT_ID=1234567890-abc.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxx
```

### 3.2: Frontend Environment (.env)

Create `.env` in Flutter project root:

```bash
# Same Web Client ID as backend
GOOGLE_WEB_CLIENT_ID=1234567890-abc.apps.googleusercontent.com
```

### 3.3: Load Environment in Flutter

Create `lib/core/constants/env_config.dart`:

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
}
```

Load in `main.dart`:
```dart
await dotenv.load(fileName: '.env');
```

---

## 4. Backend Implementation

### 4.1: File Structure

```
functions/
├── src/
│   ├── config/
│   │   ├── firebase-admin.ts      # Firebase Admin SDK init
│   │   └── constants.ts           # Collection names, enums
│   ├── services/
│   │   └── calendarService.ts     # All calendar logic
│   ├── triggers/
│   │   ├── calendarTriggers.ts    # Task→Calendar sync
│   │   └── scheduledFunctions.ts  # Token maintenance
│   └── index.ts                   # Export all functions
└── .env                           # Environment variables
```

### 4.2: Firestore User Document Schema

```typescript
interface UserDocument {
  id: string;
  email: string;
  googleCalendarConnected: boolean;  // Is calendar connected?
  googleAccessToken?: string;        // Short-lived (1 hour)
  googleRefreshToken?: string;       // Long-lived (6 months)
}
```

### 4.3: Complete calendarService.ts Implementation

```typescript
// ============================================================================
// FILE: src/services/calendarService.ts
// PURPOSE: All Google Calendar operations
// ============================================================================

import { onCall, HttpsError, CallableRequest } from 'firebase-functions/v2/https';
import { google, Auth } from 'googleapis';
import { db, admin } from '../config/firebase-admin';
import { Collections } from '../config/constants';

// Configuration
const callableConfig = { region: 'asia-south1', concurrency: 80 };

// ============================================================================
// LOGGING UTILITIES
// ============================================================================
const LOG_PREFIX = '📅 [CALENDAR]';

function calendarLog(operation: string, userId: string, details: Record<string, unknown> = {}): void {
  console.log(`${LOG_PREFIX} [${operation}] user=${userId}`, details);
}

function calendarError(operation: string, userId: string, error: unknown, details: Record<string, unknown> = {}): void {
  console.error(`${LOG_PREFIX} [${operation}] ERROR user=${userId}`, { ...details, error });
}

// ============================================================================
// CORE: GET AUTHENTICATED CLIENT
// Creates OAuth2 client with stored tokens, auto-refreshes and persists new tokens
// ============================================================================
async function getAuthenticatedClient(userId: string): Promise<{
  oauth2Client: Auth.OAuth2Client;
  calendar: ReturnType<typeof google.calendar>;
} | null> {
  // 1. Get user document
  const userDoc = await db.collection(Collections.USERS).doc(userId).get();
  const user = userDoc.data();

  // 2. Validate user has calendar enabled
  if (!user?.googleCalendarConnected || !user?.googleAccessToken) {
    calendarLog('GET_AUTH_CLIENT', userId, { status: 'SKIPPED', reason: 'not_connected' });
    return null;
  }

  // 3. Get OAuth credentials from environment
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  if (!clientId || !clientSecret) {
    calendarError('GET_AUTH_CLIENT', userId, 'Missing OAuth config', {});
    return null;
  }

  // 4. Create OAuth2 client
  const oauth2Client = new google.auth.OAuth2(clientId, clientSecret);

  // 5. Set credentials (both access and refresh tokens)
  const credentials: { access_token: string; refresh_token?: string; token_type: string } = {
    access_token: user.googleAccessToken,
    token_type: 'Bearer',
  };
  if (user.googleRefreshToken) {
    credentials.refresh_token = user.googleRefreshToken;
  }
  oauth2Client.setCredentials(credentials);

  // 6. CRITICAL: Listen for token refresh events and persist to Firestore
  oauth2Client.on('tokens', async (tokens) => {
    const updateData: Record<string, string> = {};
    if (tokens.access_token) updateData.googleAccessToken = tokens.access_token;
    if (tokens.refresh_token) updateData.googleRefreshToken = tokens.refresh_token;

    if (Object.keys(updateData).length > 0) {
      await db.collection(Collections.USERS).doc(userId).update(updateData);
      calendarLog('TOKEN_AUTO_REFRESHED', userId, { savedNewTokens: true });
    }
  });

  // 7. Return client and calendar API
  return {
    oauth2Client,
    calendar: google.calendar({ version: 'v3', auth: oauth2Client }),
  };
}

// ============================================================================
// ERROR HANDLING: Detect token revocation and reset connection
// ============================================================================
async function handleCalendarAuthError(error: unknown, userId: string): Promise<boolean> {
  const errorWithResponse = error as { response?: { status?: number }; message?: string };
  const status = errorWithResponse?.response?.status;
  const message = errorWithResponse?.message || '';

  // Check for auth errors that require user to reconnect
  const isUnauthorized = status === 401;
  const isTokenRevoked = message.includes('invalid_grant') ||
    message.includes('Token has been expired or revoked');

  if (isUnauthorized || isTokenRevoked) {
    calendarLog('AUTH_ERROR_DETECTED', userId, { action: 'RESETTING_CONNECTION' });

    // Clear connection AND tokens (so reconnectCalendar doesn't try dead tokens)
    await db.collection(Collections.USERS).doc(userId).update({
      googleCalendarConnected: false,
      googleRefreshToken: admin.firestore.FieldValue.delete(),
      googleAccessToken: admin.firestore.FieldValue.delete(),
    });

    return true; // Was an auth error
  }

  return false; // Not an auth error
}

// ============================================================================
// CREATE CALENDAR EVENT
// ============================================================================
export async function createCalendarEventForUser(
  userId: string,
  taskId: string,
  title: string,
  subtitle: string,
  deadline: Date,
  skipTaskDocUpdate = false,
  providedCalendar?: ReturnType<typeof google.calendar>
): Promise<string | null> {
  // Check if user has calendar connected
  const userDoc = await db.collection(Collections.USERS).doc(userId).get();
  if (!userDoc.data()?.googleCalendarConnected) {
    return null; // Not connected, skip silently
  }

  // Get authenticated client
  const calendar = providedCalendar || (await getAuthenticatedClient(userId))?.calendar;
  if (!calendar) return null;

  try {
    // Create event: deadline as start, +1 hour as end
    const endTime = new Date(deadline.getTime() + 60 * 60 * 1000);

    const event = await calendar.events.insert({
      calendarId: 'primary',
      requestBody: {
        summary: title,
        description: subtitle,
        start: { dateTime: deadline.toISOString() },
        end: { dateTime: endTime.toISOString() },
        reminders: {
          useDefault: false,
          overrides: [
            { method: 'popup', minutes: 1440 }, // 24h before
            { method: 'popup', minutes: 60 },   // 1h before
          ],
        },
      },
    });

    const eventId = event.data.id;
    calendarLog('CREATE_EVENT', userId, { taskId, eventId });

    // Save event ID to task document (optional)
    if (!skipTaskDocUpdate && eventId) {
      await db.collection(Collections.TASKS).doc(taskId).update({ calendarEventId: eventId });
    }

    return eventId ?? null;
  } catch (error) {
    await handleCalendarAuthError(error, userId);
    calendarError('CREATE_EVENT', userId, error, { taskId });
    return null;
  }
}

// ============================================================================
// UPDATE CALENDAR EVENT
// ============================================================================
export async function updateCalendarEvent(
  userId: string,
  eventId: string,
  newDeadline?: Date,
  newTitle?: string,
  newSubtitle?: string
): Promise<boolean> {
  const calendar = (await getAuthenticatedClient(userId))?.calendar;
  if (!calendar) return false;

  try {
    const requestBody: any = {};
    if (newDeadline) {
      const endTime = new Date(newDeadline.getTime() + 60 * 60 * 1000);
      requestBody.start = { dateTime: newDeadline.toISOString() };
      requestBody.end = { dateTime: endTime.toISOString() };
    }
    if (newTitle) requestBody.summary = newTitle;
    if (newSubtitle !== undefined) requestBody.description = newSubtitle;

    await calendar.events.patch({
      calendarId: 'primary',
      eventId,
      requestBody,
    });

    calendarLog('UPDATE_EVENT', userId, { eventId });
    return true;
  } catch (error) {
    await handleCalendarAuthError(error, userId);
    return false;
  }
}

// ============================================================================
// DELETE CALENDAR EVENT
// ============================================================================
export async function deleteCalendarEvent(
  userId: string,
  eventId: string
): Promise<boolean> {
  const calendar = (await getAuthenticatedClient(userId))?.calendar;
  if (!calendar) return false;

  try {
    await calendar.events.delete({
      calendarId: 'primary',
      eventId,
    });
    calendarLog('DELETE_EVENT', userId, { eventId });
    return true;
  } catch (error) {
    // 404 = already deleted, consider success
    if ((error as any)?.response?.status === 404) return true;
    await handleCalendarAuthError(error, userId);
    return false;
  }
}

// ============================================================================
// DELETE ALL USER CALENDAR EVENTS (for disconnect/account deletion)
// ============================================================================
export async function deleteAllUserCalendarEvents(userId: string): Promise<void> {
  const authResult = await getAuthenticatedClient(userId);
  if (!authResult) return;

  const { calendar } = authResult;

  // Get all tasks assigned to this user with calendar events
  const tasksSnapshot = await db.collection(Collections.TASKS)
    .where('assignedTo', '==', userId)
    .where('calendarEventId', '>=', '')
    .get();

  // Delete each event
  const deletes = tasksSnapshot.docs.map(async (taskDoc) => {
    const task = taskDoc.data();
    if (task.calendarEventId) {
      await deleteCalendarEvent(userId, task.calendarEventId);
      await taskDoc.ref.update({ calendarEventId: null });
    }
  });

  await Promise.allSettled(deletes);
  calendarLog('DELETE_ALL_EVENTS', userId, { deletedCount: deletes.length });
}

// ============================================================================
// VERIFY TOKEN WORKS (test API call before marking connected)
// ============================================================================
async function verifyCalendarAccess(accessToken: string): Promise<{ success: boolean; error?: string }> {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  if (!clientId || !clientSecret) return { success: false, error: 'No OAuth config' };

  try {
    const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, '');
    oauth2Client.setCredentials({ access_token: accessToken });
    const calendar = google.calendar({ version: 'v3', auth: oauth2Client });

    // Make lightweight test call
    await calendar.events.list({
      calendarId: 'primary',
      maxResults: 1,
      timeMin: new Date().toISOString(),
    });

    return { success: true };
  } catch (error) {
    return { success: false, error: (error as Error).message };
  }
}

// ============================================================================
// CLOUD FUNCTION: exchangeCalendarAuthCode
// Exchange one-time auth code for access/refresh tokens
// ============================================================================
export const exchangeCalendarAuthCode = onCall(
  callableConfig,
  async (request: CallableRequest<{ authCode: string }>) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError('unauthenticated', 'Not authenticated');

    const authCode = request.data.authCode;
    if (!authCode) throw new HttpsError('invalid-argument', 'authCode is required');

    const clientId = process.env.GOOGLE_CLIENT_ID;
    const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
    if (!clientId || !clientSecret) {
      throw new HttpsError('failed-precondition', 'OAuth not configured');
    }

    try {
      // 1. Exchange auth code for tokens
      const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, '');
      const { tokens } = await oauth2Client.getToken(authCode);

      if (!tokens.access_token) {
        throw new HttpsError('internal', 'No access token received');
      }

      // 2. VERIFY token works before marking connected
      const verification = await verifyCalendarAccess(tokens.access_token);
      if (!verification.success) {
        throw new HttpsError('internal', `Verification failed: ${verification.error}`);
      }

      // 3. Save tokens to Firestore
      const updateData: Record<string, unknown> = {
        googleAccessToken: tokens.access_token,
        googleCalendarConnected: true,
      };
      if (tokens.refresh_token) {
        updateData.googleRefreshToken = tokens.refresh_token;
      }
      await db.collection(Collections.USERS).doc(userId).update(updateData);

      calendarLog('EXCHANGE_AUTH_CODE', userId, { status: 'SUCCESS' });
      return { success: true, hasRefreshToken: !!tokens.refresh_token };

    } catch (error) {
      const msg = (error as Error).message;
      if (msg.includes('invalid_grant')) {
        throw new HttpsError('invalid-argument', 'Auth code expired or already used. Please try connecting again.');
      }
      throw new HttpsError('internal', `Exchange failed: ${msg}`);
    }
  }
);

// ============================================================================
// CLOUD FUNCTION: reconnectCalendar
// Use stored refresh token to reconnect without user interaction
// ============================================================================
export const reconnectCalendar = onCall(
  callableConfig,
  async (request: CallableRequest<unknown>) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError('unauthenticated', 'Not authenticated');

    try {
      // 1. Check for existing refresh token
      const userDoc = await db.collection(Collections.USERS).doc(userId).get();
      const user = userDoc.data();

      if (!user?.googleRefreshToken) {
        return { success: false, requiresReauth: true, message: 'No saved credentials' };
      }

      // 2. Refresh the access token
      const clientId = process.env.GOOGLE_CLIENT_ID;
      const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
      if (!clientId || !clientSecret) {
        throw new HttpsError('failed-precondition', 'OAuth not configured');
      }

      const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, '');
      oauth2Client.setCredentials({ refresh_token: user.googleRefreshToken });
      const { credentials } = await oauth2Client.refreshAccessToken();

      if (!credentials.access_token) {
        throw new Error('Failed to refresh access token');
      }

      // 3. Verify the new token works
      const verification = await verifyCalendarAccess(credentials.access_token);
      if (!verification.success) {
        // User revoked access in Google Settings - clear tokens
        await db.collection(Collections.USERS).doc(userId).update({
          googleRefreshToken: admin.firestore.FieldValue.delete(),
          googleAccessToken: admin.firestore.FieldValue.delete(),
          googleCalendarConnected: false,
        });
        return { success: false, requiresReauth: true, message: 'Connection revoked' };
      }

      // 4. Update Firestore
      await db.collection(Collections.USERS).doc(userId).update({
        googleAccessToken: credentials.access_token,
        googleCalendarConnected: true,
      });

      calendarLog('RECONNECT_CALENDAR', userId, { status: 'SUCCESS' });
      return { success: true, requiresReauth: false };

    } catch (error) {
      const msg = (error as Error).message;
      if (msg.includes('invalid_grant') || msg.includes('revoked')) {
        await db.collection(Collections.USERS).doc(userId).update({
          googleRefreshToken: admin.firestore.FieldValue.delete(),
          googleAccessToken: admin.firestore.FieldValue.delete(),
          googleCalendarConnected: false,
        });
        return { success: false, requiresReauth: true, message: 'Connection expired' };
      }
      throw new HttpsError('internal', `Reconnection failed: ${msg}`);
    }
  }
);

// ============================================================================
// CLOUD FUNCTION: disconnectCalendar
// Delete all events and mark calendar as disconnected
// ============================================================================
export const disconnectCalendar = onCall(
  callableConfig,
  async (request: CallableRequest<unknown>) => {
    const userId = request.auth?.uid;
    if (!userId) throw new HttpsError('unauthenticated', 'Not authenticated');

    const userDoc = await db.collection(Collections.USERS).doc(userId).get();
    if (!userDoc.data()?.googleCalendarConnected) {
      return { success: true, message: 'Already disconnected' };
    }

    // Delete events BEFORE setting flag (otherwise getAuthenticatedClient fails)
    await deleteAllUserCalendarEvents(userId);

    // Set flag to false (preserve tokens for easy reconnect)
    await db.collection(Collections.USERS).doc(userId).update({
      googleCalendarConnected: false,
    });

    calendarLog('DISCONNECT', userId, { status: 'SUCCESS' });
    return { success: true, message: 'Calendar disconnected' };
  }
);
```

### 4.4: Sync Existing Tasks Function (called after connection)

```typescript
// Add this to calendarService.ts

async function syncExistingTasksToCalendar(userId: string): Promise<number> {
  const authResult = await getAuthenticatedClient(userId);
  if (!authResult) return 0;
  
  const { calendar } = authResult;
  let syncedCount = 0;

  // Get all ongoing tasks assigned to this user
  const tasksSnapshot = await db.collection(Collections.TASKS)
    .where('assignedTo', '==', userId)
    .where('status', '==', 'ongoing')
    .get();

  for (const taskDoc of tasksSnapshot.docs) {
    const task = taskDoc.data();
    if (task.calendarEventId) continue; // Already has event

    const deadline = task.deadline?.toDate();
    if (deadline && deadline > new Date()) {
      const eventId = await createCalendarEventForUser(
        userId, taskDoc.id, task.title, task.subtitle || '', deadline,
        false, calendar
      );
      if (eventId) syncedCount++;
    }
  }

  calendarLog('SYNC_EXISTING_TASKS', userId, { syncedCount });
  return syncedCount;
}
```

**Call this after successful token exchange:**
```typescript
// In exchangeCalendarAuthCode, after saving tokens:
syncExistingTasksToCalendar(userId).catch((err) => {
  calendarError('SYNC_EXISTING_TASKS', userId, err, {});
});
```

### 4.5: Token Maintenance Scheduled Function

```typescript
// FILE: src/triggers/scheduledFunctions.ts

import { onSchedule } from 'firebase-functions/v2/scheduler';
import { google } from 'googleapis';
import { db, admin } from '../config/firebase-admin';
import { Collections } from '../config/constants';
import { sendNotification, createNotificationData } from '../services/notificationService';

const scheduleConfig = { region: 'asia-south1' };

/**
 * Runs on the 1st of every month at 3 AM
 * Proactively refreshes tokens and detects revoked access
 */
export const maintainCalendarTokens = onSchedule(
  { schedule: '0 3 1 * *', ...scheduleConfig },
  async () => {
    console.log('🔄 [CALENDAR_MAINTENANCE] Starting monthly token check...');

    const usersWithCalendar = await db.collection(Collections.USERS)
      .where('googleCalendarConnected', '==', true)
      .get();

    const clientId = process.env.GOOGLE_CLIENT_ID;
    const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
    if (!clientId || !clientSecret) {
      console.error('🔄 [CALENDAR_MAINTENANCE] Missing OAuth credentials');
      return;
    }

    let refreshedCount = 0;
    let revokedCount = 0;

    for (const userDoc of usersWithCalendar.docs) {
      const userId = userDoc.id;
      const user = userDoc.data();

      if (!user.googleRefreshToken) continue;

      try {
        const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, '');
        oauth2Client.setCredentials({ refresh_token: user.googleRefreshToken });
        const { credentials } = await oauth2Client.refreshAccessToken();

        if (credentials.access_token) {
          await userDoc.ref.update({ googleAccessToken: credentials.access_token });
          refreshedCount++;
        }
      } catch (error) {
        const msg = (error as Error).message;
        if (msg.includes('invalid_grant') || msg.includes('revoked')) {
          // Token was revoked - clear connection
          await userDoc.ref.update({
            googleCalendarConnected: false,
            googleRefreshToken: admin.firestore.FieldValue.delete(),
            googleAccessToken: admin.firestore.FieldValue.delete(),
          });
          revokedCount++;

          // Notify user
          await sendNotification(
            userId,
            '🔄 Calendar Reconnection Required',
            'Your calendar connection expired. Please reconnect in Settings.',
            createNotificationData('task_updated', { action: 'calendar_reconnect' })
          );
        }
      }
    }

    console.log(`🔄 [CALENDAR_MAINTENANCE] Complete. Refreshed: ${refreshedCount}, Revoked: ${revokedCount}`);
  }
);
```

### 4.6: Calendar Triggers (Task → Calendar Sync)

```typescript
// FILE: src/triggers/calendarTriggers.ts

import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { createCalendarEventForUser, updateCalendarEvent, deleteCalendarEvent } from '../services/calendarService';
import { db } from '../config/firebase-admin';
import { Collections } from '../config/constants';

const firestoreConfig = { region: 'asia-south1' };

// When task is created → create calendar event
export const onTaskCreated = onDocumentCreated(
  { document: `${Collections.TASKS}/{taskId}`, ...firestoreConfig },
  async (event) => {
    const task = event.data?.data();
    if (!task || task.status !== 'ongoing' || !task.assignedTo) return;

    const deadline = task.deadline?.toDate();
    if (!deadline || deadline < new Date()) return;

    await createCalendarEventForUser(
      task.assignedTo,
      event.params.taskId,
      task.title,
      task.subtitle || '',
      deadline
    );
  }
);

// When task is updated → update calendar event
export const onTaskUpdated = onDocumentUpdated(
  { document: `${Collections.TASKS}/{taskId}`, ...firestoreConfig },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || !after.assignedTo) return;

    // If task was completed/deleted, remove calendar event
    if (after.status !== 'ongoing' && before.calendarEventId) {
      await deleteCalendarEvent(after.assignedTo, before.calendarEventId);
      await event.data?.after.ref.update({ calendarEventId: null });
      return;
    }

    // If task has calendar event and deadline/title changed, update it
    if (after.calendarEventId) {
      const newDeadline = after.deadline?.toDate();
      const deadlineChanged = before.deadline?.toDate()?.getTime() !== newDeadline?.getTime();
      const titleChanged = before.title !== after.title;
      const subtitleChanged = before.subtitle !== after.subtitle;

      if (deadlineChanged || titleChanged || subtitleChanged) {
        await updateCalendarEvent(
          after.assignedTo,
          after.calendarEventId,
          deadlineChanged ? newDeadline : undefined,
          titleChanged ? after.title : undefined,
          subtitleChanged ? after.subtitle : undefined
        );
      }
    }
  }
);

// When task is deleted → delete calendar event
export const onTaskDeleted = onDocumentDeleted(
  { document: `${Collections.TASKS}/{taskId}`, ...firestoreConfig },
  async (event) => {
    const task = event.data?.data();
    if (!task?.calendarEventId || !task?.assignedTo) return;

    await deleteCalendarEvent(task.assignedTo, task.calendarEventId);
  }
);
```

### 4.7: Export Functions in index.ts

```typescript
// src/index.ts

// Calendar callable functions
export {
  exchangeCalendarAuthCode,
  reconnectCalendar,
  disconnectCalendar,
} from './services/calendarService';

// Calendar triggers
export {
  onTaskCreated,
  onTaskUpdated,
  onTaskDeleted,
} from './triggers/calendarTriggers';

// Scheduled functions
export { maintainCalendarTokens } from './triggers/scheduledFunctions';
```

### 4.8: Deploy Backend

```bash
cd functions
firebase deploy --only functions
```

---

## 5. Frontend Implementation

### 5.1: Dependencies (pubspec.yaml)

```yaml
dependencies:
  google_sign_in: ^6.2.1
  googleapis: ^11.5.0
  cloud_functions: ^4.5.8
  cloud_firestore: ^4.13.6
  flutter_dotenv: ^5.1.0
  http: ^1.2.0  # REQUIRED for _GoogleAuthClient
```

### 5.2: Complete CalendarService Implementation

```dart
// lib/data/services/calendar_service.dart

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/env_config.dart';
import 'cloud_functions_service.dart';

// ============================================================================
// RESULT ENUMS
// ============================================================================

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

// ============================================================================
// CALENDAR SERVICE (SINGLETON)
// ============================================================================
class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;
  CalendarService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudFunctionsService _cloudFunctions = CloudFunctionsService();

  // Web Client ID from environment config
  String get _webClientId => EnvConfig.googleWebClientId;

  // GoogleSignIn with calendar scope and serverClientId for auth code flow
  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn {
    _googleSignInInstance ??= GoogleSignIn(
      scopes: ['email', calendar.CalendarApi.calendarEventsScope],
      serverClientId: _webClientId,
    );
    return _googleSignInInstance!;
  }

  GoogleSignInAccount? _currentAccount;
  calendar.CalendarApi? _calendarApi;

  bool get isConnected => _calendarApi != null;

  // ============================================================================
  // RESET: Called on logout
  // ============================================================================
  Future<void> reset() async {
    debugPrint('📅 [CALENDAR] [RESET] Clearing local state...');
    _currentAccount = null;
    _calendarApi = null;
    
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('⚠️ [CALENDAR] [RESET] signOut error: $e');
    }
    
    _googleSignInInstance = null;  // Force fresh instance next time
    debugPrint('📅 [CALENDAR] [RESET] Complete');
  }

  // ============================================================================
  // CLEAR STALE SESSION: Called when access was revoked
  // ============================================================================
  Future<void> clearStaleSession() async {
    debugPrint('📅 [CALENDAR] [CLEAR_STALE] Clearing stale session...');
    _currentAccount = null;
    _calendarApi = null;
    
    try {
      await _googleSignIn.disconnect();  // More aggressive than signOut
    } catch (e) {
      debugPrint('⚠️ [CALENDAR] [CLEAR_STALE] disconnect error: $e');
    }
    
    _googleSignInInstance = null;
    debugPrint('📅 [CALENDAR] [CLEAR_STALE] Complete');
  }

  // ============================================================================
  // VERIFY CONNECTION STATUS: Called on login to detect revoked access
  // ============================================================================
  Future<bool> verifyConnectionStatus() async {
    debugPrint('📅 [CALENDAR] [VERIFY] Verifying connection...');
    try {
      final result = await _cloudFunctions.reconnectCalendar();
      if (result['success'] == true) {
        debugPrint('✅ [CALENDAR] [VERIFY] Connection is valid');
        return true;
      } else {
        debugPrint('⚠️ [CALENDAR] [VERIFY] Connection invalid');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [CALENDAR] [VERIFY] Error: $e');
      return false;
    }
  }

  // ============================================================================
  // REFRESH ACCESS TOKEN: Fallback for active app
  // ============================================================================
  Future<CalendarRefreshResult> refreshAccessToken(
    String userId, {
    int maxRetries = 2,
  }) async {
    debugPrint('📅 [CALENDAR] [REFRESH_TOKEN] Starting for user=$userId');

    int attempt = 0;
    Exception? lastError;

    while (attempt <= maxRetries) {
      attempt++;
      debugPrint('📅 [CALENDAR] [REFRESH_TOKEN] Attempt $attempt/${maxRetries + 1}');

      try {
        _currentAccount = await _googleSignIn.signInSilently();

        if (_currentAccount == null) {
          debugPrint('📅 [CALENDAR] [REFRESH_TOKEN] Silent sign-in returned null');
          return CalendarRefreshResult.reconnectNeeded;
        }

        final auth = await _currentAccount!.authentication;
        if (auth.accessToken == null) {
          debugPrint('📅 [CALENDAR] [REFRESH_TOKEN] No access token available');
          return CalendarRefreshResult.reconnectNeeded;
        }

        await _firestore.collection('users').doc(userId).update({
          'googleCalendarConnected': true,
          'googleAccessToken': auth.accessToken,
        });

        debugPrint('✅ [CALENDAR] [REFRESH_TOKEN] SUCCESS');
        return CalendarRefreshResult.success;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint('❌ [CALENDAR] [REFRESH_TOKEN] Attempt $attempt FAILED: $e');

        if (attempt <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }

    debugPrint('❌ [CALENDAR] [REFRESH_TOKEN] All attempts failed: $lastError');
    return CalendarRefreshResult.failed;
  }

  // ============================================================================
  // CONNECT: Main connection flow with iOS-specific handling
  // ============================================================================
  Future<CalendarConnectResult> connect(String userId) async {
    debugPrint('📅 [CALENDAR] [CONNECT] Starting for user=$userId');

    try {
      // STEP 1: Try Smart Reconnect (use stored tokens)
      debugPrint('📅 [CALENDAR] [CONNECT] Attempting Smart Reconnect...');
      bool requiresReauth = false;
      
      try {
        final reconnectResult = await _cloudFunctions.reconnectCalendar();
        if (reconnectResult['success'] == true) {
          debugPrint('✅ [CALENDAR] [CONNECT] Smart Reconnect SUCCESS!');
          
          // Try to restore local session (optional - backend is source of truth)
          try {
            _currentAccount = await _googleSignIn.signInSilently();
            if (_currentAccount != null) {
              _calendarApi = calendar.CalendarApi(
                _GoogleAuthClient(await _currentAccount!.authHeaders)
              );
            } else {
              // iOS: signInSilently often returns null even with valid consent
              debugPrint('ℹ️ [CALENDAR] [CONNECT] Local session null (iOS), but backend connected');
            }
          } catch (e) {
            debugPrint('⚠️ [CALENDAR] [CONNECT] Local restore failed, but backend is connected: $e');
          }
          return CalendarConnectResult.success;
        } else {
          requiresReauth = reconnectResult['requiresReauth'] == true;
          debugPrint('ℹ️ [CALENDAR] [CONNECT] Smart Reconnect failed. requiresReauth=$requiresReauth');
        }
      } catch (e) {
        debugPrint('⚠️ [CALENDAR] [CONNECT] Smart Reconnect error: $e');
      }

      // iOS-SPECIFIC FIX: On iOS, cached session interferes with fresh serverAuthCode
      // Must disconnect() first when reauth is required
      if (Platform.isIOS && requiresReauth) {
        debugPrint('📅 [CALENDAR] [CONNECT] iOS: requiresReauth=true, clearing stale session...');
        try {
          await _googleSignIn.disconnect();
          debugPrint('📅 [CALENDAR] [CONNECT] iOS: Session cleared');
        } catch (e) {
          debugPrint('⚠️ [CALENDAR] [CONNECT] iOS: disconnect() error: $e');
        }
      }

      // STEP 2: Full Sign-In Flow
      debugPrint('📅 [CALENDAR] [CONNECT] Trying signInSilently...');

      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.signInSilently();
        
        // CRITICAL iOS FIX: signInSilently() NEVER returns serverAuthCode on iOS
        if (account != null && account.serverAuthCode != null) {
          debugPrint('✅ [CALENDAR] [CONNECT] signInSilently SUCCESS with serverAuthCode');
        } else {
          if (account != null) {
            debugPrint('⚠️ [CALENDAR] [CONNECT] signInSilently no serverAuthCode (iOS), forcing signIn()...');
          } else {
            debugPrint('ℹ️ [CALENDAR] [CONNECT] signInSilently null, showing dialog...');
          }
          account = await _googleSignIn.signIn();
          
          // iOS FALLBACK: If still no serverAuthCode, disconnect and retry once
          if (Platform.isIOS && account != null && account.serverAuthCode == null) {
            debugPrint('⚠️ [CALENDAR] [CONNECT] iOS: No serverAuthCode, disconnecting and retrying...');
            try {
              await _googleSignIn.disconnect();
              account = await _googleSignIn.signIn();
              debugPrint('📅 [CALENDAR] [CONNECT] iOS: Retry hasServerAuthCode=${account?.serverAuthCode != null}');
            } catch (retryError) {
              debugPrint('❌ [CALENDAR] [CONNECT] iOS: Retry failed: $retryError');
            }
          }
        }
      } catch (signInError) {
        debugPrint('❌ [CALENDAR] [CONNECT] GoogleSignIn error: $signInError');
        if (signInError.toString().contains('network')) {
          return CalendarConnectResult.networkError;
        }
        return CalendarConnectResult.signInFailed;
      }

      if (account == null) {
        return CalendarConnectResult.userCancelled;
      }

      _currentAccount = account;
      debugPrint('📅 [CALENDAR] [CONNECT] GoogleSignIn SUCCESS: ${account.email}');

      // STEP 3: Get serverAuthCode
      final serverAuthCode = account.serverAuthCode;
      if (serverAuthCode == null || serverAuthCode.isEmpty) {
        debugPrint('❌ [CALENDAR] [CONNECT] No serverAuthCode!');
        _calendarApi = null;
        return CalendarConnectResult.noServerAuthCode;
      }

      // Setup local calendar API
      _calendarApi = calendar.CalendarApi(
        _GoogleAuthClient(await account.authHeaders)
      );

      // STEP 4: Exchange auth code with backend
      debugPrint('📅 [CALENDAR] [CONNECT] Calling backend exchangeCalendarAuthCode...');

      try {
        final result = await _cloudFunctions.exchangeCalendarAuthCode(serverAuthCode);
        
        if (result['success'] != true) {
          _calendarApi = null;
          return CalendarConnectResult.backendExchangeFailed;
        }

        debugPrint('✅ [CALENDAR] [CONNECT] SUCCESS');
        return CalendarConnectResult.success;

      } catch (e) {
        debugPrint('❌ [CALENDAR] [CONNECT] Backend failed: $e');
        _calendarApi = null;
        _currentAccount = null;

        final errorStr = e.toString().toLowerCase();
        
        if (errorStr.contains('expired') || errorStr.contains('already used')) {
          debugPrint('⚠️ [CALENDAR] [CONNECT] Auth code expired - clearing session');
          await clearStaleSession();
          return CalendarConnectResult.accessRevoked;
        }
        
        if (errorStr.contains('network') || errorStr.contains('socket')) {
          return CalendarConnectResult.networkError;
        }

        return CalendarConnectResult.backendExchangeFailed;
      }

    } catch (e, stackTrace) {
      debugPrint('❌ [CALENDAR] [CONNECT] FAILED: $e\n$stackTrace');
      _calendarApi = null;
      _currentAccount = null;
      return CalendarConnectResult.unknownError;
    }
  }

  // ============================================================================
  // DISCONNECT
  // ============================================================================
  Future<CalendarDisconnectResult> disconnect(String userId) async {
    debugPrint('📅 [CALENDAR] [DISCONNECT] Starting for user=$userId');

    try {
      final result = await _cloudFunctions.disconnectCalendar();
      
      if (result['success'] != true) {
        return CalendarDisconnectResult.backendFailed;
      }

      _currentAccount = null;
      _calendarApi = null;

      debugPrint('✅ [CALENDAR] [DISCONNECT] SUCCESS');
      return CalendarDisconnectResult.success;

    } catch (e) {
      debugPrint('❌ [CALENDAR] [DISCONNECT] FAILED: $e');
      
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('socket')) {
        return CalendarDisconnectResult.networkError;
      }
      
      return CalendarDisconnectResult.backendFailed;
    }
  }

  // ============================================================================
  // LOCAL CALENDAR OPERATIONS (Optional - Backend handles sync via triggers)
  // ============================================================================

  /// Create a calendar event for a task (local operation)
  Future<String?> createTaskEvent({
    required String title,
    required String description,
    required DateTime deadline,
    String? attendeeEmail,
  }) async {
    if (_calendarApi == null) return null;

    try {
      final startTime = deadline.subtract(const Duration(hours: 1));
      final timeZone = DateTime.now().timeZoneName;

      final event = calendar.Event(
        summary: title,
        description: description,
        start: calendar.EventDateTime(dateTime: startTime.toUtc(), timeZone: timeZone),
        end: calendar.EventDateTime(dateTime: deadline.toUtc(), timeZone: timeZone),
        reminders: calendar.EventReminders(
          useDefault: false,
          overrides: [
            calendar.EventReminder(method: 'popup', minutes: 30),
            calendar.EventReminder(method: 'email', minutes: 60),
          ],
        ),
      );

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

  /// Update a calendar event (local operation)
  Future<bool> updateTaskEvent({
    required String eventId,
    String? title,
    String? description,
    DateTime? deadline,
  }) async {
    if (_calendarApi == null) return false;

    try {
      final existingEvent = await _calendarApi!.events.get('primary', eventId);

      if (title != null) existingEvent.summary = title;
      if (description != null) existingEvent.description = description;
      if (deadline != null) {
        final startTime = deadline.subtract(const Duration(hours: 1));
        final timeZone = DateTime.now().timeZoneName;
        existingEvent.start = calendar.EventDateTime(dateTime: startTime.toUtc(), timeZone: timeZone);
        existingEvent.end = calendar.EventDateTime(dateTime: deadline.toUtc(), timeZone: timeZone);
      }

      await _calendarApi!.events.update(existingEvent, 'primary', eventId);
      debugPrint('✅ Calendar: Event updated - $eventId');
      return true;
    } catch (e) {
      debugPrint('❌ Calendar: Event update failed - $e');
      return false;
    }
  }

  /// Delete a calendar event (local operation)
  Future<bool> deleteTaskEvent(String eventId) async {
    if (_calendarApi == null) return false;

    try {
      await _calendarApi!.events.delete('primary', eventId);
      debugPrint('✅ Calendar: Event deleted - $eventId');
      return true;
    } catch (e) {
      debugPrint('❌ Calendar: Event deletion failed - $e');
      return false;
    }
  }

  /// Mark event as completed (local operation)
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

// ============================================================================
// HTTP CLIENT FOR GOOGLE APIS
// ============================================================================
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
```

### 5.3: CloudFunctionsService Methods

```dart
// lib/data/services/cloud_functions_service.dart

class CloudFunctionsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<Map<String, dynamic>> exchangeCalendarAuthCode(String authCode) async {
    final callable = _functions.httpsCallable('exchangeCalendarAuthCode');
    final result = await callable.call({'authCode': authCode});
    return result.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reconnectCalendar() async {
    final callable = _functions.httpsCallable('reconnectCalendar');
    final result = await callable.call();
    return result.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> disconnectCalendar() async {
    final callable = _functions.httpsCallable('disconnectCalendar');
    final result = await callable.call();
    return result.data as Map<String, dynamic>;
  }
}
```

### 5.4: AuthRepository with Upfront Calendar Consent

> **KEY CHANGE (v2.1):** Calendar consent is now requested during the initial Google Sign-In flow, not when toggling the calendar switch in Settings. This provides a seamless experience where users only see one consent screen.

```dart
// lib/data/repositories/auth_repository.dart

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import '../../core/constants/env_config.dart';

/// Result of Google sign-in containing Firebase credential and optional serverAuthCode
typedef GoogleSignInResult = ({
  firebase_auth.UserCredential credential,
  String? serverAuthCode,
});

class AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  AuthRepository({
    firebase_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
       // CRITICAL: Include calendar scope and serverClientId for upfront consent
       _googleSignIn = googleSignIn ?? GoogleSignIn(
         scopes: ['email', calendar.CalendarApi.calendarEventsScope],
         serverClientId: EnvConfig.googleWebClientId,
       );

  /// Sign in with Google (includes calendar consent for seamless toggle experience)
  /// Returns both Firebase credential and serverAuthCode for calendar token exchange
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Capture serverAuthCode for calendar token exchange
      final serverAuthCode = googleUser.serverAuthCode;

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      return (credential: userCredential, serverAuthCode: serverAuthCode);
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  // ... other methods (signInWithApple, signOut, etc.)
}
```

### 5.5: AuthProvider with Immediate Token Exchange

```dart
// lib/data/providers/auth_provider.dart

class AuthProvider with ChangeNotifier, WidgetsBindingObserver {
  // ... existing fields ...
  
  bool _calendarVerifiedThisSession = false; // Prevent repeated verification calls

  /// Sign in with Google
  /// Calendar consent is included in sign-in flow for seamless toggle experience
  Future<void> signInWithGoogle() async {
    debugPrint('🔐 Starting Google Sign-In...');
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authRepository.signInWithGoogle();
      debugPrint('✅ Google Sign-In successful');
      
      // IMMEDIATE TOKEN EXCHANGE: Exchange serverAuthCode for calendar tokens
      // This enables seamless calendar toggle without showing account picker again
      if (result.serverAuthCode != null) {
        debugPrint('📅 Exchanging calendar auth code...');
        try {
          final cloudFunctions = CloudFunctionsService();
          await cloudFunctions.exchangeCalendarAuthCode(result.serverAuthCode!);
          debugPrint('✅ Calendar tokens exchanged and stored');
        } catch (calendarError) {
          // Non-fatal: User can still use the app, calendar toggle will retry
          debugPrint('⚠️ Calendar token exchange failed (non-fatal): $calendarError');
        }
      } else {
        debugPrint('ℹ️ No serverAuthCode received (calendar toggle will require manual consent)');
      }
      
      // Wait for user data to load
      await _waitForUserData();
    } catch (e) {
      debugPrint('❌ Google Sign-In failed: $e');
      await _authRepository.signOutGoogleOnly();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // In the user stream listener, verify calendar connection once per session:
  void _onUserDataReceived(UserModel? user) {
    // ... existing logic ...
    
    // Proactively verify calendar connection if user has it enabled
    // Only verify ONCE per session to avoid infinite loop
    if (user?.googleCalendarConnected == true && !_calendarVerifiedThisSession) {
      _calendarVerifiedThisSession = true;
      CalendarService().verifyConnectionStatus().then((isValid) {
        if (!isValid) {
          debugPrint('⚠️ Calendar connection was invalidated');
          // Backend already set googleCalendarConnected = false
        }
      });
    }
  }

  void _clearUser() {
    _calendarVerifiedThisSession = false;  // Reset for next login
    CalendarService().reset();  // Clear calendar state
    // ... rest of cleanup
  }
}
```

### 5.6: UI Handler (Settings Screen)

```dart
// Handle all CalendarConnectResult cases

switch (result) {
  case CalendarConnectResult.success:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calendar connected successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    break;

  case CalendarConnectResult.userCancelled:
    // User cancelled - no snackbar needed
    debugPrint('📅 Calendar connection cancelled by user');
    break;

  case CalendarConnectResult.networkError:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Network error. Please check your connection.'),
        backgroundColor: Colors.orange,
      ),
    );
    break;

  case CalendarConnectResult.signInFailed:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google sign-in failed. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
    break;

  case CalendarConnectResult.noServerAuthCode:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuration error. Please contact support.'),
        backgroundColor: Colors.red,
      ),
    );
    break;

  case CalendarConnectResult.verificationFailed:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calendar verification failed. Please ensure you granted permissions.'),
        backgroundColor: Colors.red,
      ),
    );
    break;

  case CalendarConnectResult.backendExchangeFailed:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to connect calendar. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
    break;

  case CalendarConnectResult.accessRevoked:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calendar access was revoked. Please logout and login again to reconnect.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 5),
      ),
    );
    break;

  case CalendarConnectResult.unknownError:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('An unexpected error occurred. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
    break;
}
```

---

## 6. User Flows

> **KEY CHANGE (v2.1):** Calendar consent is now obtained during the initial Google Sign-In, not when toggling the calendar switch. This creates a seamless experience.

### Flow 0: First Time Login with Calendar Consent (NEW)
1. User taps "Sign in with Google" on login screen
2. Google consent screen shows **including calendar permission** (due to `calendarEventsScope` in AuthRepository)
3. User grants all permissions
4. `signInWithGoogle()` returns `serverAuthCode`
5. **Immediately** exchanges `serverAuthCode` via `exchangeCalendarAuthCode()` Cloud Function
6. Backend stores access token + refresh token
7. User enters app (calendar tokens stored but `googleCalendarConnected = false`)

> **Note:** Users have granted calendar consent but haven't explicitly enabled sync. Toggling the calendar switch in Settings will now work instantly without showing any dialog.

### Flow 1: Toggle Calendar ON (After Login)
1. User goes to Settings → Calendar toggle is OFF
2. User toggles switch ON
3. `CalendarService.connect()` is called
4. **Smart Reconnect:** `reconnectCalendar()` checks for stored tokens
   - If tokens exist and are valid → **SUCCESS immediately!** (No dialog)
   - If tokens don't exist or are invalid → Continue to full flow
5. `signInSilently()` attempts silent session restoration
6. If no session, `signIn()` shows consent screen
7. Exchange `serverAuthCode` with backend
8. Backend sets `googleCalendarConnected = true`
9. UI shows "Connected" ✓

### Flow 2: Smart Reconnect (Returning User)
1. User previously connected calendar and logged out
2. User logs back in
3. `verifyConnectionStatus()` is called on user data load
4. Backend validates stored refresh token
5. If valid → `googleCalendarConnected` remains true
6. User sees calendar already connected in Settings

### Flow 3: Reconnect After Token Expiry
1. User has calendar connected
2. Access token expires (after 1 hour)
3. User or backend attempts calendar operation
4. Backend uses `oauth2Client.on('tokens')` listener
5. New access token is automatically saved to Firestore
6. Operation succeeds - **User notices nothing!**

### Flow 4: Reconnect After Access Revoked
1. User revokes access in [Google Account Settings](https://myaccount.google.com/permissions)
2. User tries to toggle calendar switch ON
3. `reconnectCalendar()` returns `requiresReauth: true`
4. On iOS: `disconnect()` clears stale session first
5. `signIn()` shows consent screen (fresh credentials needed)
6. If user completes consent → Works!
7. If user cancels → Show "Please logout and login again" message

### Flow 5: Disconnect Calendar
1. User toggles calendar switch OFF
2. `CalendarService.disconnect()` is called
3. Backend Cloud Function:
   - Deletes all calendar events for user's tasks
   - Sets `googleCalendarConnected = false`
   - **Preserves tokens** for easy reconnect later
4. UI shows "Disconnected"

### Flow 6: Account Deletion Cleanup
1. User initiates account deletion
2. `deleteAllUserCalendarEvents()` is called
3. All calendar events associated with user's tasks are deleted
4. User document is deleted (including tokens)
5. Firebase Auth account is deleted

---

## 7. Platform-Specific Considerations

> **CRITICAL:** iOS and Android behave differently with Google Sign-In and serverAuthCode retrieval. The CalendarService has platform-specific code to handle these differences.

### iOS Behavior

| Behavior | iOS | Android |
|----------|-----|---------|
| `signInSilently()` returns `serverAuthCode` | ❌ Never | ✅ Yes |
| Cached session interferes with fresh consent | ✅ Yes | ❌ No |
| `disconnect()` required before reauth | ✅ Yes | ❌ No |

### iOS-Specific Code Patterns

```dart
// 1. iOS requires disconnect() when requiresReauth is true
if (Platform.isIOS && requiresReauth) {
  await _googleSignIn.disconnect();
}

// 2. iOS signInSilently() never returns serverAuthCode - must force signIn()
if (account != null && account.serverAuthCode == null) {
  account = await _googleSignIn.signIn();
}

// 3. iOS fallback: disconnect and retry if still no serverAuthCode
if (Platform.isIOS && account != null && account.serverAuthCode == null) {
  await _googleSignIn.disconnect();
  account = await _googleSignIn.signIn();
}
```

### Why iOS Behaves Differently

1. **iOS keychain caching:** iOS aggressively caches Google session in the secure keychain. When access is revoked externally, the cache becomes stale.

2. **No incremental scopes on iOS:** Android's Google Sign-In SDK supports incremental authorization. iOS does not - it requires a full new sign-in to get serverAuthCode after initial consent.

3. **signInSilently limitation:** iOS's `signInSilently()` restores the *session* but not the *authorization code*. This is by design - auth codes are one-time use.

### Testing Platform-Specific Flows

**iOS Testing:**
1. Sign in → Calendar connected
2. Revoke access at [myaccount.google.com/permissions](https://myaccount.google.com/permissions)
3. Kill app completely
4. Reopen app → Toggle calendar switch
5. **Expected:** Consent screen appears (not error)

**Android Testing:**
Same as above, but `signInSilently()` may return serverAuthCode directly without showing consent screen (if app is still authorized).

---

## 8. Edge Case Handling

| Edge Case | Detection | Resolution |
|-----------|-----------|------------|
| Stale auth code | Backend returns "expired or already used" | `clearStaleSession()` + show logout message |
| Token revoked (active) | 401/invalid_grant during operation | `handleCalendarAuthError()` resets connection |
| Token revoked (passive) | `verifyConnectionStatus()` on login | Backend updates Firestore |
| Infinite verification loop | N/A | `_calendarVerifiedThisSession` flag |
| Dormant user (6+ months) | Monthly `maintainCalendarTokens` job | Proactively refreshes or clears tokens |
| Account deletion | User deletes account | Call `deleteAllUserCalendarEvents()` before deletion |
| Multi-assignee tasks | Task has multiple assignees | Each assignee gets own event, stored in `assignments` subcollection |
| iOS no serverAuthCode | `signInSilently()` returns account without code | Force `signIn()`, retry with `disconnect()` if still null |
| iOS cached stale session | `requiresReauth=true` from backend | `disconnect()` before attempting consent |
| Network timeout | CloudFunction exceeds 60s | `CloudFunctionTimeoutException` handling |

---

## 9. Testing Checklist

### Upfront Consent (v2.1)
- [ ] First Google Sign-In shows calendar permission in consent screen
- [ ] After sign-in, calendar tokens are exchanged in background
- [ ] Calendar toggle works instantly (no dialog) after login

### Happy Path
- [ ] First time connect shows consent, then works
- [ ] Disconnect removes events and updates UI
- [ ] Logout/login preserves connection status
- [ ] Task creation creates ONE calendar event
- [ ] Smart reconnect works (no dialog for returning users)

### Edge Cases
- [ ] Revoke while using app → shows "logout and login" message
- [ ] After logout/login following revocation → consent screen appears
- [ ] Revoke while logged out → auto-detects on next login
- [ ] No infinite loops in logs

### iOS-Specific
- [ ] iOS: Toggle calendar after fresh login → works without dialog
- [ ] iOS: Revoke access → retry shows consent screen (not error)
- [ ] iOS: `signInSilently()` fallback to `signIn()` works
- [ ] iOS: Multiple retry attempts don't cause issues

### Android-Specific
- [ ] Android: `signInSilently()` returns serverAuthCode when authorized
- [ ] Android: Incremental scope authorization works

---

## 10. Troubleshooting

### Error: "Auth code expired or already used"
**Cause:** The `serverAuthCode` from GoogleSignIn was already exchanged once.
**Fix:** Call `clearStaleSession()` and have user logout/login.

### Error: "No refresh token received"
**Cause:** User has previously granted consent. Google only sends refresh token on FIRST consent.
**Fix:** This is normal if you already have a refresh token stored.

### Error: "OAuth credentials not configured"
**Cause:** `.env` file not loaded or missing variables.
**Fix:** Check `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set.

### Calendar shows "Connected" but events don't sync
**Cause:** Tokens are invalid but flag wasn't reset.
**Fix:** The `verifyCalendarAccess()` function should prevent this. Check it's being called.

### iOS: "Configuration Error" when toggling calendar
**Cause:** `serverAuthCode` is null because iOS `signInSilently()` doesn't return it.
**Fix:** The v2.1 code has fallback logic. Ensure you're using the latest CalendarService with Platform.isIOS checks.

### iOS: Calendar toggle shows Google consent even after login
**Cause:** Token exchange during login failed silently.
**Fix:** Check AuthProvider logs for "Calendar token exchange failed" messages. Ensure `exchangeCalendarAuthCode()` is being called.

### iOS: Infinite "Please logout and login again" loop
**Cause:** Stale session not being cleared properly.
**Fix:** Ensure `clearStaleSession()` calls `_googleSignIn.disconnect()` (not just `signOut()`).

### Calendar sync stopped after 6 months
**Cause:** Refresh token expired (6-month Google policy for unverified apps).
**Fix:** Complete Google OAuth verification to get indefinite refresh tokens. Or run `maintainCalendarTokens` job more frequently.

### "No serverAuthCode" error on Android
**Cause:** `serverClientId` not configured correctly in GoogleSignIn.
**Fix:** Verify `EnvConfig.googleWebClientId` matches the Web Client ID from Google Cloud Console (not Android client ID).
