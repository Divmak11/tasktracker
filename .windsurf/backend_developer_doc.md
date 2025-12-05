# Backend Developer Documentation
**TODO Planner & Task Management - Firebase + Cloud Functions**

## Architecture Overview

**Stack:**
- **Authentication**: Firebase Auth (Email/Password)
- **Database**: Cloud Firestore
- **Functions**: Firebase Cloud Functions (Node.js/TypeScript)
- **Notifications**: Firebase Cloud Messaging (FCM)
- **Storage**: Cloud Storage (for report exports)
- **Email**: Firebase Extensions (Trigger Email) or SendGrid

**Environments:**
- **Dev**: Development project for testing
- **Prod**: Production project

---

## Firebase Project Setup

### 1. Create Projects

```bash
# Install Firebase CLI
npm install -g firebase-tools
firebase login

# Create Dev project via Firebase Console, then:
firebase projects:list
firebase use --add  # Select dev project, alias: "dev"

# Repeat for Prod project, alias: "prod"
```

### 2. Initialize Functions

```bash
firebase init functions
# Select TypeScript
# Enable ESLint
```

**Project structure:**
```
functions/
├── src/
│   ├── config/
│   │   └── firebase-admin.ts
│   ├── controllers/
│   │   ├── authController.ts
│   │   ├── taskController.ts
│   │   └── calendarController.ts
│   ├── services/
│   │   ├── notificationService.ts
│   │   ├── calendarService.ts
│   │   └── emailService.ts
│   ├── triggers/
│   │   └── authTriggers.ts
│   ├── utils/
│   │   └── validators.ts
│   └── index.ts
├── package.json
└── tsconfig.json
```

### 3. Install Dependencies

```bash
cd functions
npm install firebase-admin firebase-functions
npm install googleapis nodemailer
npm install @sendgrid/mail  # If using SendGrid
```

---

## Firestore Data Model

### Collections Schema

#### **users**
```typescript
{
  id: string;              // Auto-generated doc ID
  name: string;
  email: string;
  role: 'super_admin' | 'team_admin' | 'member';
  teamIds: string[];       // Array of team IDs user belongs to
  status: 'pending' | 'active' | 'revoked';
  googleCalendarConnected: boolean;
  googleAccessToken?: string;
  googleRefreshToken?: string;
  fcmToken?: string;
  createdAt: Timestamp;
  lastActive: Timestamp;
}
```

#### **teams**
```typescript
{
  id: string;
  name: string;
  adminId: string;         // Single Team Admin user ID
  memberIds: string[];     // Array of member user IDs
  createdBy: string;       // Super Admin who created it
  createdAt: Timestamp;
}
```

#### **tasks**
```typescript
{
  id: string;
  title: string;
  subtitle: string;
  assignedType: 'member' | 'team';
  assignedTo: string;      // userId or teamId
  createdBy: string;       // userId who created the task
  status: 'ongoing' | 'completed' | 'cancelled';
  deadline: Timestamp;
  calendarEventId?: string;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}
```

**Note:** When `assignedType = 'team'`, a separate **task document is created for each team member** with individual `assignedTo = memberId`.

#### **remarks**
```typescript
{
  id: string;
  taskId: string;
  userId: string;          // Who wrote the remark
  message: string;
  createdAt: Timestamp;
}
```

#### **approvalRequests**
```typescript
{
  id: string;
  type: 'reschedule' | 'user_access';
  requesterId: string;     // User requesting
  targetId: string;        // taskId (for reschedule) or userId (for access)
  payload: {
    newDeadline?: Timestamp;
    reason?: string;
  };
  status: 'pending' | 'approved' | 'rejected';
  approverId?: string;     // Who approved/rejected
  createdAt: Timestamp;
  resolvedAt?: Timestamp;
}
```

#### **rescheduleLog**
```typescript
{
  id: string;
  taskId: string;
  requestedBy: string;      // Member who requested
  originalDeadline: Timestamp;
  newDeadline: Timestamp;
  approvedBy: string;       // Task creator who approved
  createdAt: Timestamp;
}
```

---

## Cloud Functions

### 1. Auth Trigger - Create User Profile

**`src/triggers/authTriggers.ts`**
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const createUserProfile = functions.auth.user().onCreate(async (user) => {
  const superAdminEmail = functions.config().app.super_admin_email;
  
  const role = user.email === superAdminEmail ? 'super_admin' : 'member';
  const status = user.email === superAdminEmail ? 'active' : 'pending';
  
  await admin.firestore().collection('users').doc(user.uid).set({
    name: user.displayName || user.email?.split('@')[0] || 'User',
    email: user.email,
    role,
    teamIds: [],
    status,
    googleCalendarConnected: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    lastActive: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // If pending, create approval request
  if (status === 'pending') {
    await admin.firestore().collection('approvalRequests').add({
      type: 'user_access',
      requesterId: user.uid,
      targetId: user.uid,
      payload: { email: user.email },
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Notify Super Admin
    await notifySuperAdmin('New user access request', user.email);
  }
});
```

### 2. Assign Task Function

**`src/controllers/taskController.ts`**
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { createCalendarEvent } from '../services/calendarService';
import { sendNotification } from '../services/notificationService';

export const assignTask = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  
  const { title, subtitle, assignedType, assignedTo, deadline } = data;
  const createdBy = context.auth.uid;
  
  // Validation
  if (!title || !deadline) {
    throw new functions.https.HttpsError('invalid-argument', 'Title and deadline required');
  }
  
  const db = admin.firestore();
  const deadlineTimestamp = admin.firestore.Timestamp.fromDate(new Date(deadline));
  
  // If assigning to team, create individual tasks for each member
  if (assignedType === 'team') {
    const teamDoc = await db.collection('teams').doc(assignedTo).get();
    if (!teamDoc.exists) throw new functions.https.HttpsError('not-found', 'Team not found');
    
    const team = teamDoc.data()!;
    const memberIds = team.memberIds;
    
    const batch = db.batch();
    
    for (const memberId of memberIds) {
      const taskRef = db.collection('tasks').doc();
      batch.set(taskRef, {
        title,
        subtitle,
        assignedType: 'member',
        assignedTo: memberId,
        createdBy,
        status: 'ongoing',
        deadline: deadlineTimestamp,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Schedule calendar event creation
      const taskId = taskRef.id;
      await createCalendarEventForUser(memberId, taskId, title, subtitle, deadline);
      
      // Send notification
      await sendNotification(memberId, 'New Task Assigned', `${title} - Due ${new Date(deadline).toLocaleDateString()}`);
    }
    
    await batch.commit();
  } else {
    // Single member assignment
    const taskRef = await db.collection('tasks').add({
      title,
      subtitle,
      assignedType: 'member',
      assignedTo,
      createdBy,
      status: 'ongoing',
      deadline: deadlineTimestamp,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    await createCalendarEventForUser(assignedTo, taskRef.id, title, subtitle, deadline);
    await sendNotification(assignedTo, 'New Task Assigned', `${title}`);
  }
  
  return { success: true };
});
```

### 3. Request Reschedule Function

**`src/controllers/taskController.ts`**
```typescript
export const requestReschedule = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  
  const { taskId, newDeadline, reason } = data;
  const requesterId = context.auth.uid;
  
  const db = admin.firestore();
  const taskDoc = await db.collection('tasks').doc(taskId).get();
  if (!taskDoc.exists) throw new functions.https.HttpsError('not-found', 'Task not found');
  
  const task = taskDoc.data()!;
  
  // Create approval request
  await db.collection('approvalRequests').add({
    type: 'reschedule',
    requesterId,
    targetId: taskId,
    payload: {
      newDeadline: admin.firestore.Timestamp.fromDate(new Date(newDeadline)),
      originalDeadline: task.deadline,
      reason,
    },
    status: 'pending',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Notify task creator (who can approve)
  await sendNotification(task.createdBy, 'Reschedule Request', `${task.title} - Requested by assignee`);
  
  return { success: true };
});
```

### 4. Approve Reschedule Function

**`src/controllers/taskController.ts`**
```typescript
export const approveReschedule = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  
  const { requestId, approved } = data;
  const approverId = context.auth.uid;
  
  const db = admin.firestore();
  const requestDoc = await db.collection('approvalRequests').doc(requestId).get();
  if (!requestDoc.exists) throw new functions.https.HttpsError('not-found', 'Request not found');
  
  const request = requestDoc.data()!;
  const taskId = request.targetId;
  
  // Update request status
  await db.collection('approvalRequests').doc(requestId).update({
    status: approved ? 'approved' : 'rejected',
    approverId,
    resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  if (approved) {
    const newDeadline = request.payload.newDeadline;
    
    // Update task deadline
    await db.collection('tasks').doc(taskId).update({
      deadline: newDeadline,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Log reschedule
    await db.collection('rescheduleLog').add({
      taskId,
      requestedBy: request.requesterId,
      originalDeadline: request.payload.originalDeadline,
      newDeadline,
      approvedBy: approverId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Update Google Calendar event
    const taskDoc = await db.collection('tasks').doc(taskId).get();
    const task = taskDoc.data()!;
    if (task.calendarEventId) {
      await updateCalendarEvent(task.assignedTo, task.calendarEventId, newDeadline);
    }
    
    // Notify requester
    await sendNotification(request.requesterId, 'Reschedule Approved', `New deadline: ${newDeadline.toDate().toLocaleDateString()}`);
  }
  
  return { success: true };
});
```

### 5. Google Calendar Integration

**`src/services/calendarService.ts`**
```typescript
import { google } from 'googleapis';
import * as admin from 'firebase-admin';

async function createCalendarEventForUser(userId: string, taskId: string, title: string, subtitle: string, deadline: string) {
  const db = admin.firestore();
  const userDoc = await db.collection('users').doc(userId).get();
  const user = userDoc.data()!;
  
  if (!user.googleCalendarConnected) {
    // Send notification to connect calendar
    await sendNotification(userId, 'Connect Calendar', 'To sync tasks, connect your Google Calendar in Settings');
    return;
  }
  
  const oauth2Client = new google.auth.OAuth2();
  oauth2Client.setCredentials({
    access_token: user.googleAccessToken,
    refresh_token: user.googleRefreshToken,
  });
  
  const calendar = google.calendar({ version: 'v3', auth: oauth2Client });
  
  try {
    const event = await calendar.events.insert({
      calendarId: 'primary',
      requestBody: {
        summary: title,
        description: subtitle,
        start: { dateTime: new Date(deadline).toISOString() },
        end: { dateTime: new Date(new Date(deadline).getTime() + 60 * 60 * 1000).toISOString() }, // +1 hour
      },
    });
    
    // Save event ID to task
    await db.collection('tasks').doc(taskId).update({
      calendarEventId: event.data.id,
    });
  } catch (error) {
    console.error('Calendar event creation failed:', error);
  }
}

async function updateCalendarEvent(userId: string, eventId: string, newDeadline: admin.firestore.Timestamp) {
  const db = admin.firestore();
  const userDoc = await db.collection('users').doc(userId).get();
  const user = userDoc.data()!;
  
  if (!user.googleCalendarConnected) return;
  
  const oauth2Client = new google.auth.OAuth2();
  oauth2Client.setCredentials({
    access_token: user.googleAccessToken,
    refresh_token: user.googleRefreshToken,
  });
  
  const calendar = google.calendar({ version: 'v3', auth: oauth2Client });
  
  try {
    await calendar.events.patch({
      calendarId: 'primary',
      eventId,
      requestBody: {
        start: { dateTime: newDeadline.toDate().toISOString() },
        end: { dateTime: new Date(newDeadline.toDate().getTime() + 60 * 60 * 1000).toISOString() },
      },
    });
  } catch (error) {
    console.error('Calendar event update failed:', error);
  }
}

export const disconnectCalendar = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  
  const userId = context.auth.uid;
  const db = admin.firestore();
  
  // Get all user's tasks with calendar events
  const tasksSnapshot = await db.collection('tasks')
    .where('assignedTo', '==', userId)
    .where('calendarEventId', '!=', null)
    .get();
  
  const userDoc = await db.collection('users').doc(userId).get();
  const user = userDoc.data()!;
  
  if (user.googleAccessToken) {
    const oauth2Client = new google.auth.OAuth2();
    oauth2Client.setCredentials({
      access_token: user.googleAccessToken,
      refresh_token: user.googleRefreshToken,
    });
    
    const calendar = google.calendar({ version: 'v3', auth: oauth2Client });
    
    // Delete all calendar events
    for (const taskDoc of tasksSnapshot.docs) {
      const task = taskDoc.data();
      try {
        await calendar.events.delete({ calendarId: 'primary', eventId: task.calendarEventId! });
      } catch (error) {
        console.error('Failed to delete event:', error);
      }
    }
  }
  
  // Update user record
  await db.collection('users').doc(userId).update({
    googleCalendarConnected: false,
    googleAccessToken: admin.firestore.FieldValue.delete(),
    googleRefreshToken: admin.firestore.FieldValue.delete(),
  });
  
  return { success: true };
});
```

### 6. Notification Service

**`src/services/notificationService.ts`**
```typescript
import * as admin from 'firebase-admin';

export async function sendNotification(userId: string, title: string, body: string, data?: object) {
  const db = admin.firestore();
  const userDoc = await db.collection('users').doc(userId).get();
  const user = userDoc.data();
  
  if (!user || !user.fcmToken) return;
  
  await admin.messaging().send({
    token: user.fcmToken,
    notification: { title, body },
    data: { ...data, clickAction: 'FLUTTER_NOTIFICATION_CLICK' },
  });
}
```

### 7. Scheduled Deadline Reminders

**`src/triggers/scheduledFunctions.ts`**
```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

// Run every hour
export const checkDeadlines = functions.pubsub.schedule('every 1 hours').onRun(async () => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const oneDayLater = new Date(now.toMillis() + 24 * 60 * 60 * 1000);
  const sixHoursLater = new Date(now.toMillis() + 6 * 60 * 60 * 1000);
  
  // 1-day reminder
  const tasksIn24h = await db.collection('tasks')
    .where('status', '==', 'ongoing')
    .where('deadline', '>=', admin.firestore.Timestamp.fromDate(oneDayLater))
    .where('deadline', '<', admin.firestore.Timestamp.fromDate(new Date(oneDayLater.getTime() + 60 * 60 * 1000)))
    .get();
  
  for (const doc of tasksIn24h.docs) {
    const task = doc.data();
    await sendNotification(task.assignedTo, 'Task Reminder', `${task.title} is due in 24 hours`);
    await sendNotification(task.createdBy, 'Task Reminder', `Assigned task "${task.title}" is due in 24 hours`);
  }
  
  // 6-hour reminder (similar logic)
  // ... 
  
  // Overdue notifications
  const overdueTasks = await db.collection('tasks')
    .where('status', '==', 'ongoing')
    .where('deadline', '<', now)
    .get();
  
  for (const doc of overdueTasks.docs) {
    const task = doc.data();
    await sendNotification(task.assignedTo, 'Task Overdue', `${task.title} is overdue!`);
    await sendNotification(task.createdBy, 'Task Overdue', `Assigned task "${task.title}" is overdue`);
    
    // Notify Super Admin
    const superAdmins = await db.collection('users').where('role', '==', 'super_admin').get();
    for (const adminDoc of superAdmins.docs) {
      await sendNotification(adminDoc.id, 'Overdue Task Alert', `Task "${task.title}" is overdue`);
    }
  }
});
```

---

---

## Callable Functions Specifications (Frontend Requirements)

These functions are required by the frontend to perform privileged operations securely.

### 1. Approve User Access
**Function Name**: `approveUserAccess`
**Type**: Callable
**Auth Required**: Yes (Super Admin only)

**Input (Request Data)**:
```json
{
  "userId": "string (UID of the user to approve/reject)",
  "approved": "boolean (true for active, false for revoked)"
}
```

**Output (Response)**:
```json
{
  "success": "boolean",
  "message": "string (optional)"
}
```

**Logic**:
1. Verify caller is Super Admin.
2. Update `users/{userId}`:
   - If `approved` is true: set `status` to `'active'`, `approvedBy` to caller ID, `approvedAt` to server timestamp.
   - If `approved` is false: set `status` to `'revoked'`, `rejectedBy` to caller ID, `rejectedAt` to server timestamp.
3. Trigger email/push notification (handled by triggers).

### 2. Update User Role
**Function Name**: `updateUserRole`
**Type**: Callable
**Auth Required**: Yes (Super Admin only)

**Input (Request Data)**:
```json
{
  "userId": "string (UID of the user)",
  "newRole": "string ('superAdmin' | 'teamAdmin' | 'member')"
}
```

**Output (Response)**:
```json
{
  "success": "boolean"
}
```

**Logic**:
1. Verify caller is Super Admin.
2. Update `users/{userId}`:
   - Set `role` to `newRole`.
   - Set `roleChangedBy` to caller ID.
   - Set `roleChangedAt` to server timestamp.

### 3. Create Team
**Function Name**: `createTeam`
**Type**: Callable
**Auth Required**: Yes (Super Admin or Team Admin)

**Input (Request Data)**:
```json
{
  "name": "string (Team name)",
  "memberIds": "string[] (List of user UIDs to add)",
  "adminId": "string (UID of the team admin)"
}
```

**Output (Response)**:
```json
{
  "teamId": "string (ID of the created team)"
}
```

**Logic**:
1. Verify caller has permission (Super Admin or Team Admin).
2. Create document in `teams` collection.
3. Update `users` collection for all members (add team ID to `teamIds` array).

---

## Firestore Security Rules

**`firestore.rules`**
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isSuperAdmin() {
      return isAuthenticated() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'super_admin';
    }
    
    function isApproved() {
      return isAuthenticated() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.status == 'active';
    }
    
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && request.auth.uid == userId;
      allow update: if isAuthenticated() && (request.auth.uid == userId || isSuperAdmin());
      allow delete: if isSuperAdmin();
    }
    
    match /teams/{teamId} {
      allow read: if isApproved();
      allow create, update, delete: if isSuperAdmin();
    }
    
    match /tasks/{taskId} {
      allow read: if isApproved();
      allow create: if isApproved();
      allow update: if isApproved() && (resource.data.assignedTo == request.auth.uid || resource.data.createdBy == request.auth.uid || isSuperAdmin());
      allow delete: if isSuperAdmin();
    }
    
    match /remarks/{remarkId} {
      allow read: if isApproved();
      allow create: if isApproved();
      allow update, delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
    }
    
    match /approvalRequests/{requestId} {
      allow read: if isApproved();
      allow create: if isApproved();
      allow update: if isSuperAdmin() || isApproved();
    }
  }
}

---

## Push Notification Functions (REQUIRED)

These functions are critical for sending push notifications when the app is closed.

### 1. Notify Admin of New User
**Trigger**: `onCreate` of `users/{userId}`
**Purpose**: Send push notification to all Super Admins when a new user signs up.

```typescript
// functions/src/triggers/notificationTriggers.ts

export const notifyAdminNewUser = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const newUser = snap.data();
    
    // Only notify for pending users
    if (newUser.status !== 'pending') return;

    // Get all super admins
    const adminsSnapshot = await admin.firestore()
      .collection('users')
      .where('role', '==', 'superAdmin')
      .get();

    const tokens: string[] = [];
    adminsSnapshot.forEach(doc => {
      const token = doc.data().fcmToken;
      if (token) tokens.push(token);
    });

    if (tokens.length === 0) return;

    // Send multicast message
    await admin.messaging().sendMulticast({
      tokens,
      notification: {
        title: 'New Approval Request',
        body: `${newUser.email} is waiting for approval`,
      },
      data: {
        type: 'new_pending_user',
        userId: context.params.userId,
      },
    });
  });
```

### 2. Notify User of Approval
**Trigger**: `onUpdate` of `users/{userId}`
**Purpose**: Send push notification to user when their status changes to 'active'.

```typescript
// functions/src/triggers/notificationTriggers.ts

export const notifyUserApproval = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Check if status changed from pending to active
    if (before.status === 'pending' && after.status === 'active') {
      const token = after.fcmToken;
      if (!token) return;

      await admin.messaging().send({
        token,
        notification: {
          title: 'Access Approved! 🎉',
          body: 'Your account has been approved. Welcome to the team!',
        },
        data: {
          type: 'approval_granted',
        },
      });
    }
  });
```

### 3. Notify User of Rejection
**Trigger**: `onUpdate` of `users/{userId}`
**Purpose**: Send push notification to user when their status changes to 'revoked'.

```typescript
// functions/src/triggers/notificationTriggers.ts

export const notifyUserRejection = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Check if status changed from pending to revoked
    if (before.status === 'pending' && after.status === 'revoked') {
      const token = after.fcmToken;
      if (!token) return;

      await admin.messaging().send({
        token,
        notification: {
          title: 'Access Request Update',
          body: 'Your access request has been declined. Please contact support.',
        },
        data: {
          type: 'approval_rejected',
        },
      });
    }
  });
```

---

## Next Steps & Implementation Plan

### Phase 1: Super Admin Module

**Frontend Status**: ✅ **COMPLETED**
- [x] Super Admin auto-approval implemented
- [x] Approval Queue with real Firestore data
- [x] In-App Notifications
- [x] User Management Screen with role management

**Backend Functions Required**:

#### 1. User Approval/Rejection Functions (CRITICAL)

**Function: `approveUserAccess`**  
**Type**: Callable HTTPS Function  
**Purpose**: Approve pending user and grant access  
**Priority**: **CRITICAL**  

```typescript
// functions/src/user/approveUserAccess.ts

export const approveUserAccess = functions.https.onCall(async (data, context) => {
  // Verify caller is Super Admin
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only Super Admin can approve users');
  }

  const { userId } = data;
  const db = admin.firestore();

  try {
    // Update user status to 'active'
    await db.collection('users').doc(userId).update({
      status: 'active',
      activatedAt: admin.firestore.FieldValue.serverTimestamp(),
      activatedBy: context.auth.uid,
    });

    // Get user details for notification
    const userDoc = await db.collection('users').doc(userId).get();
    const user = userDoc.data();

    // Send FCM notification to user
    if (user && user.fcmToken) {
      await admin.messaging().send({
        token: user.fcmToken,
        notification: {
          title: 'Access Approved!',
          body: 'Your account has been approved. You can now access the app.',
        },
        data: {
          type: 'user_approved',
          userId: userId,
        },
      });
    }

    return { success: true, message: 'User approved successfully' };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

**Frontend Integration**:
```dart
// UserRepository - Replace direct Firestore with this
Future<void> approveUser(String userId) async {
  final callable = FirebaseFunctions.instance.httpsCallable('approveUserAccess');
  await callable.call({'userId': userId});
}
```

---

**Function: `rejectUserAccess`**  
**Type**: Callable HTTPS Function  
**Purpose**: Reject pending user request  
**Priority**: HIGH  

```typescript
export const rejectUserAccess = functions.https.onCall(async (data, context) => {
  // Verify caller is Super Admin
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only Super Admin can reject users');
  }

  const { userId, reason } = data;
  const db = admin.firestore();

  try {
    // Delete user document (or set status to 'rejected')
    await db.collection('users').doc(userId).delete();

    // Optionally notify user via email about rejection
    // await sendRejectionEmail(userEmail, reason);

    return { success: true, message: 'User rejected successfully' };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

#### 2. Role Management Functions (CRITICAL)

**Function: `updateUserRole`**  
**Type**: Callable HTTPS Function  
**Purpose**: Change user's role (Member/Team Admin/Super Admin)  
**Priority**: **CRITICAL**  

```typescript
export const updateUserRole = functions.https.onCall(async (data, context) => {
  // Verify caller is Super Admin
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only Super Admin can change roles');
  }

  const { userId, newRole } = data;
  const validRoles = ['member', 'team_admin', 'super_admin'];

  if (!validRoles.includes(newRole)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid role specified');
  }

  const db = admin.firestore();

  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const oldRole = userDoc.data()!.role;

    // Handle Team Admin demotion
    if (oldRole === 'team_admin' && newRole !== 'team_admin') {
      // Find teams where user is admin
      const teamsSnapshot = await db.collection('teams')
        .where('adminId', '==', userId)
        .get();

      // Demote or reassign admin for each team
      const batch = db.batch();
      teamsSnapshot.docs.forEach(doc => {
        // Either clear adminId or assign to another member
        batch.update(doc.ref, { adminId: null });
      });
      await batch.commit();
    }

    // Update user role
    await db.collection('users').doc(userId).update({
      role: newRole,
      roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      roleUpdatedBy: context.auth.uid,
    });

    // Update custom claims for auth
    await admin.auth().setCustomUserClaims(userId, { role: newRole });

    return { success: true, message: `Role updated to ${newRole}` };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

#### 3. User Removal Functions (HIGH Priority)

**Function: `revokeUserAccess`**  
**Type**: Callable HTTPS Function  
**Purpose**: Revoke user's access (soft delete)  
**Priority**: HIGH  

```typescript
export const revokeUserAccess = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Unauthorized');
  }

  const { userId } = data;
  const db = admin.firestore();

  try {
    // Update user status to 'revoked'
    await db.collection('users').doc(userId).update({
      status: 'revoked',
      revokedAt: admin.firestore.FieldValue.serverTimestamp(),
      revokedBy: context.auth.uid,
    });

    // Disable Firebase Auth account
    await admin.auth().updateUser(userId, { disabled: true });

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

**Function: `deleteUser`**  
**Type**: Callable HTTPS Function  
**Purpose**: Permanently delete user and cleanup related data  
**Priority**: MEDIUM  

```typescript
export const deleteUser = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Unauthorized');
  }

  const { userId } = data;
  const db = admin.firestore();

  try {
    const batch = db.batch();

    // 1. Cancel all ongoing tasks assigned to user
    const assignedTasks = await db.collection('tasks')
      .where('assignedTo', '==', userId)
      .where('status', '==', 'ongoing')
      .get();

    assignedTasks.docs.forEach(doc => {
      batch.update(doc.ref, { status: 'cancelled' });
    });

    // 2. Update task creator references (keep for audit)
    // Tasks created by deleted user should show "[Deleted User]"
    // Frontend handles this by checking if creator exists

    // 3. Remove from all teams
    const teamsSnapshot = await db.collection('teams')
      .where('memberIds', 'array-contains', userId)
      .get();

    teamsSnapshot.docs.forEach(doc => {
      const memberIds = doc.data().memberIds.filter(id => id !== userId);
      batch.update(doc.ref, { memberIds });
    });

    // 4. Delete user document
    batch.delete(db.collection('users').doc(userId));

    await batch.commit();

    // 5. Delete Firebase Auth account
    await admin.auth().deleteUser(userId);

    return { success: true, message: 'User deleted successfully' };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

### Phase 1 Summary

**Critical Functions** (Implement First):
1. ✅ `approveUserAccess` - Allow pending users to access app
2. ✅ `updateUserRole` - Change user roles with proper validation
3. ✅ `revokeUserAccess` - Disable user access

**High Priority**:
4. ✅ `rejectUserAccess` - Remove pending user requests
5. ✅ `deleteUser` - Permanent user removal with cleanup

**Frontend Migration**:
- Replace direct Firestore writes in `UserRepository` with Cloud Function calls
- Use `FirebaseFunctions.instance.httpsCallable('functionName')`


### Phase 2: Team Management
1. **Frontend**:
   - [x] Create TeamRepository (DONE)
   - [x] Create Team Screen with Firestore integration (DONE)
   - [x] Team List Screen with Firestore integration (DONE)
   - [x] Team Detail Screen with real data (DONE)
   - [x] Edit Team Screen (DONE)
   - [x] Add/Remove Member functionality (DONE)

**Frontend Status**: ✅ **COMPLETED**
- [x] Team creation, listing, detail, edit screens
- [x] Add/remove member functionality
- [x] Team admin assignment with warnings

**Backend Functions Required**:

> **Note**: Frontend currently uses direct Firestore for team CRUD. Cloud Functions below provide business logic validation, notifications, and proper member management.

#### 1. Team Creation Function (HIGH Priority)

**Function: `createTeam`**  
**Type**: Callable HTTPS Function  
**Purpose**: Create team with validation and notifications  
**Priority**: HIGH  

```typescript
export const createTeam = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only Super Admin can create teams');
  }

  const { name, memberIds, adminId } = data;
  const db = admin.firestore();

  try {
    // Validate team admin is in members list
    if (!memberIds.includes(adminId)) {
      throw new functions.https.HttpsError('invalid-argument', 'Admin must be in members list');
    }

    // Create team
    const teamRef = await db.collection('teams').add({
      name,
      memberIds,
      adminId,
      createdBy: context.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Update all members' teamIds array
    const batch = db.batch();
    memberIds.forEach(userId => {
      batch.update(db.collection('users').doc(userId), {
        teamIds: admin.firestore.FieldValue.arrayUnion(teamRef.id),
      });
    });
    await batch.commit();

    // Send notifications to all members
    const memberDocs = await db.collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', memberIds)
      .get();

    const tokens = [];
    memberDocs.forEach(doc => {
      const token = doc.data().fcmToken;
      if (token) tokens.push(token);
    });

    if (tokens.length > 0) {
      await admin.messaging().sendMulticast({
        tokens,
        notification: {
          title: 'Added to Team',
          body: `You've been added to ${name}`,
        },
        data: { type: 'team_created', teamId: teamRef.id },
      });
    }

    return { success: true, teamId: teamRef.id };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

#### 2. Team Update Functions (MEDIUM Priority)

**Function: `updateTeam`**  
**Type**: Callable HTTPS Function  
**Purpose**: Update team name/members/admin  
**Priority**: MEDIUM  

```typescript
export const updateTeam = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const { teamId, updates } = data;
  const db = admin.firestore();

  try {
    const teamDoc = await db.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Team not found');
    }

    const isSuperAdmin = context.auth.token.role === 'super_admin';
    const isTeamAdmin = teamDoc.data().adminId === context.auth.uid;

    if (!(isSuperAdmin || isTeamAdmin)) {
      throw new functions.https.HttpsError('permission-denied', 'Not authorized');
    }

    await db.collection('teams').doc(teamId).update({
      ...updates,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: context.auth.uid,
    });

    return { success: true };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

#### 3. Team Deletion Function (MEDIUM Priority)

**Function: `deleteTeam`**  
**Type**: Callable HTTPS Function  
**Purpose**: Delete team and cancel all team tasks  
**Priority**: MEDIUM  

```typescript
export const deleteTeam = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Only Super Admin can delete teams');
  }

  const { teamId } = data;
  const db = admin.firestore();

  try {
    const teamDoc = await db.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Team not found');
    }

    const memberIds = teamDoc.data().memberIds;
    const batch = db.batch();

    // Cancel all ongoing team tasks
    const teamTasks = await db.collection('tasks')
      .where('assignedTo', '==', teamId)
      .where('assignedType', '==', 'team')
      .where('status', '==', 'ongoing')
      .get();

    teamTasks.docs.forEach(doc => {
      batch.update(doc.ref, { status: 'cancelled' });
    });

    // Remove team ID from all members
    memberIds.forEach(userId => {
      batch.update(db.collection('users').doc(userId), {
        teamIds: admin.firestore.FieldValue.arrayRemove(teamId),
      });
    });

    // Delete team
    batch.delete(db.collection('teams').doc(teamId));

    await batch.commit();

    return { success: true, message: 'Team deleted successfully' };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});
```

---

### Phase 2 Summary

**High Priority**:
1. ✅ `createTeam` - Create team with member notifications
2. ✅ `updateTeam` - Update team with validation
3. ✅ `deleteTeam` - Delete team and cleanup tasks

**Notification Triggers** (Optional):
- `notifyTeamCreation` - Auto-notification on team creation
- `notifyMemberAdded` - Notify new members
- `notifyAdminChanged` - Notify on admin change

**Frontend Migration**:
- Replace TeamRepository write methods with Cloud Function calls


### Phase 3: Task Management

**Frontend Status**: ✅ **COMPLETED**
- [x] TaskRepository with all CRUD operations
- [x] Create Task Screen (member/team assignment)
- [x] Task List (Ongoing/Past tabs with real-time updates)
- [x] Task Details with conditional actions
- [x] Edit Task Screen
- [x] Task Card component
- [x] Empty states and error handling

**Backend Functions Required**:

#### 1. Task Assignment Notification
**Trigger**: `onCreate` of `tasks/{taskId}`  
**Purpose**: Notify assignee when a new task is assigned  
**Priority**: HIGH  

**Implementation Notes**:
- If `assignedType === 'member'`, send notification to single user
- If `assignedType === 'team'`, send multicast notification to all team members
- Include task title, deadline, and creator name in notification
- Deep link to task detail screen

**Expected Firestore Data**:
```json
{
  "title": "Implement Authentication",
  "subtitle": "Create login and signup screens",
  "assignedType": "member",  // or "team"
  "assignedTo": "userId123",  // or "teamId456"
  "createdBy": "adminId",
  "status": "ongoing",
  "deadline": "2025-11-30T15:00:00Z",
  "createdAt": "2025-11-25T08:00:00Z"
}
```

#### 2. Task Completion Notification
**Trigger**: `onUpdate` of `tasks/{taskId}` (when status changes to 'completed')  
**Purpose**: Notify task creator when assignee completes task  
**Priority**: MEDIUM  

**Implementation Notes**:
- Only trigger when `status` field changes from 'ongoing' to 'completed'
- Send notification to `createdBy` user
- Include completion remark if provided
- Include assignee name

#### 3. Task Cancellation Notification
**Trigger**: `onUpdate` of `tasks/{taskId}` (when status changes to 'cancelled')  
**Purpose**: Notify assignee when creator/admin cancels task  
**Priority**: MEDIUM  

**Implementation Notes**:
- Only trigger when `status` changes to 'cancelled'
- Send notification to assignee(s)
- Include cancellation reason if frontend adds this field later

#### 4. Overdue Task Reminder (Scheduled)
**Trigger**: Scheduled function (runs daily at 9 AM)  
**Purpose**: Send reminders for overdue ongoing tasks  
**Priority**: LOW  

**Implementation Notes**:
- Query all tasks where `status === 'ongoing'` AND `deadline < now()`
- Group by assignee
- Send summary notification: "You have X overdue tasks"
- Include list of overdue task titles

#### 5. Calendar Event Integration (Future Enhancement)
**Trigger**: `onCreate`/`onUpdate` of `tasks/{taskId}`  
**Purpose**: Create/update Google Calendar events for tasks  
**Priority**: LOW (deferred to Module 7)  

**Implementation Notes**:
- Check if assignee has `googleCalendarConnected === true`
- Use stored refresh token to get access token
- Create calendar event with task title and deadline
- Store `calendarEventId` back to task document
- On task update, update calendar event
- On task completion/cancellation, delete calendar event

---

### Task Functions Priority Matrix

| Function | Priority | Complexity | Dependencies |
|----------|----------|------------|--------------|
| Task Assignment Notification | **HIGH** | Medium | FCM tokens |
| Task Completion Notification | MEDIUM | Low | FCM tokens |
| Task Cancellation Notification | MEDIUM | Low | FCM tokens |
| Overdue Task Reminder | LOW | Medium | Scheduled functions, FCM |
| Calendar Integration | LOW | High | Google APIs, OAuth tokens |

**Recommendation**: Implement functions 1-3 first for MVP. Defer function 4-5 to post-launch.

---

## Team Management Cloud Functions (Optional)

These functions provide push notifications for team events. The frontend already handles all team operations via direct Firestore access.

### 1. Notify Team Creation
**Trigger**: `onCreate` of `teams/{teamId}`
**Purpose**: Notify team members when they're added to a new team

```typescript
// functions/src/triggers/teamTriggers.ts

export const notifyTeamCreation = functions.firestore
  .document('teams/{teamId}')
  .onCreate(async (snap, context) => {
    const team = snap.data();
    const db = admin.firestore();
    
    // Get all team members
    const memberDocs = await db.collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', team.memberIds)
      .get();
    
    const tokens: string[] = [];
    memberDocs.forEach(doc => {
      const token = doc.data().fcmToken;
      if (token) tokens.push(token);
    });
    
    if (tokens.length === 0) return;
    
    // Send multicast notification
    await admin.messaging().sendMulticast({
      tokens,
      notification: {
        title: 'Added to Team',
        body: `You've been added to ${team.name}`,
      },
      data: {
        type: 'team_created',
        teamId: context.params.teamId,
      },
    });
  });
```

**Input** (Automatic from Firestore):
```json
{
  "name": "Development Team",
  "adminId": "userId123",
  "memberIds": ["user1", "user2", "user3"],
  "createdBy": "userId123",
  "createdAt": "2025-11-25T07:00:00Z"
}
```

**Output**: Push notifications sent to all team members

---

### 2. Notify Member Added
**Trigger**: `onUpdate` of `teams/{teamId}`
**Purpose**: Notify new members when added to existing team

```typescript
export const notifyMemberAdded = functions.firestore
  .document('teams/{teamId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Find new members (in after but not in before)
    const newMembers = after.memberIds.filter(
      (id: string) => !before.memberIds.includes(id)
    );
    
    if (newMembers.length === 0) return;
    
    const db = admin.firestore();
    
    // Get FCM tokens for new members
    const memberDocs = await db.collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', newMembers)
      .get();
    
    const tokens: string[] = [];
    memberDocs.forEach(doc => {
      const token = doc.data().fcmToken;
      if (token) tokens.push(token);
    });
    
    if (tokens.length === 0) return;
    
    await admin.messaging().sendMulticast({
      tokens,
      notification: {
        title: 'Added to Team',
        body: `You've been added to ${after.name}`,
      },
      data: {
        type: 'member_added',
        teamId: context.params.teamId,
      },
    });
  });
```

**Input** (Automatic - before/after team document):
```json
// Before update
{
  "name": "Dev Team",
  "memberIds": ["user1", "user2"]
}

// After update
{
  "name": "Dev Team",
  "memberIds": ["user1", "user2", "user3"]
}
```

**Output**: Push notification sent to "user3"

---

### 3. Notify Member Removed
**Trigger**: `onUpdate` of `teams/{teamId}`
**Purpose**: Notify members when removed from team

```typescript
export const notifyMemberRemoved = functions.firestore
  .document('teams/{teamId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Find removed members (in before but not in after)
    const removedMembers = before.memberIds.filter(
      (id: string) => !after.memberIds.includes(id)
    );
    
    if (removedMembers.length === 0) return;
    
    const db = admin.firestore();
    
    // Get FCM tokens for removed members
    const memberDocs = await db.collection('users')
      .where(admin.firestore.FieldPath.documentId(), 'in', removedMembers)
      .get();
    
    const tokens: string[] = [];
    memberDocs.forEach(doc => {
      const token = doc.data().fcmToken;
      if (token) tokens.push(token);
    });
    
    if (tokens.length === 0) return;
    
    await admin.messaging().sendMulticast({
      tokens,
      notification: {
        title: 'Removed from Team',
        body: `You've been removed from ${before.name}`,
      },
      data: {
        type: 'member_removed',
        teamId: context.params.teamId,
      },
    });
  });
```

**Input** (Automatic - before/after team document):
```json
// Before update
{
  "name": "Dev Team",
  "memberIds": ["user1", "user2", "user3"]
}

// After update
{
  "name": "Dev Team",
  "memberIds": ["user1", "user2"]
}
```

**Output**: Push notification sent to "user3"

---

---

## Email Service Setup

### Option 1: Firebase Extensions (Trigger Email)

```bash
firebase ext:install firebase/firestore-send-email
```

Configure with SMTP credentials or SendGrid API key.

### Option 2: SendGrid Direct

**`src/services/emailService.ts`**
```typescript
import sgMail from '@sendgrid/mail';

sgMail.setApiKey(functions.config().sendgrid.key);

export async function sendInviteEmail(toEmail: string, inviteLink: string) {
  const msg = {
    to: toEmail,
    from: 'noreply@yourapp.com',
    subject: 'You're invited to TODO Planner',
    html: `<p>Click <a href="${inviteLink}">here</a> to join.</p>`,
  };
  
  await sgMail.send(msg);
}
```

---

## Environment Configuration

Set environment variables:
```bash
firebase functions:config:set app.super_admin_email="admin@company.com"
firebase functions:config:set sendgrid.key="YOUR_SENDGRID_KEY"
```

---

## Deployment

```bash
# Deploy to Dev
firebase use dev
firebase deploy --only functions

# Deploy to Prod
firebase use prod
firebase deploy --only functions,firestore:rules
```

---

## Unclarified Backend Items

1. **Report PDF Generation**: Which library? (pdfkit, puppeteer?)
2. **Email Templates**: Need HTML templates for invite/notification emails
3. **Calendar Sync Frequency**: How often should we check for calendar changes? (Not implemented yet per user clarification)
4. **Error Monitoring**: Sentry, Firebase Crashlytics, or custom logging?
5. **Rate Limiting**: Should we implement rate limits on Cloud Functions?

---

## Testing

### Emulator Suite
```bash
firebase emulators:start
```

### Unit Tests (functions/src/\_\_tests\_\_)
- Test individual Cloud Functions with mock data
- Validate Firestore rules

---

## Monitoring

- **Firebase Console**: Monitor function executions, errors
- **Cloud Logging**: View structured logs
- **FCM Metrics**: Track notification delivery rates
