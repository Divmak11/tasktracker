# Production Audit - Issue Fix Plan

> **Generated**: December 13, 2025  
> **Status**: Planning Phase (No Implementation)  
> **Methodology**: Following `.agent/rules/scouting_rules.md`

This document contains detailed analysis of each solvable issue identified during the production audit, including the exact source location and recommended fix.

---

## Table of Contents

1. [Critical Issues](#critical-issues)
   - [Issue #1: Login Screen `_isLoading` Never Reset on Success](#issue-1-login-screen-_isloading-never-reset-on-success)
   - [Issue #2: Auth Persistence Race Condition](#issue-2-auth-persistence-race-condition)
2. [High Priority Issues](#high-priority-issues)
   - [Issue #3: ApprovalQueueScreen `_processingUsers` Never Populated](#issue-3-approvalqueuescreen-_processingusers-never-populated)
   - [Issue #4: UserManagementScreen Optimistic Updates Without Error Feedback](#issue-4-usermanagementscreen-optimistic-updates-without-error-feedback)
   - [Issue #5: RescheduleRequestDialog `_isSubmitting` Never Used](#issue-5-reschedulerequestdialog-_issubmitting-never-used)
   - [Issue #6: RescheduleApprovalScreen `_isProcessing` Never Used](#issue-6-rescheduleapprovalscreen-_isprocessing-never-used)
3. [Medium Priority Issues](#medium-priority-issues)
   - [Issue #7: HomeScreen Calendar Token Refresh on Every Visit](#issue-7-homescreen-calendar-token-refresh-on-every-visit)
   - [Issue #8: TaskDetailScreen N+1 Query Pattern for Remarks](#issue-8-taskdetailscreen-n1-query-pattern-for-remarks)
   - [Issue #9: ApprovalQueueScreen Empty Name Initial Crash](#issue-9-approvalqueuescreen-empty-name-initial-crash)
   - [Issue #10: Backend Super Admin Role Check Inconsistency](#issue-10-backend-super-admin-role-check-inconsistency)
4. [Low Priority / Enhancements](#low-priority--enhancements)
   - [Issue #11: ThemeProvider Initialize Without Error Handling](#issue-11-themeprovider-initialize-without-error-handling)
   - [Issue #12: Calendar Service Hardcoded Web Client ID](#issue-12-calendar-service-hardcoded-web-client-id)

---

# Critical Issues

## Issue #1: Login Screen `_isLoading` Never Reset on Success

### Description
When Google or Apple sign-in succeeds, the `_isLoading` state variable is never reset to `false`. This means if there's any delay in navigation, the button remains in a loading state indefinitely.

### Source Location
**File**: `lib/presentation/auth/login_screen.dart`  
**Lines**: 240-256 (Google), 259-276 (Apple)

### Current Code
```dart
// Lines 240-256
Future<void> _handleGoogleSignIn() async {
  setState(() => _isLoading = true);

  try {
    await context.read<AuthProvider>().signInWithGoogle();
    // Navigation is handled automatically by auth state listener in AppRouter
    // ❌ ISSUE: _isLoading is NEVER set to false on success!
  } catch (e) {
    if (mounted) {
      setState(() => _isLoading = false);  // Only reset on error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### Recommended Fix
Add `finally` block to ensure `_isLoading` is always reset:

```dart
Future<void> _handleGoogleSignIn() async {
  setState(() => _isLoading = true);

  try {
    await context.read<AuthProvider>().signInWithGoogle();
    // Navigation is handled automatically by auth state listener in AppRouter
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
```

### Files to Modify
- `lib/presentation/auth/login_screen.dart` (lines 240-256, 259-276)

---

## Issue #2: Auth Persistence Race Condition

### Description
The `signInWithGoogle` method uses a fixed 500ms delay to wait for user data to load before checking revoked status. This is a race condition - on slow networks, user data may not be loaded in time.

### Source Location
**File**: `lib/data/providers/auth_provider.dart`  
**Lines**: 143-156

### Current Code
```dart
// Lines 143-156
// Wait a moment for user data to load
await Future.delayed(const Duration(milliseconds: 500));  // ❌ Race condition!

// Check if user has revoked status
if (_currentUser?.status == UserStatus.revoked) {
  debugPrint('⚠️ User has revoked status, signing out from Google only');
  // Sign out from Google only to force account picker on next attempt
  // Keep Firebase session so router can navigate to AccessRevokedScreen
  await _authRepository.signOutGoogleOnly();
  _isLoading = false;
  notifyListeners();
  // Don't rethrow - let router handle navigation to AccessRevokedScreen
  return;
}
```

### Recommended Fix
Replace fixed delay with a proper wait mechanism using a `Completer` or listener:

```dart
Future<void> signInWithGoogle() async {
  debugPrint('🔐 Starting Google Sign-In...');
  _isLoading = true;
  notifyListeners();

  try {
    await _authRepository.signInWithGoogle();
    debugPrint('✅ Google Sign-In successful');
    
    // Wait for user data to actually load (with timeout)
    final startTime = DateTime.now();
    const maxWait = Duration(seconds: 5);
    
    while (_currentUser == null && 
           DateTime.now().difference(startTime) < maxWait) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    // Check if user has revoked status
    if (_currentUser?.status == UserStatus.revoked) {
      debugPrint('⚠️ User has revoked status, signing out from Google only');
      await _authRepository.signOutGoogleOnly();
      _isLoading = false;
      notifyListeners();
      return;
    }
  } catch (e) {
    debugPrint('❌ Google Sign-In failed: $e');
    await _authRepository.signOutGoogleOnly();
    _isLoading = false;
    notifyListeners();
    rethrow;
  }
}
```

### Alternative Fix (Using Completer)
Create a `Completer<UserModel?>` that completes when `_loadUserData` finishes, then await it instead of fixed delay.

### Files to Modify
- `lib/data/providers/auth_provider.dart` (lines 132-167)

---

# High Priority Issues

## Issue #3: ApprovalQueueScreen `_processingUsers` Never Populated

### Description
The `_processingUsers` set is declared but never populated with user IDs. This means the `isProcessing` check always returns `false`, allowing users to double-click approve/reject buttons.

### Source Location
**File**: `lib/presentation/admin/approval_queue_screen.dart`  
**Lines**: 21, 194

### Current Code
```dart
// Line 21
final Set<String> _processingUsers = {};  // ❌ Never populated!

// Line 194
final isProcessing = _processingUsers.contains(user.id);  // Always false
```

### Recommended Fix
Add the user ID to `_processingUsers` before starting the async operation and remove it after completion:

```dart
Future<void> _handleApprove(UserModel user) async {
  final confirm = await showDialog<bool>(...);

  if (confirm == true && mounted) {
    // Add to processing set
    setState(() => _processingUsers.add(user.id));
    
    NotificationService.showInAppNotification(...);

    _cloudFunctions.approveUserAccess(user.id).then((_) {
      // Success - Firestore stream will remove user from list
    }).catchError((error) {
      if (mounted) {
        // Remove from processing on error so user can retry
        setState(() => _processingUsers.remove(user.id));
        ScaffoldMessenger.of(context).showSnackBar(...);
      }
      return <String, dynamic>{};
    });
  }
}
```

### Files to Modify
- `lib/presentation/admin/approval_queue_screen.dart` (methods `_handleApprove` and `_handleReject`)

---

## Issue #4: UserManagementScreen Optimistic Updates Without Error Feedback

### Description
When role changes, revoke, or restore operations fail, the error is only logged to `debugPrint` with no user feedback. The user sees "success" but the action didn't actually happen.

### Source Location
**File**: `lib/presentation/admin/user_management_screen.dart`  
**Lines**: 109-112, 149-152, 187-190

### Current Code
```dart
// Lines 109-112 (_showChangeRoleDialog)
_cloudFunctions.updateUserRole(user.id, result.toJson()).catchError((error) {
  debugPrint('Failed to update role: $error');  // ❌ No user feedback!
  return <String, dynamic>{};
});

// Lines 149-152 (_handleRevokeAccess)
_cloudFunctions.revokeUserAccess(user.id).catchError((error) {
  debugPrint('Failed to revoke access: $error');  // ❌ No user feedback!
  return <String, dynamic>{};
});

// Lines 187-190 (_handleRestoreAccess)
_cloudFunctions.restoreUserAccess(user.id).catchError((error) {
  debugPrint('Failed to restore access: $error');  // ❌ No user feedback!
  return <String, dynamic>{};
});
```

### Recommended Fix
Add user-facing error feedback with retry option (similar to ApprovalQueueScreen pattern):

```dart
// Example for _showChangeRoleDialog (apply same pattern to others)
_cloudFunctions.updateUserRole(user.id, result.toJson()).catchError((error) {
  debugPrint('Failed to update role: $error');
  if (mounted) {
    final message = error is FirebaseFunctionsException 
        ? error.message ?? error.code 
        : error.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to sync role change: $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () => _showChangeRoleDialog(user),
        ),
      ),
    );
  }
  return <String, dynamic>{};
});
```

### Files to Modify
- `lib/presentation/admin/user_management_screen.dart` (lines 109-112, 149-152, 187-190)

---

## Issue #5: RescheduleRequestDialog `_isSubmitting` Never Used

### Description
The `_isSubmitting` boolean is declared but never set to `true`, making the loading state on the submit button useless.

### Source Location
**File**: `lib/presentation/tasks/widgets/reschedule_request_dialog.dart`  
**Lines**: 27, 99-135

### Current Code
```dart
// Line 27
bool _isSubmitting = false;  // ❌ Declared but never set to true

// Lines 99-135
Future<void> _submitRequest() async {
  if (!_isValidDeadline) {...}

  // Capture values before popping
  final newDeadline = _newDeadline;
  ...

  // OPTIMISTIC UPDATE: Close dialog and show success immediately
  Navigator.of(context).pop(true);  // ❌ _isSubmitting never toggled!
  ScaffoldMessenger.of(context).showSnackBar(...);

  // Fire cloud function in background
  _cloudFunctions.requestReschedule(...).catchError((error) {...});
}
```

### Recommended Fix
Since the dialog uses optimistic update pattern (closes immediately), `_isSubmitting` can be removed entirely OR the pattern should be changed to show loading while waiting for response:

**Option A - Remove unused variable:**
```dart
// Remove line 27:
// bool _isSubmitting = false;

// Update lines 291-294 and 302-307 to remove _isSubmitting references
```

**Option B - Use proper loading state (if want to wait for server):**
```dart
Future<void> _submitRequest() async {
  if (!_isValidDeadline) {...}

  setState(() => _isSubmitting = true);
  
  try {
    await _cloudFunctions.requestReschedule(
      taskId: widget.task.id,
      newDeadline: _newDeadline,
      reason: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
    );
    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reschedule request submitted'), backgroundColor: Colors.green),
      );
    }
  } catch (error) {
    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $error'), backgroundColor: Colors.red),
      );
    }
  }
}
```

### Recommendation
**Use Option A** since the current optimistic pattern is intentional and documented. Just clean up the unused variable.

### Files to Modify
- `lib/presentation/tasks/widgets/reschedule_request_dialog.dart` (line 27, 291-294, 302-307)

---

## Issue #6: RescheduleApprovalScreen `_isProcessing` Never Used

### Description
Similar to Issue #5, the `_isProcessing` variable in `_RescheduleRequestCardState` is declared but never toggled.

### Source Location
**File**: `lib/presentation/approvals/reschedule_approval_screen.dart`  
**Lines**: 137, 433, 444

### Current Code
```dart
// Line 137
bool _isProcessing = false;  // ❌ Never set to true

// Lines 433, 444 - Used in button disabled check
onPressed: _isProcessing ? null : _handleReject,  // Always enabled
onPressed: _isProcessing ? null : _handleApprove,  // Always enabled
```

### Recommended Fix
**Option A - Remove unused variable** (since optimistic updates close the card via stream):
```dart
// Remove line 137
// Update lines 433 and 444 to just use the handler directly
onPressed: _handleReject,
onPressed: _handleApprove,
```

**Option B - Implement proper loading state** to prevent double-clicks:
```dart
Future<void> _handleApprove() async {
  setState(() => _isProcessing = true);
  
  ScaffoldMessenger.of(context).showSnackBar(...);

  _approvalRepository.approveRescheduleRequest(...).then((_) {
    return _approvalRepository.createRescheduleLog(...);
  }).catchError((error) {
    if (mounted) {
      setState(() => _isProcessing = false);  // Allow retry
      ScaffoldMessenger.of(context).showSnackBar(...);
    }
  });
}
```

### Recommendation
**Use Option B** to prevent double-click issues during the brief period before Firestore stream removes the card.

### Files to Modify
- `lib/presentation/approvals/reschedule_approval_screen.dart` (lines 137, 139-178, 181-233)

---

# Medium Priority Issues

## Issue #7: HomeScreen Calendar Token Refresh on Every Visit

### Description
`_refreshCalendarTokenIfNeeded` is called on every `initState` of HomeScreen. If user navigates away and back, it unnecessarily refreshes again.

### Source Location
**File**: `lib/presentation/home/home_screen.dart`  
**Lines**: 54-70

### Current Code
```dart
// Lines 54-70
@override
void initState() {
  super.initState();
  _tabController = TabController(length: 3, vsync: this);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _showCalendarGuideIfNeeded();
    _refreshCalendarTokenIfNeeded();  // ❌ Called every time
  });
}

Future<void> _refreshCalendarTokenIfNeeded() async {
  final authProvider = context.read<AuthProvider>();
  final currentUser = authProvider.currentUser;
  if (currentUser?.googleCalendarConnected == true) {
    await _calendarService.refreshAccessToken(currentUser!.id);
  }
}
```

### Recommended Fix
Add a cooldown mechanism using SharedPreferences or a static timestamp:

```dart
static DateTime? _lastCalendarRefresh;
static const _refreshCooldown = Duration(minutes: 30);

Future<void> _refreshCalendarTokenIfNeeded() async {
  // Skip if refreshed recently
  if (_lastCalendarRefresh != null && 
      DateTime.now().difference(_lastCalendarRefresh!) < _refreshCooldown) {
    return;
  }
  
  final authProvider = context.read<AuthProvider>();
  final currentUser = authProvider.currentUser;
  if (currentUser?.googleCalendarConnected == true) {
    await _calendarService.refreshAccessToken(currentUser!.id);
    _lastCalendarRefresh = DateTime.now();
  }
}
```

### Files to Modify
- `lib/presentation/home/home_screen.dart` (add static variable, modify `_refreshCalendarTokenIfNeeded`)

---

## Issue #8: TaskDetailScreen N+1 Query Pattern for Remarks

### Description
Each remark triggers a separate Firestore query for user data. With 10 remarks = 10 individual queries.

### Source Location
**File**: `lib/presentation/tasks/task_detail_screen.dart`  
**Lines**: 433-452

### Current Code
```dart
// Lines 433-452
return ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: remarks.length,
  itemBuilder: (context, index) {
    final remark = remarks[index];
    return StreamBuilder<UserModel?>(
      stream: userRepository.getUserStream(remark.userId),  // ❌ Per-remark query!
      builder: (context, userSnapshot) {
        return RemarkItem(
          remark: remark,
          user: userSnapshot.data,
        );
      },
    );
  },
);
```

### Recommended Fix
Implement user prefetching similar to HomeScreen's `_prefetchUsers` pattern:

```dart
// Add to TaskDetailScreen (convert to StatefulWidget if needed, or use FutureBuilder wrapper)
final Map<String, UserModel?> _userCache = {};

Future<void> _prefetchRemarkUsers(List<RemarkModel> remarks) async {
  final userIds = remarks.map((r) => r.userId).toSet();
  final uncachedIds = userIds.where((id) => !_userCache.containsKey(id)).toList();
  
  if (uncachedIds.isEmpty) return;
  
  final futures = uncachedIds.map((id) => userRepository.getUser(id));
  final users = await Future.wait(futures);
  
  for (int i = 0; i < uncachedIds.length; i++) {
    _userCache[uncachedIds[i]] = users[i];
  }
}

// Then in build:
return FutureBuilder<void>(
  future: _prefetchRemarkUsers(remarks),
  builder: (context, _) {
    return ListView.builder(
      itemCount: remarks.length,
      itemBuilder: (context, index) {
        final remark = remarks[index];
        return RemarkItem(
          remark: remark,
          user: _userCache[remark.userId],
        );
      },
    );
  },
);
```

### Alternative
Since TaskDetailScreen is a StatelessWidget, could wrap the remarks section in a separate StatefulWidget that handles prefetching.

### Files to Modify
- `lib/presentation/tasks/task_detail_screen.dart` (convert to StatefulWidget or add inner StatefulWidget for remarks section)

---

## Issue #9: ApprovalQueueScreen Empty Name Initial Crash

### Description
If a user signs up with no display name (can happen with some OAuth providers), accessing `user.name[0]` will throw a `RangeError`.

### Source Location
**File**: `lib/presentation/admin/approval_queue_screen.dart`  
**Line**: 208

### Current Code
```dart
// Line 208
child: Text(
  user.name[0],  // ❌ Crashes if name is empty!
  style: TextStyle(
    color: theme.colorScheme.onPrimaryContainer,
  ),
),
```

### Recommended Fix
Add a safety check:

```dart
child: Text(
  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
  style: TextStyle(
    color: theme.colorScheme.onPrimaryContainer,
  ),
),
```

### Note
This pattern also appears in other files. Search for similar usages:
- `lib/presentation/admin/user_management_screen.dart` (line 467) - Already fixed
- `lib/presentation/approvals/reschedule_approval_screen.dart` (lines 310-311) - Has null check but uses different pattern

### Files to Modify
- `lib/presentation/admin/approval_queue_screen.dart` (line 208)

---

## Issue #10: Backend Super Admin Role Check Inconsistency

### Description
The `cancelTask` function has a fallback to check Firestore if custom claims don't show super admin, but `updateTask` and `reopenTask` don't have this fallback.

### Source Location
**File**: `todo-backend/src/controllers/taskController.ts`  
**Lines**: 178-184 (updateTask), 272-281 (cancelTask), 317-319 (reopenTask)

### Current Code
```typescript
// cancelTask (lines 272-281) - HAS fallback
let isSuperAdmin = context.auth?.token?.role === UserRole.SUPER_ADMIN;

if (!isSuperAdmin) {
  const callerDoc = await db.collection(Collections.USERS).doc(callerId).get();
  if (callerDoc.exists) {
    isSuperAdmin = callerDoc.data()?.role === UserRole.SUPER_ADMIN;
  }
}

// updateTask (lines 178-184) - NO fallback
const callerRole = context.auth?.token?.role;
const isSuperAdmin = callerRole === UserRole.SUPER_ADMIN;  // ❌ No fallback

// reopenTask (lines 317-319) - NO fallback
const callerRole = context.auth?.token?.role;
if (callerRole !== UserRole.SUPER_ADMIN) {  // ❌ No fallback
  throw new functions.https.HttpsError('permission-denied', 'Only Super Admin can reopen tasks');
}
```

### Recommended Fix
Create a helper function and use it consistently:

```typescript
// Add helper function at top of file or in validators
async function isSuperAdminWithFallback(context: functions.https.CallableContext): Promise<boolean> {
  const callerId = context.auth?.uid;
  if (!callerId) return false;
  
  // First check custom claims
  if (context.auth?.token?.role === UserRole.SUPER_ADMIN) {
    return true;
  }
  
  // Fallback to Firestore
  const callerDoc = await db.collection(Collections.USERS).doc(callerId).get();
  return callerDoc.exists && callerDoc.data()?.role === UserRole.SUPER_ADMIN;
}

// Then use in updateTask, cancelTask, reopenTask:
const isSuperAdmin = await isSuperAdminWithFallback(context);
```

### Files to Modify
- `todo-backend/src/controllers/taskController.ts` (add helper, update updateTask and reopenTask)
- Optionally: `todo-backend/src/utils/validators.ts` (if helper should be shared)

---

# Low Priority / Enhancements

## Issue #11: ThemeProvider Initialize Without Error Handling

### Description
If SharedPreferences fails during theme initialization, the app may crash on startup.

### Source Location
**File**: `lib/main.dart`  
**Lines**: 50-51

### Current Code
```dart
// Lines 50-51
final themeProvider = ThemeProvider();
await themeProvider.initialize();  // ❌ No try-catch
```

### Recommended Fix
Wrap in try-catch with fallback:

```dart
final themeProvider = ThemeProvider();
try {
  await themeProvider.initialize();
} catch (e) {
  debugPrint('⚠️ Failed to initialize theme provider: $e');
  // App will use default theme
}
```

### Files to Modify
- `lib/main.dart` (lines 50-51)

---

## Issue #12: Calendar Service Hardcoded Web Client ID

### Description
Production credential is hardcoded in the source file. Should be in environment config.

### Source Location
**File**: `lib/data/services/calendar_service.dart`  
**Lines**: 25-26

### Current Code
```dart
// Lines 25-26
static const String _webClientId =
    '1062148887754-5gjiqtggvt2bltnrbj9ovg11sc71rc84.apps.googleusercontent.com';
```

### Recommended Fix
Move to environment configuration:

```dart
// In lib/core/constants/env_config.dart - add:
static String get googleWebClientId => 
    dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

// In calendar_service.dart - update:
String get _webClientId => EnvConfig.googleWebClientId;

// In .env and .env.example - add:
GOOGLE_WEB_CLIENT_ID=1062148887754-5gjiqtggvt2bltnrbj9ovg11sc71rc84.apps.googleusercontent.com
```

### Files to Modify
- `lib/data/services/calendar_service.dart` (lines 25-26)
- `lib/core/constants/env_config.dart` (add getter)
- `.env.example` (add variable)
- `.env` (add variable)

---

# Summary

| Issue | Priority | Complexity | Files Changed |
|-------|----------|------------|---------------|
| #1 Login `_isLoading` | Critical | Low | 1 |
| #2 Auth Race Condition | Critical | Medium | 1 |
| #3 `_processingUsers` | High | Low | 1 |
| #4 UserManagement Errors | High | Low | 1 |
| #5 Reschedule `_isSubmitting` | High | Low | 1 |
| #6 Approval `_isProcessing` | High | Low | 1 |
| #7 Calendar Refresh | Medium | Low | 1 |
| #8 N+1 Query Remarks | Medium | Medium | 1 |
| #9 Empty Name Crash | Medium | Low | 1 |
| #10 Backend Role Check | Medium | Medium | 1-2 |
| #11 Theme Error Handling | Low | Low | 1 |
| #12 Hardcoded Client ID | Low | Low | 3-4 |

---

# Excluded Issues (Require External Setup)

The following issues were identified but excluded from this plan as they require external setup or resources:

1. **Terms of Service / Privacy Policy URLs** - Requires legal document creation
2. **iOS APNs Configuration** - Requires Apple Developer account setup
3. **Crashlytics Integration** - Requires Firebase console setup
4. **Firestore Rules Audit** - Separate security review
5. **Rate Limiting on Cloud Functions** - Requires infrastructure decision
6. **Deep Link Handling** - Requires URL scheme registration and router changes

---

> **Next Steps**: After review, create implementation tickets for each issue based on priority and sprint capacity.
