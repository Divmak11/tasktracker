# TODO Planner - CodeMap & Technical Reference

**Version:** 1.0.12  
**Last Updated:** 2025-12-17  
**Project Version:** 1.0.0+1

---

## 1. Table of Contents

1. [Project Overview](#2-project-overview)
2. [Directory Structure](#3-directory-structure)
3. [Database/Data Layer Schemas](#4-databasedata-layer-schemas)
4. [Identifier Semantics](#5-identifier-semantics)
5. [Query/API Patterns](#6-queryapi-patterns)
6. [Data Handling Conventions](#7-data-handling-conventions)
7. [State Management](#8-state-management)
8. [Component Architecture](#9-component-architecture)
9. [Core Functions & Data Flow](#10-core-functions--data-flow)
10. [Design Documentation Workflow](#11-design-documentation-workflow)
11. [Temporary Implementations & Cloud Function Migration](#115-temporary-implementations--cloud-function-migration-plan)
12. [Known Pitfalls & Solutions](#12-known-pitfalls--solutions)
13. [Debugging Helpers](#13-debugging-helpers)
14. [Quick Reference](#14-quick-reference)
15. [Maintenance Guidelines](#15-maintenance-guidelines)
16. [Critical Information for AI/Developers](#16-critical-information-for-aidevelopers)

---

## 2. Project Overview

**Tech Stack**:
- **Framework**: Flutter 3.16+ (Dart 3.2+)
- **State Management**: Provider
- **Navigation**: GoRouter (with auth-based redirect)
- **Backend**: Firebase (Auth, Firestore, Functions, Storage, Messaging)
- **Authentication**: Firebase Auth (Google Sign-In, Apple Sign-In)
- **Database**: Cloud Firestore
- **Local Storage**: Shared Preferences (for theme/settings)
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Network**: `googleapis` (Calendar), `http`
- **UI Libraries**: `flutter_svg`, `cached_network_image`

**Architecture Pattern**:
- **Pattern**: Feature-based Layered Architecture
- **Layers**:
  - **Presentation**: UI screens and widgets (`lib/presentation/`)
  - **Domain/Data**: Repositories and Models (`lib/data/`)
  - **Core**: Shared utilities, constants, and theme (`lib/core/`)

**Core Modules**:
- **Auth**: Authentication and Onboarding
- **Task**: Task CRUD, Assignment, Remarks
- **Team**: Team creation and management
- **Admin**: Dashboard, User Approval, Reporting
- **Settings**: Profile, Theme, Calendar Integration

---

## 3. Directory Structure

```
lib/
├── main.dart                    // App entry point & initialization
├── firebase_options.dart        // Firebase configuration
    ├── core/
    │   ├── constants/          # app_strings.dart, app_spacing.dart, app_routes.dart, env_config.dart
    │   ├── theme/              # app_theme.dart (AppColors, AppTheme)
    │   ├── router/             # app_router.dart (GoRouter config)
    │   └── utils/              # permission_utils.dart (Role-based access control)
    ├── data/
    │   ├── models/             # user_model.dart, team_model.dart, task_model.dart, remark_model.dart, approval_request_model.dart, reschedule_log_model.dart, notification_model.dart
    │   ├── providers/          # auth_provider.dart, theme_provider.dart
    │   ├── repositories/       # auth_repository.dart, user_repository.dart, team_repository.dart, task_repository.dart, remark_repository.dart, approval_repository.dart, notification_repository.dart
    │   └── services/           # fcm_service.dart, notification_service.dart, calendar_service.dart
    ├── domain/
    │   ├── entities/           # Domain entities
    │   ├── repositories/       # Repository interfaces
    │   └── usecases/           # Business logic use cases
    └── presentation/
        ├── auth/               # login_screen.dart, request_pending_screen.dart, onboarding_screen.dart
        ├── common/             # Reusable widgets
        │   ├── buttons/        # app_button.dart
        │   ├── cards/          # app_card.dart
        │   ├── inputs/         # app_text_field.dart
        │   ├── badges/         # status_badge.dart
        │   └── list_items/     # task_list_item.dart
        ├── navigation/         # main_layout.dart (Bottom Navigation)
        ├── admin/              # admin_dashboard_screen.dart, team_management_screen.dart, create_team_screen.dart, team_detail_screen.dart, edit_team_screen.dart, approval_queue_screen.dart, user_management_screen.dart, reschedule_log_screen.dart
        ├── approvals/          # reschedule_approval_screen.dart
        ├── notifications/      # notification_center_screen.dart
        ├── home/               # home_screen.dart, widgets/task_card.dart
        ├── tasks/              # task_detail_screen.dart, create_task_screen.dart, edit_task_screen.dart, widgets/add_remark_dialog.dart, widgets/remark_item.dart, widgets/reschedule_request_dialog.dart
        └── settings/           # settings_screen.dart, theme_selector_screen.dart
```

---

## 4. Database/Data Layer Schemas

### Firestore Collections

#### Users Collection
**Path:** `/users/{userId}`
- `id` (string): Firebase Auth UID
- `name` (string): Display name
- `email` (string): User email
- `role` (string): 'super_admin' | 'team_admin' | 'member'
- `teamIds` (array<string>): IDs of teams user belongs to
- `status` (string): 'pending' | 'active' | 'revoked'
- `googleCalendarConnected` (boolean): OAuth status
- `revokedBy` (string, optional): Admin ID who revoked access
- `revokedAt` (timestamp, optional): When access was revoked
- `restoredBy` (string, optional): Admin ID who restored access
- `restoredAt` (timestamp, optional): When access was restored

#### Deleted Users Collection (Audit Log)
**Path:** `/deleted_users/{originalUserId}`
- All fields from original user document, plus:
- `deletedAt` (timestamp): When account was deleted
- `deletedBy` (string): User ID who performed deletion (self or admin)
- `deletionReason` (string): 'User self-deleted' | 'Admin deleted'
- `originalUserId` (string): Original Firebase Auth UID

#### Tasks Collection
**Path:** `/tasks/{taskId}`

**Core Fields:**
- `id` (string): UUID
- `title` (string): Task title
- `subtitle` (string): Description
- `assignedType` (string): 'member' | 'team'
- `createdBy` (string): User ID of task creator
- `status` (string): 'ongoing' | 'completed' | 'cancelled'
- `deadline` (timestamp): Due date
- `createdAt` (timestamp): Creation timestamp
- `updatedAt` (timestamp): Last update timestamp

**Legacy Single-Assignee Fields** (for backward compatibility):
- `assignedTo` (string, optional): User ID (for old single-assignee tasks)
- `calendarEventId` (string, optional): Google Calendar Event ID
- `completedAt` (timestamp, optional): Completion timestamp
- `completionRemark` (string, optional): Completion note

**Multi-Assignee Fields** (new structure):
- `isMultiAssignee` (boolean): True for tasks with 2+ assignees
- `assigneeIds` (array<string>): List of all assigned user IDs
- `supervisorIds` (array<string>): Users who can view all assignees' status
- `sourceTeamId` (string, optional): Original team ID if assigned to team
- `taskGroupId` (string, optional): Links related tasks from same team assignment

**Subcollection:** `/tasks/{taskId}/assignments/{assignmentId}`
- `id` (string): Assignment document ID
- `userId` (string): Assigned user ID
- `status` (string): 'ongoing' | 'completed'
- `assignedAt` (timestamp): Assignment timestamp
- `completedAt` (timestamp, optional): When this user completed
- `completionRemark` (string, optional): This user's completion note
- `calendarEventId` (string, optional): Calendar event for this user

#### Teams Collection
**Path:** `/teams/{teamId}`
- `id` (string): UUID
- `name` (string): Team name
- `adminId` (string): User ID of Team Admin
- `memberIds` (array<string>): List of member User IDs

---

## 5. Identifier Semantics

**Key Identifiers**:
- **User IDs**: Firebase Auth UIDs (alphanumeric string). Used as document keys in `users` collection.
- **Task/Team IDs**: UUIDs generated by Firestore (`doc().id`).
- **Calendar Event IDs**: String IDs returned by Google Calendar API.

**Naming Conventions**:
- **Variables**: camelCase (e.g., `isLoading`, `currentUser`)
- **Files**: snake_case (e.g., `user_repository.dart`)
- **Classes**: PascalCase (e.g., `UserRepository`)

---

## 6. Query/API Patterns

**Data Fetching (Repository Pattern)**:
All Firestore interactions are encapsulated in Repositories.

```dart
// Example: Fetching tasks
class TaskRepository {
  final FirebaseFirestore _firestore;
  
  Stream<List<TaskModel>> getTasks(String userId) {
    return _firestore
        .collection('tasks')
        .where('assignedTo', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TaskModel.fromJson(doc.data(), doc.id))
            .toList());
  }
}
```

**Authentication Flow** (Implemented):
1. UI calls `AuthProvider.signInWithGoogle()` or `signInWithApple()`
2. Provider calls `AuthRepository.signInWithGoogle()`
3. Repository uses `GoogleSignIn` to get credentials
4. Repository calls `FirebaseAuth.signInWithCredential()`
5. Auth state listener auto-fires
6. Provider loads `UserModel` from Firestore via `UserRepository`
7. GoRouter auto-navigates based on `user.status` and `user.role`

---

## 7. Data Handling Conventions

**Standards**:
- **Dates**: Use `DateTime` in models, convert to `Timestamp` for Firestore.
- **Null Safety**: All models use non-nullable fields with defaults where possible.
- **Serialization**: `fromJson(Map, String id)` factory and `toJson()` method in all models.
- **Validation**: Validate inputs in UI (Form keys) before sending to Repository.
- **Enum Handling**: Custom `toJson()` and `fromJson()` methods for enums (e.g., `UserRole`, `TaskStatus`).

**Data Models** (All implemented):
- `UserModel`: id, name, email, role, teamIds, status, needsOnboarding, calendar tokens
- `TeamModel`: id, name, adminId, memberIds, createdBy
- `TaskModel`: id, title, subtitle, assignedType, createdBy, status, deadline, isMultiAssignee, assigneeIds, supervisorIds, assignedTo (legacy), completedAt (legacy)
- `TaskAssignmentModel`: id, userId, status, assignedAt, completedAt, completionRemark, calendarEventId
- `RemarkModel`: id, taskId, userId, message
- `ApprovalRequestModel`: id, type, requesterId, targetId, payload, status
- `RescheduleLogModel`: id, taskId, requestedBy, deadlines, approvedBy

**Error Handling**:
- Repositories catch Firebase exceptions and throw custom `AppException`.
- UI catches `AppException` and shows `SnackBar` or `AlertDialog`.

**Optimistic Updates Pattern** (REQUIRED for all Cloud Function calls):
All network operations that update UI state should follow the optimistic update pattern for instant responsiveness:

```dart
// ❌ BLOCKING PATTERN (DON'T USE)
Future<void> _handleAction() async {
  setState(() => _isLoading = true);
  try {
    await _cloudFunctions.someAction();  // Blocks UI
    if (mounted) showSuccessNotification();
  } catch (e) {
    if (mounted) showErrorSnackbar(e);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

// ✅ OPTIMISTIC PATTERN (USE THIS)
Future<void> _handleAction() async {
  // 1. Show success immediately (optimistic)
  NotificationService.showInAppNotification(context, title: 'Success', ...);
  
  // 2. Navigate away if applicable
  context.pop();  // or Navigator.of(context).pop()
  
  // 3. Fire cloud function in background (don't await)
  _cloudFunctions.someAction().catchError((error) {
    debugPrint('Failed to sync: $error');
    // Firestore streams auto-correct UI if server fails
    return <String, dynamic>{};  // Required return type
  });
}
```

**Key Principles**:
1. **UI First**: Update UI immediately, sync in background
2. **Firestore Streams**: Real-time streams auto-correct if server update fails
3. **Error Handling**: Show retry snackbar for critical failures
4. **Return Types**: Always return a value in `catchError` to satisfy Future type

**Files Using This Pattern**:
- `task_detail_screen.dart` (complete/cancel)
- `add_remark_dialog.dart` (addRemark)
- `create_task_screen.dart` (assignTask)
- `edit_task_screen.dart` (updateTask)
- `reschedule_request_dialog.dart` (requestReschedule)
- `reschedule_approval_screen.dart` (approve/reject)
- `approval_queue_screen.dart` (approve/reject user)
- `user_management_screen.dart` (updateRole/revoke/restore)
- `invite_users_screen.dart` (send/resend/cancel invite)
- `profile_edit_screen.dart` (updateProfile)
- `notification_preferences_screen.dart` (updatePreferences)

---

## 8. State Management

**Provider Architecture**:
- **Global State**: `MultiProvider` in `main.dart`.
- **Access**: `Provider.of<T>(context)` or `Consumer<T>`.
- **Logic**: Business logic resides in `ChangeNotifier` classes (Providers).

**Key Providers**:
- `AuthProvider`: Manages user session and auth state.
- `ThemeProvider`: Manages light/dark mode preference.
- `TaskProvider`: Manages task lists and CRUD operations.

---

## 9. Component Architecture

### Initialization Sequence
1. `main()` calls `WidgetsFlutterBinding.ensureInitialized()`
2. Load `.env` variables via `flutter_dotenv`
3. Initialize `Firebase.initializeApp()` with platform-specific options (`firebase_options.dart`)
4. Create `MultiProvider` with `AuthProvider` (now with Firebase Auth + Firestore listeners)
5. Wrap app with `Consumer<AuthProvider>` to rebuild router on auth changes
6. Create `GoRouter` with `AuthProvider` for auth-based redirects
7. Run `MaterialApp.router` with dynamic router configuration

### State Management Setup
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()), // Firebase Auth + Firestore
  ],
  child: Consumer<AuthProvider>(
    builder: (context, authProvider, _) {
      return MaterialApp.router(
        routerConfig: AppRouter.createRouter(authProvider), // Dynamic router
      );
    },
  ),
)
```

**Key Changes from Mock**:
- ✅ `AuthProvider` now uses `AuthRepository` (Firebase Auth)
- ✅ Real-time user data sync from Firestore via `UserRepository`
- ✅ Auto-navigation based on auth state and user status
- ✅ Google Sign-In and Apple Sign-In integrated

### UI Component Hierarchy (Atomic Design)

#### **Atoms** (Basic Building Blocks)
**Location**: `lib/presentation/common/`

1. **AppButton** (`buttons/app_button.dart`)
   - Variants: Primary, Secondary, Text, Icon
   - Props: `text`, `onPressed`, `isLoading`, `type`, `icon`
   - Usage:
   ```dart
   AppButton(
     text: 'Create Task',
     onPressed: () {},
     type: AppButtonType.primary,
   )
   ```

2. **AppTextField** (`inputs/app_text_field.dart`)
   - Features: Label, hint, validation, prefix icon
   - Props: `label`, `hint`, `controller`, `validator`, `obscureText`
   - Usage:
   ```dart
   AppTextField(
     label: 'Email',
     hint: 'Enter your email',
     controller: _emailController,
     validator: (value) => ...,
   )
   ```

3. **StatusBadge** (`badges/status_badge.dart`)
   - Types: Ongoing, Completed, Cancelled, Overdue, PendingApproval
   - Auto-styled by status type
   - Usage:
   ```dart
   StatusBadge(status: StatusType.ongoing)
   ```

4. **AppCard** (`cards/app_card.dart`)
   - Variants: Standard, Elevated
   - Props: `child`, `onTap`, `type`, `padding`, `border`
   - Theme-aware elevation and colors

#### **Molecules** (Component Combinations)

1. **TaskListItem** (`list_items/task_list_item.dart`)
   - Components: Title, Subtitle, Deadline, StatusBadge, Assignee Avatar
   - Props: `title`, `subtitle`, `deadline`, `status`, `assigneeName`, `onTap`
   - Usage:
   ```dart
   TaskListItem(
     title: 'Complete Auth',
     subtitle: 'Implement login flow',
     deadline: DateTime.now(),
     status: StatusType.ongoing,
     assigneeName: 'John Doe',
     onTap: () => context.go('/task/1'),
   )
   ```

2. **MainLayout** (`navigation/main_layout.dart`)
   - Bottom Navigation Bar with 3 tabs
   - Wraps child screens via `ShellRoute`
   - Theme-aware tab indicators

#### **Organisms** (Screen-Level Components)

**Auth Module** (`presentation/auth/`):
- `LoginScreen` - Social login (Google/Apple)
- `EnterNameScreen` - **NEW (Dec 17, 2025)** - Name onboarding after first login
- `RequestPendingScreen` - Approval waiting state
- `AccessRevokedScreen` - Displayed when user access is revoked by Super Admin
- `OnboardingScreen` - 3-step PageView flow

**Admin Module** (`presentation/admin/`):
- `AdminDashboardScreen` - Stats overview + Quick Actions
- `TeamManagementScreen` - Team list with FAB (conditional)
- `CreateTeamScreen` - Team creation form
- `TeamDetailScreen` - Team members view
- `ApprovalQueueScreen` - **NEW** - Approve/reject pending users (Super Admin)
- `UserManagementScreen` - **UPDATED** - Manage all users with dual filters:
  - Role Filter: All Roles, Super Admin, Team Admin, Members
  - Status Filter: All, Active, Revoked (helps manage 100+ user lists)

**Task Module** (`presentation/tasks/`):
- `CreateTaskScreen` - **UPDATED** - Task form with 3 assignment types (Member, Team, Self)
- `TaskDetailScreen` - Full task info with actions

**Home Module** (`presentation/home/`):
- `HomeScreen` - Task list for members

**Settings Module** (`presentation/settings/`):
- `SettingsScreen` - Profile and logout

### Permission System

**PermissionUtils** (`lib/core/utils/permission_utils.dart`) - **NEW**:
- Static utility class for role-based access control
- Methods:
  ```dart
  static bool canCreateTask(UserRole? role)        // All users
  static bool canCreateTeam(UserRole? role)        // Super Admin and Team Admin
  static bool canApproveUsers(UserRole? role)      // Super Admin only
  static bool canManageUsers(UserRole? role)       // Super Admin only
  static bool canPromoteTeamAdmin(UserRole? role)  // Super Admin only
  static bool canReopenTask(UserRole? role)        // Super Admin only
  static bool isAdmin(UserRole? role)              // Helper
  static bool isSuperAdmin(UserRole? role)         // Helper
  ```
- **Usage Pattern**:
  ```dart
  // Conditional rendering
  if (PermissionUtils.canCreateTeam(authProvider.userRole)) {
    return FloatingActionButton(...);
  }
  
  // In widget tree
  floatingActionButton: PermissionUtils.canCreateTeam(
    context.watch<AuthProvider>().userRole
  ) ? FloatingActionButton(...) : null
  ```


### Theming System

**AppTheme** (`lib/core/theme/app_theme.dart`):
- `lightTheme` and `darkTheme` ThemeData
- Material 3 design
- Custom color schemes via `AppColors`

**AppColors** (Static class):
- Primary, Secondary, Error, Success, Warning palettes
- Neutral (Gray) and Slate scales (50-900)
- Light/Dark mode variants

**Access Pattern**:
```dart
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;
final primaryColor = theme.colorScheme.primary;
final neutralText = isDark ? AppColors.neutral300 : AppColors.neutral700;
```

**Constants**:
- `AppSpacing` - xs, sm, md, lg, xl, xxl, screenPaddingMobile
- `AppRadius` - small, medium, large, full
- `AppIconSize` - small, medium, large

---

## 10. Core Functions & Data Flow


### Authentication Flow (Firebase - IMPLEMENTED) ✅

```
LoginScreen
  ↓ User taps "Continue with Google"
  ↓ _handleGoogleSignIn()
  ↓ setState(isLoading: true)
  ↓ context.read<AuthProvider>().signInWithGoogle()
  ↓
AuthProvider.signInWithGoogle()
  ↓ Calls AuthRepository.signInWithGoogle()
  ↓
AuthRepository.signInWithGoogle()
  ↓ GoogleSignIn().signIn() → Get Google account
  ↓ Get Google auth credentials (accessToken, idToken)
  ↓ Create Firebase credential
  ↓ FirebaseAuth.signInWithCredential(credential)
  ↓ Returns UserCredential
  ↓
Firebase Auth State Change (automatic)
  ↓ AuthProvider._authStateSubscription listener fires
  ↓ AuthProvider._loadUserData(firebaseUserId)
  ↓
UserRepository.getUserStream(userId)
  ↓ Firestore.collection('users').doc(userId).snapshots()
  ↓ Listens for real-time user document changes
  ↓ Maps to UserModel
  ↓ AuthProvider._currentUser = userModel
  ↓ notifyListeners()
  ↓
GoRouter Redirect Logic (automatic)
  ↓ Router rebuilds due to AuthProvider change
  ↓ Check: isAuthenticated? → YES
  ↓ Check: currentUser loaded? → YES (from Firestore)
  ↓ Check: user.needsOnboarding == true? (NEW - Dec 17, 2025)
  │   YES → Navigate to EnterNameScreen
  │   NO → Continue
  ↓ Check: user.status == 'pending'?
  │   YES → Navigate to RequestPendingScreen
  │   NO → Continue
  ↓ Check: user.status == 'revoked'? (UPDATED Dec 19, 2025)
  │   YES → Navigate to AccessRevokedScreen (user stays authenticated)
  │   NO → Continue
  ↓ Check: user.status == 'active'?
  │   YES → Navigate based on role:
  │     SuperAdmin → /admin (AdminDashboardScreen)
  │     TeamAdmin/Member → / (HomeScreen)
```

**Implementation Details**:
- **AuthRepository**: Handles Firebase Auth API calls
- **UserRepository**: Manages Firestore user documents
- **AuthProvider**: Orchestrates both + notifies UI
- **Real-time Sync**: User data updates live from Firestore
- **Auto-Navigation**: GoRouter redirects based on auth state

**Supported Sign-In Methods**:
- ✅ Google Sign-In (Android, iOS, macOS)
- ✅ Apple Sign-In (iOS, macOS only)

**User Status Handling** (Updated Dec 19, 2025):
- `pending`: Redirect to RequestPendingScreen (wait for admin approval)
- `active`: Allow app access
- `revoked`: Redirect to AccessRevokedScreen (Firebase Auth NOT disabled, user can view revoked page)

### Logout Flow (Implemented)
```
SettingsScreen / RequestPendingScreen
  ↓ User taps "Logout"
  ↓ Show confirmation dialog
  ↓ User confirms
  ↓ context.read<AuthProvider>().logout()
  ↓ AuthProvider clears currentUser
  ↓ context.go(AppRoutes.login)
```

### Task Creation Flow (Implemented ✅)
```
HomeScreen
  ↓ User taps FAB
  ↓ context.go('/task/create')
  ↓
CreateTaskScreen
  ↓ User fills form (title, description, deadline)
  ↓ User selects assignment type:
  │   - Member (search & select user from dropdown)
  │   - Team (select from team dropdown)
  │   - Self (automatically assigns to current user, no dropdown needed)
  ↓ User taps "Create Task"
  ↓ Validate form
  ↓ Optimistic update: Show success notification
  ↓ context.pop()
  ↓ Fire Cloud Function in background (assignTask)
  ↓ Cloud Function creates task + Calendar event + Sends notification
  ↓ Firestore real-time listener updates task list
```

**Self Assignment Feature**: 
- When "Self" is selected, assignee dropdown is hidden
- Task is automatically assigned to the current logged-in user
- Backend receives 'member' as assignedType with current user's ID

### Task Completion Flow (Implemented)
```
TaskDetailScreen
  ↓ User taps "Mark as Completed"
  ↓ Show confirmation dialog
  ↓ User confirms
  ↓ Currently: Show success SnackBar
  ↓
Future:
  ↓ TaskProvider.completeTask(taskId)
  ↓ Update Firestore document {status: 'completed'}
  ↓ Cloud Function updates calendar event
```

### Team Creation Flow (UI Only)
```
TeamManagementScreen
  ↓ User taps FAB (only if Super Admin)
  ↓ context.go('/admin/teams/create')
  ↓
CreateTeamScreen
  ↓ User enters name and selects members
  ↓ User taps "Create Team"
  ↓ Validate (name + at least 1 member)
  ↓ Currently: Mock delay → context.pop()
  ↓
Future:
  ↓ TeamProvider.createTeam(data)
  ↓ Cloud Function creates team + Updates user documents
```

### User Approval Workflow (Module 2 - UI Only)
```
Super Admin Perspective:
AdminDashboardScreen
  ↓ Shows "3 Pending Requests" in stats
  ↓ User taps "Approve Requests" Quick Action
  ↓ context.go('/admin/approvals')
  ↓
ApprovalQueueScreen
  ↓ List of pending users (mock data)
  ↓ User taps "Approve" on a request
  ↓ Show confirmation dialog
  ↓ User confirms
  ↓ Currently: Remove from list, show success SnackBar
  ↓
Future (Backend Integration):
  ↓ Call Cloud Function: approveUserAccess(userId)
  ↓ Function updates user.status = 'active'
  ↓ Function sends FCM notification to approved user
  ↓ Real-time listener updates UI
  
Pending User Perspective:
RequestPendingScreen
  ↓ Shows waiting message
  ↓ "Logout" button available
  ↓ Future: Receives FCM notification when approved
  ↓ Real-time listener detects status change
  ↓ Auto-navigate to OnboardingScreen or Home
```

**Current Implementation**: Mock data, no Firebase
**Future Implementation**: 
1. Firestore listener on `/users/{userId}` for status changes
2. Cloud Function `approveUserAccess` callable
3. FCM push notification on approval
4. UI reacts to real-time status updates


### Navigation Flow (Implemented)
```
Login
  ↓ Social login
  ↓
MainLayout (ShellRoute)
  ├─ AdminDashboardScreen (/)
  ├─ TeamManagementScreen (/admin/teams)
  │   ├─ CreateTeamScreen (/admin/teams/create)
  │   └─ TeamDetailScreen (/admin/teams/:id)
  ├─ SettingsScreen (/settings)
  └─ HomeScreen (/)
      ├─ CreateTaskScreen (/task/create)
      └─ TaskDetailScreen (/task/:id)
```

**Route Table**:
| Route | Screen | Access |
|-------|--------|--------|
| `/login` | LoginScreen | Public |
| `/enter-name` | EnterNameScreen | Authenticated (needsOnboarding) |
| `/request-pending` | RequestPendingScreen | Authenticated (pending) |
| `/access-revoked` | AccessRevokedScreen | Authenticated (revoked) |
| `/onboarding` | OnboardingScreen | Authenticated (first login) |
| `/` or `/admin` | AdminDashboardScreen | Admin only |
| `/admin/teams` | TeamManagementScreen | Admin only |
| `/admin/teams/create` | CreateTeamScreen | Admin only |
| `/admin/teams/:id` | TeamDetailScreen | Admin only |
| `/` | HomeScreen | Member |
| `/task/create` | CreateTaskScreen | Authenticated |
| `/task/:id` | TaskDetailScreen | Authenticated |
| `/settings` | SettingsScreen | Authenticated |

---

## 11. Design Documentation Workflow

**Source of Truth**: `.windsurf/design_system.md`

**Workflow**:
1. Check `design_system.md` for component specs (colors, spacing, typography).
2. Use `AppTheme` and `AppSpacing` constants in code.
3. Do NOT hardcode colors or dimensions; use the defined tokens.

---

## 11.5. Cloud Functions Integration (COMPLETED ✅)

> **✅ PRODUCTION READY**  
> All write operations now use **Cloud Functions (Callable)** for security, business logic validation, and proper notifications. Backend deployed to Firebase project `todo-taskmanager-25ab4`.

### Architecture (Production)

```
Flutter App → Repository → CloudFunctionsService → Cloud Function → Firestore + Notifications
```

### Migration Status Table

| Repository | Method | Cloud Function | Status |
|------------|--------|----------------|--------|
| **UserRepository** | `approveUserAccess()` | ✅ `approveUserAccess` | **DONE** |
| **UserRepository** | `rejectUserAccess()` | ✅ `rejectUserAccess` | **DONE** |
| **UserRepository** | `updateUserRole()` | ✅ `updateUserRole` | **DONE** |
| **UserRepository** | `revokeUserAccess()` | ✅ `revokeUserAccess` | **DONE** |
| **UserRepository** | `deleteUser()` | ✅ `deleteUser` | **DONE** |
| **TeamRepository** | `createTeam()` | ✅ `createTeam` | **DONE** |
| **TeamRepository** | `updateTeam()` | ✅ `updateTeam` | **DONE** |
| **TeamRepository** | `deleteTeam()` | ✅ `deleteTeam` | **DONE** |
| **TeamRepository** | `addMember()` | ✅ `updateTeam` | **DONE** |
| **TeamRepository** | `removeMember()` | ✅ `updateTeam` | **DONE** |
| **TaskRepository** | `createTask()` | ✅ `assignTask` | **DONE** |
| **TaskRepository** | `updateTask()` | ✅ `updateTask` | **DONE** |
| **TaskRepository** | `completeTask()` | ✅ `completeTask` | **DONE** |
| **TaskRepository** | `cancelTask()` | ✅ `cancelTask` | **DONE** |
| **TaskRepository** | `reopenTask()` | ✅ `reopenTask` | **DONE** |
| **ApprovalRepository** | `createRescheduleRequest()` | ✅ `requestReschedule` | **DONE** |
| **ApprovalRepository** | `approveRescheduleRequest()` | ✅ `approveReschedule` | **DONE** |
| **ApprovalRepository** | `rejectRescheduleRequest()` | ✅ `approveReschedule` | **DONE** |
| **RemarkRepository** | `addRemark()` | ✅ `addRemark` | **DONE** |
| **CalendarService** | `disconnect()` | ✅ `disconnectCalendar` | **DONE** |

### Cloud Functions Service

**Location**: `lib/data/services/cloud_functions_service.dart`

```dart
// Usage example
final cloudFunctions = CloudFunctionsService();

// User management
await cloudFunctions.approveUserAccess(userId);
await cloudFunctions.updateUserRole(userId, 'team_admin');

// Team management  
await cloudFunctions.createTeam(name: 'Dev Team', memberIds: [...], adminId: '...');

// Task management
await cloudFunctions.assignTask(title: '...', deadline: DateTime.now(), ...);
await cloudFunctions.completeTask(taskId, remark: 'Done!');

// Reschedule workflow
await cloudFunctions.requestReschedule(taskId: '...', newDeadline: DateTime.now());
await cloudFunctions.approveReschedule(requestId: '...', approved: true);

// Remark management
await cloudFunctions.addRemark(taskId: '...', message: 'Great progress!');

// Calendar management
await cloudFunctions.disconnectCalendar();
```

### Deployed Cloud Functions (30 total)

| Category | Functions |
|----------|-----------|
| **User Management** | `approveUserAccess`, `rejectUserAccess`, `updateUserRole`, `revokeUserAccess`, `deleteUser`, `updateProfile` |
| **Team Management** | `createTeam`, `updateTeam`, `deleteTeam` |
| **Task Management** | `assignTask`, `updateTask`, `completeTask`, `cancelTask`, `reopenTask` |
| **Reschedule** | `requestReschedule`, `approveReschedule` |
| **Remark** | `addRemark` |
| **Calendar** | `disconnectCalendar` |
| **Multi-Assignee** | `completeAssignment` |
| **Auth Triggers** | `createUserProfile`, `onUserDeleted` |
| **Notification Triggers** | `notifyAdminNewUser`, `notifyUserStatusChange`, `notifyTeamCreation`, `notifyTeamMemberChange`, `notifyTaskAssignment`, `notifyTaskStatusChange` |
| **Scheduled** | `checkDeadlines`, `checkOverdueTasks`, `cleanupInactiveTracking` |

### Multi-Assignee Task Architecture (Dec 15, 2025)

**Overview:**
Major architectural update to support assigning a single task to multiple users with shared remarks, individual completion tracking, and supervisor roles.

**Architecture Pattern: Normalized Parent-Child Model**
- **Single Task (1 assignee)**: Legacy structure with `assignedTo` field
- **Multi-Assignee (2+ assignees)**: Parent task with `assignments` subcollection
- **Team Assignment**: Resolves to multi-assignee with all team members

**Key Features:**
1. **Shared Task Context**: All assignees see the same task with shared remarks
2. **Individual Progress**: Each assignee can complete their assignment independently
3. **Supervisor Role**: Selected assignees can view completion status of all users
4. **Backward Compatibility**: Old single-assignee tasks continue to work

**Data Structure:**

```
tasks/{taskId}                     // Parent task document
  ├─ isMultiAssignee: true
  ├─ assigneeIds: ["user1", "user2", "user3"]
  ├─ supervisorIds: ["user1"]      // Can see all completion status
  ├─ status: "ongoing"             // Overall task status
  └─ assignments/{assignmentId}    // Per-user tracking
       ├─ userId: "user1"
       ├─ status: "completed"
       ├─ completedAt: timestamp
       └─ completionRemark: "Done!"
```

**Backend Changes:**
- `assignTask`: Creates parent task + assignment subdocs for multi-assignee
- `completeAssignment`: Marks individual assignment complete
- `completeTask`: Routes to `completeAssignment` for multi-assignee tasks
- `cancelTask`, `reopenTask`: Handle both single and multi-assignee

**Frontend Changes:**
- `TaskModel`: Added `isMultiAssignee`, `assigneeIds`, `supervisorIds` fields + helper methods
- `TaskAssignmentModel`: New model for assignment subdocuments
- `TaskRepository`: Added `getTaskAssignmentsStream()`, `getUserAssignedTasksStream()`
- `AssigneeSelectionScreen`: Added supervisor toggle for multi-assignee selection
- `CreateTaskScreen`: Pass supervisorIds when creating tasks
- `TaskDetailScreen`: Show assignments progress table for creator/supervisor
- `TaskTile`: Display assignee count for multi-assignee tasks

**Helper Methods in TaskModel:**
```dart
task.isCreator(userId)              // Check if user created the task
task.isSupervisor(userId)           // Check if user is a supervisor
task.isAssignee(userId)             // Check if user is assigned
task.canSeeAllCompletionStatus(userId)  // Creator or supervisor
task.allAssigneeIds                 // Get all assignee IDs
task.primaryAssigneeId              // Get first assignee for display
```

### New Screens Added (Nov 27, 2025)

| Screen | Path | Description |
|--------|------|-------------|
| `ProfileEditScreen` | `/settings/profile` | Edit user name and avatar |
| `NotificationPreferencesScreen` | `/settings/notifications` | Manage notification preferences |
| `CalendarViewScreen` | `/calendar` | In-app calendar with task events |
| `OverdueTasksScreen` | `/admin/overdue-tasks` | Admin view of all overdue tasks |
| `ExportReportDialog` | Dialog | PDF report export with filters |

### Backend Project

- **Location**: `/Users/divyammakar/workspace/Projects/todo-backend`
- **Firebase Project**: `todo-taskmanager-25ab4`
- **CodeMap**: `.windsurf/CodeMap.md`

### Required Firestore Indexes for Multi-Assignee Tasks

The following composite indexes are required for multi-assignee task queries to work correctly. Firebase will auto-generate these links in the console when queries fail, but you can also create them proactively:

**Collection: `tasks`**

| Fields | Order | Purpose |
|--------|-------|---------|
| `assigneeIds` (ARRAY), `status` (ASC) | - | Filter multi-assignee tasks by status |
| `assigneeIds` (ARRAY), `deadline` (ASC) | - | Sort multi-assignee tasks by deadline |
| `assigneeIds` (ARRAY), `status` (ASC), `deadline` (ASC) | - | Combined filter + sort |
| `assignedTo` (ASC), `status` (ASC), `deadline` (ASC) | - | Legacy single-assignee queries |
| `assignedTo` (ASC), `status` (ASC), `deadline` (DESC) | - | Legacy past tasks query |

**How to Create:**
1. Run the app and trigger queries that require indexes
2. Check the debug console for "requires an index" errors
3. Click the provided link to auto-create the index in Firebase Console
4. Or manually create in Firebase Console → Firestore → Indexes → Add Index

---

## 12. Known Pitfalls & Solutions

**Issue**: Firestore Index Errors
- **Symptom**: Query fails with "requires an index" link.
- **Solution**: Click the link in debug console to create the composite index.

**Issue**: Keyboard Overflows
- **Symptom**: Yellow/black striped warning on input screens.
- **Solution**: Wrap form content in `SingleChildScrollView`.

**Issue**: Context in Async Methods
- **Symptom**: "Looking up a deactivated widget's ancestor".
- **Solution**: Check `mounted` before using `context` after an `await`.

**Issue**: Firestore Collection Name Mismatch ⚠️ CRITICAL
- **Symptom**: Data created by backend doesn't appear in Flutter queries.
- **Cause**: Backend uses camelCase collection names (`approvalRequests`, `rescheduleLog`), but Flutter used snake_case.
- **Solution**: Always use camelCase collection names to match backend: `approvalRequests`, `rescheduleLog` (NOT `approval_requests`, `reschedule_logs`).

**Issue**: DateTime/Timestamp Type Mismatch in updateTask
- **Symptom**: "DateTime is not subtype of Timestamp" error when editing task deadline.
- **Cause**: `task_repository.dart` expected Timestamp but callers passed DateTime.
- **Solution**: Handle both types in `updateTask` method using type checking.

**Issue**: Button Text Overflow
- **Symptom**: RenderFlex overflow on the right in `AppButton`.
- **Solution**: Wrap Text in `Flexible` with `TextOverflow.ellipsis` in `app_button.dart`.

**Issue**: Google Sign-In SecurityException ⚠️ IMPORTANT
- **Symptom**: `E/GoogleApiManager: java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'`
- **Cause**: Missing SHA-1/SHA-256 fingerprints in Firebase Console.
- **Solution**: 
  1. Run `cd android && ./gradlew signingReport`
  2. Copy SHA-1 and SHA-256 hashes
  3. Add them to Firebase Console → Project Settings → Your Android App
  4. Download updated `google-services.json`
  5. Rebuild app
- **Full Guide**: See `.windsurf/GOOGLE_SIGNIN_FIX.md`

**Issue**: Users Getting Logged Out Automatically
- **Symptom**: Super Admin users report being logged out after some time.
- **Cause**: Firebase Auth persistence not explicitly configured.
- **Solution**: ✅ **FIXED** - Added `Firebase.Auth.setPersistence(Persistence.LOCAL)` in main.dart (line 27-33)
- **Verification**: Check logs for `✅ Firebase Auth persistence set to LOCAL`

**Issue**: App Always Shows Login Screen on Launch
- **Symptom**: Even authenticated users see login screen briefly before being redirected.
- **Cause**: Router `initialLocation` was set to `/login`, causing flash of login screen.
- **Solution**: ✅ **FIXED** - 
  1. Added `SplashScreen` component
  2. Changed `initialLocation` to `/` (shows splash while checking auth)
  3. Router redirects to appropriate screen after auth state loads
- **Impact**: Users now see branded splash screen → seamless navigation to Dashboard/Home

**Issue**: Splash Screen Shows Too Long
- **Symptom**: Splash screen visible for extended period.
- **Cause**: Slow network or large Firestore user document.
- **Solution**: 
  - Check `_loadUserData()` in `auth_provider.dart`
  - Verify Firestore indexes are created
  - Monitor `🔀 Router Redirect` debug logs

**Issue**: Notification Screen Lag / Multiple Taps Required
- **Symptom**: Notification taps unresponsive, multiple taps needed, lag when opening items.
- **Cause**: `NotificationRepository()` created on every build; `await markAsRead()` blocked navigation.
- **Solution**: ✅ **FIXED** (Dec 13, 2025)
  1. Converted to `StatefulWidget` to cache `NotificationRepository`
  2. Navigate immediately without awaiting `markAsRead`
  3. Use fire-and-forget pattern for background operations
  4. Changed from `context.watch` to `context.read` for auth
- **Impact**: Instant tap response, smooth navigation

**Issue**: Excessive Router Redirect Logs / Abrupt Redirections
- **Symptom**: Router redirect logs (`🔀 Router Redirect`) appearing on every state change, not just navigation.
- **Cause**: `GoRouter` was being recreated inside `Consumer2` on every `AuthProvider.notifyListeners()`.
- **Solution**: ✅ **FIXED** (Dec 13, 2025)
  1. Converted `MyApp` from `StatelessWidget` to `StatefulWidget` in `main.dart`
  2. Cache `AuthProvider` and `GoRouter` instances in `initState()`
  3. Use `refreshListenable: authProvider` in GoRouter to re-evaluate redirects on auth changes
  4. Changed from `Consumer2` to `Consumer<ThemeProvider>` (only theme triggers rebuilds)
- **Impact**: Router redirects now only trigger on actual navigation or auth state changes

**Issue**: Production Audit Fixes Phase 1 (Dec 13, 2025)
- **Files Modified**: 
  - `login_screen.dart` - Fixed `_isLoading` never reset on success
  - `auth_provider.dart` - Fixed race condition with proper user data wait mechanism
  - `approval_queue_screen.dart` - Fixed `_processingUsers` never populated, empty name crash
  - `user_management_screen.dart` - Added error feedback for optimistic updates + added `_processingUsers` to prevent double-clicks
  - `reschedule_request_dialog.dart` - Removed optimistic pattern, added proper loading state and error feedback
  - `reschedule_approval_screen.dart` - Fixed `_isProcessing` to prevent double-clicks, removed duplicate log creation
  - `home_screen.dart` - Added 30-min cooldown for calendar token refresh with user feedback
  - `main.dart` - Added try-catch for ThemeProvider initialization
  - `calendar_service.dart` - Moved hardcoded web client ID to environment config
  - `env_config.dart` - Added `googleWebClientId` getter
  - `.env.example` - Added `GOOGLE_WEB_CLIENT_ID` variable
  - `taskController.ts` (backend) - Added Firestore fallback for super admin role check
- **Optimistic Update Pattern**: All screens with optimistic updates now show proper error feedback via SnackBar with retry option. `reschedule_request_dialog.dart` uses synchronous pattern (waits for server response) to avoid confusing users.
- **Details**: See `.windsurf/AUDIT_FIX_PLAN.md` for complete documentation

**Issue**: Production Audit Fixes Phase 2 (Dec 13, 2025)
- **Files Modified**:
  - `calendar_service.dart` - Added retry logic with `CalendarRefreshResult` enum for better error handling
  - `home_screen.dart` - Updated to handle `CalendarRefreshResult` with user feedback for failures/reconnect needed
  - `cloud_functions_service.dart` - Added `CloudFunctionTimeoutException` and 30s timeout wrapper for critical calls
  - `create_task_screen.dart` - Added validation to prevent selecting past time when today is selected
  - `reschedule_approval_screen.dart` - Removed duplicate log creation (backend already creates it)
  - `taskController.ts` (backend) - Added `taskGroupId` and `sourceTeamId` for team assignment linking
  - `main.dart` - Added global `FlutterError.onError` handler, uses `EnvConfig.isProduction` for conditional debug output
- **New Features**:
  - Cloud function calls now have 30s timeout with clear error messages
  - Team assignments now create linked tasks via `taskGroupId` for bulk operations
  - Calendar refresh shows appropriate feedback when reconnection is needed

**Issue**: User Deletion & Management Refactor (Dec 19, 2025)
- **Files Modified**:
  - `userController.ts` (backend) - Complete overhaul of deletion and revocation logic
  - `auth_provider.dart` - Added `WidgetsBindingObserver` for app lifecycle, fixed imports
  - `access_revoked_screen.dart` - Converted to static screen with "Contact Admin" message
  - `cloud_functions_service.dart` - Added `deleteOwnAccount` method
- **New Features**:
  1. **Audit Log**: Deleted users archived to `deleted_users` collection
  2. **Zombie Cleanup**: Deletion queries by email to remove duplicate user documents
  3. **Multi-Assignee Protection**: User removed from `assigneeIds`, task only cancelled if 0 assignees remain
  4. **Revoked User Flow**: Firebase Auth NOT disabled, user sees AccessRevokedScreen
  5. **Restore Access**: Re-enables Firebase Auth for legacy disabled accounts
- **Key Behavioral Changes**:
  - `revokeUserAccess`: No longer disables Firebase Auth account
  - `restoreUserAccess`: Re-enables Firebase Auth (handles legacy disabled accounts)
  - `deleteUser` / `deleteOwnAccount`: Archives to `deleted_users`, cleans up duplicates by email
  - Multi-assignee tasks: Removes deleted user from `assigneeIds` instead of cancelling entire task
- **Re-registration Flow**:
  - After deletion, user can re-login with same account
  - System creates new `pending` user document
  - Admin receives notification, user appears in Approval Queue

---

## 13. Debugging Helpers

**Logging**:
- Use `debugPrint()` for general logging.
- Firebase Crashlytics for production errors.

**Common Debug Points**:
- `AuthRepository`: Check `currentUser` status.
- `GoRouter`: Check current route stack.

---

## 14. Quick Reference

### Essential File Locations
| Purpose | File Path |
|---------|-----------|
| App Entry | `lib/main.dart` |
| Routes | `lib/core/constants/app_routes.dart` |
| Router Config | `lib/core/router/app_router.dart` |
| Theme | `lib/core/theme/app_theme.dart` |
| Spacing/Radius | `lib/core/constants/app_spacing.dart` |
| Strings | `lib/core/constants/app_strings.dart` |
| **Auth Provider** | **`lib/data/providers/auth_provider.dart`** ✅ |
| **Theme Provider** | **`lib/data/providers/theme_provider.dart`** ✅ |
| **Auth Repository** | **`lib/data/repositories/auth_repository.dart`** ✅ |
| **User Repository** | **`lib/data/repositories/user_repository.dart`** ✅ |
| **Team Repository** | **`lib/data/repositories/team_repository.dart`** ✅ |
| **Task Repository** | **`lib/data/repositories/task_repository.dart`** ✅ |
| **Remark Repository** | **`lib/data/repositories/remark_repository.dart`** ✅ |
| Firebase Config | `lib/firebase_options.dart` ✅ |
| Env Config | `lib/core/constants/env_config.dart` |
| **Android Config** | **`android/app/google-services.json`** ✅ |
| **iOS Config** | **`ios/Runner/GoogleService-Info.plist`** ✅ |

### Implemented Screens Catalog

**Authentication** (`lib/presentation/auth/`):
| Screen | File | Purpose |
|--------|------|---------|
| Login | `login_screen.dart` | Social login (Google/Apple) |
| Request Pending | `request_pending_screen.dart` | Approval waiting state |
| Onboarding | `onboarding_screen.dart` | 3-step welcome flow |
| Signup | `signup_screen.dart` | Placeholder (merged with login) |

**Admin** (`lib/presentation/admin/`):
| Screen | File | Purpose |
|--------|------|---------|
| Dashboard | `admin_dashboard_screen.dart` | Overview stats + Quick Actions (real-time). "Active Tasks" navigates to Ongoing tab by default |
| **All Tasks** | **`all_tasks_screen.dart`** | **Tabbed task view (All/Ongoing/Completed/Cancelled) with assignee filter. Default tab: Ongoing** |
| Team Management | `team_management_screen.dart` | List all teams |
| Create Team | `create_team_screen.dart` | Team creation form |
| Team Detail | `team_detail_screen.dart` | View team members |
| **Edit Team** | **`edit_team_screen.dart`** | **Edit team name/members/admin** |
| **Approval Queue** | **`approval_queue_screen.dart`** | **Approve/reject pending users (Super Admin)** |
| **User Management** | **`user_management_screen.dart`** | **Manage all users, change roles (Super Admin)** |

**Tasks** (`lib/presentation/tasks/`):
| Screen | File | Purpose |
|--------|------|---------|
| Create Task | `create_task_screen.dart` | Task creation with member/team assignment (revamped with separate assignee selection) |
| Task Detail | `task_detail_screen.dart` | View task info with conditional actions (revamped compact people section) |
| **Edit Task** | **`edit_task_screen.dart`** | **Edit task title/description/deadline** |
| **Assignee Selection** | **`widgets/assignee_selection_screen.dart`** | **Full-screen modal for multi-user selection** |

**Other**:
| Screen | File | Purpose |
|--------|------|---------|
| Home | `lib/presentation/home/home_screen.dart` | Task list with Ongoing/Past tabs |
| Settings | `lib/presentation/settings/settings_screen.dart` | Profile & settings |
| **Theme Selector** | **`lib/presentation/settings/theme_selector_screen.dart`** | **Light/Dark/System theme selection** |
| Main Layout | `lib/presentation/navigation/main_layout.dart` | Bottom nav wrapper |

### Reusable Component Catalog

| Component | File | Props | Usage Example |
|-----------|------|-------|---------------|
| AppButton | `common/buttons/app_button.dart` | `text`, `onPressed`, `type`, `isLoading`, `icon` | `AppButton(text: 'Save', onPressed: () {})` |
| AppTextField | `common/inputs/app_text_field.dart` | `label`, `hint`, `controller`, `validator` | `AppTextField(label: 'Email', controller: ...)` |
| AppCard | `common/cards/app_card.dart` | `child`, `onTap`, `type` | `AppCard(child: Text('Content'))` |
| StatusBadge | `common/badges/status_badge.dart` | `status` | `StatusBadge(status: StatusType.ongoing)` |
| TaskListItem | `common/list_items/task_list_item.dart` | `title`, `subtitle`, `deadline`, `status`, `assigneeName`, `onTap` | See Component Architecture |
| **TaskCard** | **`home/widgets/task_card.dart`** | **`task`, `creator`** | **`TaskCard(task: taskModel, creator: userModel)`** |
| **TaskTile** | **`common/list_items/task_tile.dart`** | **`task`, `assignee`, `creator`, `remarksCount`, `onTap`** | **Modern task tile with status, deadline, assignee info** |

### Utilities Catalog

| Utility | File | Purpose | Key Methods |
|---------|------|---------|-------------|
| **PermissionUtils** | **`core/utils/permission_utils.dart`** | **Role-based access control** | **`canCreateTeam()`, `canApproveUsers()`, `canManageUsers()`** |

### Services Catalog

| Service | File | Purpose | Key Methods |
|---------|------|---------|-------------|
| **FCMService** | **`data/services/fcm_service.dart`** ✅ | **Firebase Cloud Messaging** | **`initialize()`, `reset()`, `requestPermission()`** |
| **CalendarService** | **`data/services/calendar_service.dart`** ✅ | **Google Calendar integration** | **`connect()` (saves accessToken + refreshToken to Firestore), `disconnect()`, `createTaskEvent()`, `updateTaskEvent()`, `deleteTaskEvent()`** |
| **NotificationService** | **`data/services/notification_service.dart`** ✅ | **Local notifications** | N/A |

### Repositories Catalog

| Repository | File | Purpose | Key Methods |
|------------|------|---------|-------------|
| **AuthRepository** | **`data/repositories/auth_repository.dart`** ✅ | **Firebase Auth operations** | **`signInWithGoogle()`, `signInWithApple()`, `signOut()`** |
| **UserRepository** | **`data/repositories/user_repository.dart`** ✅ | **Firestore user CRUD** | **`getUserStream()`, `getUser()`, `createUser()`, `updateUser()`** |
| **TeamRepository** | **`data/repositories/team_repository.dart`** ✅ | **Firestore team CRUD** | **`getTeamStream()`, `createTeam()`, `updateTeam()`, `getAllTeamsStream()`** |
| **TaskRepository** | **`data/repositories/task_repository.dart`** ✅ | **Firestore task CRUD** | **`createTask()`, `getUserTasksStream()`, `completeTask()`, `cancelTask()`, `getAllTasksStream()`** |
| **ApprovalRepository** | **`data/repositories/approval_repository.dart`** ✅ | **Reschedule requests** | **`createRescheduleRequest()`, `approveRescheduleRequest()`, `rejectRescheduleRequest()`, `getAllRescheduleRequestsStream()`, `getPendingRescheduleRequestsStream(taskCreatorId)` (queries by `payload.taskCreatorId`)** |
| **NotificationRepository** | **`data/repositories/notification_repository.dart`** ✅ | **In-app notifications** | **`getUserNotificationsStream()`, `createNotification()`, `markAsRead()`, `getUnreadCountStream()`** |

### Common Code Patterns

**Firebase Authentication**:
```dart
// In LoginScreen
Future<void> _handleGoogleSignIn() async {
  try {
    await context.read<AuthProvider>().signInWithGoogle();
    // Auto-navigates via GoRouter redirect
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sign-in failed: $e')),
    );
  }
}
```

**Access Firestore Data**:
```dart
// Stream-based (real-time)
final authProvider = context.watch<AuthProvider>();
final currentUser = authProvider.currentUser; // Updates automatically

// Repository pattern
final userRepo = UserRepository();
final userStream = userRepo.getUserStream(userId);

StreamBuilder<UserModel?>(
  stream: userStream,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return CircularProgressIndicator();
    final user = snapshot.data!;
    return Text('Hello, ${user.name}');
  },
)
```

**Navigation**:
```dart
// Navigate to route
context.go(AppRoutes.home);

// Navigate with params
context.go('${AppRoutes.teamManagement}/$teamId');

// Go back
context.pop();
```

**Access Auth State**:
```dart
// Get current user
final authProvider = context.read<AuthProvider>();
final user = authProvider.currentUser;

// Check authentication
if (authProvider.isAuthenticated) {
  // User is logged in
}

// Check role
if (authProvider.isSuperAdmin) {
  // Show admin features
}

// Check status
if (authProvider.isPending) {
  // User needs approval
}
```

**Sign Out**:
```dart
await context.read<AuthProvider>().logout();
// Auto-redirects to login via GoRouter
```

**Show Feedback**:
```dart
// Success message
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Success!'), backgroundColor: Colors.green),
);

// Confirmation dialog
final confirm = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Confirm'),
    content: const Text('Are you sure?'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
    ],
  ),
);
```

**Form Validation**:
```dart
final _formKey = GlobalKey<FormState>();

// In build
Form(
  key: _formKey,
  child: AppTextField(
    validator: (value) {
      if (value == null || value.isEmpty) return 'Required';
      return null;
    },
  ),
)

// On submit
if (_formKey.currentState?.validate() ?? false) {
  // Proceed
}
```

**Theme Access**:
```dart
final theme = Theme.of(context);
final isDark = theme.brightness == Brightness.dark;
final primaryColor = theme.colorScheme.primary;
final textColor = isDark ? AppColors.neutral300 : AppColors.neutral700;
```

---

## 15. Maintenance Guidelines

**Updating CodeMap**:
- Update when adding new modules or changing architecture.
- Increment version number at top.
- Review `Pre-Production Checklist` before every release.

---

## 16. Critical Information for AI/Developers

> [!CAUTION]
> **PRE-PRODUCTION CHECKLIST (MUST COMPLETE)**

### 🔥 Firebase Configuration
- [x] **`lib/firebase_options.dart`**: Replace ALL placeholder API keys.
- [x] **Android**: Add `google-services.json`.
- [x] **iOS**: Add `GoogleService-Info.plist`.
- [x] **Backend**: Set `app.super_admin_email` to `div.makar@gmail.com`.

### 🔐 Environment Variables
- [x] **`.env`**: Update `SUPER_ADMIN_EMAILS` (comma-separated for multiple admins).
- [ ] **`.env`**: Set `ENV=production` before app store release.

### 📦 Bundle Identifier
- [ ] Update `applicationId` (Android) and Bundle ID (iOS) for production.

### 🎨 Assets (Before App Store Submission)
- [ ] Add custom App Icon (iOS/Android).
- [ ] Add custom Splash Screen.
- [ ] Add App Logo for various sizes.
- [ ] Prepare App Store Screenshots (6.7", 5.5" iPhone, Android).
- [ ] Prepare App Store Feature Graphic (Android).

### 📄 Legal (Before App Store Submission)
- [ ] Create Privacy Policy page/URL.
- [ ] Create Terms of Service page/URL.

### 🔒 Signing & Certificates (Before App Store Submission)
- [ ] **iOS**: Apple Developer Account ($99/year).
- [ ] **iOS**: Create App ID and Provisioning Profiles.
- [ ] **iOS**: Configure APNs for push notifications.
- [ ] **Android**: Generate release keystore.
- [ ] **Android**: Configure signing in `build.gradle`.

### 📊 Monitoring
- [ ] Enable Firebase Crashlytics.
- [ ] Set up Cloud Logging alerts.

### 🔧 Android Configuration (Updated Nov 27, 2025)
- **Core Library Desugaring**: Enabled in `android/app/build.gradle.kts` for `flutter_local_notifications` dependency
- **desugar_jdk_libs**: Version 2.1.4 added as dependency

### ⚡ Performance Optimizations (Updated Nov 27, 2025)
- **Stream Caching**: Screens converted to StatefulWidget with cached streams in `initState()` to avoid recreating subscriptions on rebuild
- **Repository Caching**: Repository instances cached as class fields instead of creating in `build()` method
- **N+1 Query Fix**: User data prefetched in batch using `_prefetchUsers()` instead of individual StreamBuilders per task
- **Responsive UI**: Stats grid uses adaptive `childAspectRatio` based on screen width with `FittedBox` for text scaling
- **Affected Files**: `admin_dashboard_screen.dart`, `home_screen.dart`, `reschedule_approval_screen.dart`

### 🔔 Push Notifications (Updated Nov 27, 2025)
- **FCM Service**: `lib/data/services/fcm_service.dart` - Handles token registration and permissions
- **Backend**: `src/services/notificationService.ts` - Sends push via Firebase Admin SDK
- **Token Storage**: FCM token stored in user document field `fcmToken`
- **Debug Tool**: Settings → "Test Push Notification" shows FCM diagnostic info
- **Troubleshooting**: Check Firebase Console → Functions logs for "Notification sent to user" messages
- **Android Permissions**: Added `POST_NOTIFICATIONS`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED` in `AndroidManifest.xml`
- **iOS Config**: Added `UIBackgroundModes` (fetch, remote-notification) in `Info.plist`

### 🔐 Role-Based Navigation (Updated Nov 27, 2025)
- **MainLayout**: `lib/presentation/navigation/main_layout.dart` now checks user role
- **Super Admin**: Dashboard tab → `/admin` (AdminDashboardScreen)
- **Members/Team Admin**: Dashboard tab → `/` (HomeScreen), label shows "My Tasks"
- **Dynamic Labels**: Navigation labels change based on role

### 🗄️ Firestore Rules Fixes (Updated Nov 27, 2025)
- **Collection Names Fixed**: `approval_requests` and `reschedule_logs` (was `approvalRequests` and `rescheduleLog`)
- **Deploy Command**: `firebase deploy --only firestore:rules` from `todo-backend` directory

### 🎨 UI Improvements (Updated Nov 28, 2025)
- **Overview Cards**: Reduced padding (`xs`/`sm`), icon size (28px), increased aspect ratio (1.0-1.2) for compact look
- **Interactive Overview Cards**: All stat cards now navigate on tap:
  - Total Users → User Management
  - Active Teams → Team Management  
  - Pending Requests → User Approval
  - Total Tasks → All Tasks Screen (NEW)
- **Quick Action Badges**: Action cards now show real-time badge counts for:
  - Approve Requests: pending user count
  - Reschedule Requests: pending reschedule count
  - Overdue Tasks: overdue task count (red badge)
- **My Tasks for Super Admin**: New action card in admin dashboard
- **Add Remark Dialog**: Fixed with `ConstrainedBox`, `SingleChildScrollView`, proper `insetPadding`
- **Files Modified**: `admin_dashboard_screen.dart`, `add_remark_dialog.dart`

### 📄 New Screens (Added Nov 28, 2025)
- **AllTasksScreen**: `lib/presentation/admin/all_tasks_screen.dart`
  - Displays all tasks with filter tabs (All, Ongoing, Completed, Cancelled)
  - Route: `/admin/all-tasks`
- **UserTaskSummaryScreen**: `lib/presentation/admin/user_task_summary_screen.dart`
  - Displays user info card, task stats (Total, Ongoing, Done, Overdue), and task list
  - Route: `/admin/users/:id/tasks`
  - Accessible from User Management by tapping a user or "View Tasks" in menu

### 🔗 New Routes (Added Nov 28, 2025)
- `AppRoutes.allTasks`: `/admin/all-tasks`
- `AppRoutes.userTaskSummary`: `/admin/users/:id/tasks`
- `AppRoutes.adminMyTasks`: `/admin/my-tasks` (reuses HomeScreen)

### 🐛 Bug Fixes (Nov 28, 2025)
- **Route Fix**: Changed `/home/task/:id` to `/task/:id` across all screens
  - Fixed in: `all_tasks_screen.dart`, `user_task_summary_screen.dart`, `overdue_tasks_screen.dart`, `calendar_view_screen.dart`, `notification_center_screen.dart`, `task_detail_screen.dart`
- **Badge Counts Added**:
  - My Tasks action card in Admin Dashboard shows ongoing task count (blue)
  - Reschedule Requests clock icon in HomeScreen shows pending count (orange)
- **Firestore Rules**: Added `notifications` collection rules for user-specific access

### 📱 Self-Assigned Tasks Behavior
- **Notification**: YES - Assignee gets notification even if they are the creator
- **Calendar**: Only if Google Calendar is connected in Settings
- **Tracking Issues**: Check Firebase Console → Cloud Functions logs for errors

### 🔔 Android Notification Permission Fix (Nov 28, 2025)
- **Issue**: Android 13+ requires explicit `POST_NOTIFICATIONS` permission request
- **Fix**: 
  - Modified `FCMService.initialize()` to use `Permission.notification.request()` on Android
  - Added `PERMISSION_HANDLER_NOTIFICATION=true` to `android/gradle.properties`
- **Files Modified**: `fcm_service.dart`, `gradle.properties`

### 🌏 Region Configuration (Dec 1, 2025)
- **All Cloud Functions** now use `asia-south1` (Mumbai) region
- **Flutter App** configured in `cloud_functions_service.dart`:
  ```dart
  final FirebaseFunctions _functions = 
      FirebaseFunctions.instanceFor(region: 'asia-south1');
  ```
- **Important**: After deploying new backend functions, the old `us-central1` functions should be deleted from Firebase Console

### ⚡ Performance Optimizations (Dec 1, 2025)
- Team task assignments now send notifications in parallel
- Deadline reminder checks process in parallel batches
- Streams are cached in screens to avoid recreating subscriptions

### 📧 Invite Users Module (Dec 1, 2025) - NO Deep Linking
- **New Screen**: `InviteUsersScreen` at `/admin/invites`
- **Features**:
  - Send email invitations to new users
  - Optionally select team to mention in email (no auto-assignment)
  - View all invites with status filtering (Pending/Accepted/Expired/Cancelled)
  - Resend or cancel pending invites
- **User Flow**:
  1. Admin sends invite → Email with Play Store link sent
  2. User downloads app from Play Store
  3. User signs up with invited email
  4. **Auto-approved by backend** (no manual approval needed)
  5. User becomes active member (no team assignment)
  6. Admin can manually add user to team later
- **Files Created**:
  - `lib/data/models/invite_model.dart` - Invite data model
  - `lib/presentation/admin/invite_users_screen.dart` - Invite UI with updated messaging
  - `lib/data/services/cloud_functions_service.dart` - Added invite methods
- **Files Modified**:
  - `lib/core/constants/app_routes.dart` - Added `/admin/invites` route
  - `lib/core/router/app_router.dart` - Added route configuration
  - `lib/presentation/admin/admin_dashboard_screen.dart` - Added "Invite Users" card
- **Navigation**: Admin Dashboard → "Invite Users" action card
- **Important**: 
  - No deep linking implemented
  - Team selection only mentions team in email, does NOT auto-assign
  - Auto-approval handled entirely by backend auth trigger
  - Email sending requires backend SendGrid configuration

### 🔧 Multi Super Admin Support (Dec 6, 2025)
- **EnvConfig Updated**: `lib/core/constants/env_config.dart`
  - Supports comma-separated emails in `SUPER_ADMIN_EMAILS`
  - New methods: `superAdminEmails` (List), `isSuperAdminEmail(email)` (bool)
  - Backward compatible with legacy `SUPER_ADMIN_EMAIL`
- **Current Super Admins**: `div.makar@gmail.com`, `ritesh@assomac.in`

### 🔐 Team Creation Permission Update (Dec 6, 2025)
- **Change**: `canCreateTeam` now allows both Super Admin AND Team Admin
- **File Modified**: `lib/core/utils/permission_utils.dart`
- **Impact**: Team Admins can now create teams via Team Management FAB

### 🔍 Searchable Assignee Dropdown (Dec 6, 2025)
- **Feature**: Create Task screen now has searchable assignee selection
- **File Modified**: `lib/presentation/tasks/create_task_screen.dart`
- **Implementation**: Uses Flutter `Autocomplete` widget with:
  - Search by name or email
  - Displays first 20 users when empty, limits to 50 filtered results
  - Custom options view with avatar, name, and email
  - Clear button to reset selection
- **Performance**: Optimized for 100+ users

### 🚫 Access Revoked Screen (Dec 6, 2025)
- **New Screen**: `lib/presentation/auth/access_revoked_screen.dart`
- **Route**: `/access-revoked` (`AppRoutes.accessRevoked`)
- **Behavior**: When user's status is `revoked`:
  - Shows Access Revoked screen instead of force logout
  - Displays message to contact Super Admin
  - Logout button available
- **Files Modified**:
  - `lib/core/constants/app_routes.dart` - Added route constant
  - `lib/core/router/app_router.dart` - Added route and redirect logic

### 👤 User Management Cloud Functions Integration (Dec 6, 2025)
- **Change**: User Management screen now uses Cloud Functions instead of direct Firestore updates
- **Benefits**:
  - Role changes trigger notifications to affected users
  - Firebase Auth custom claims are properly updated
  - Team admin cleanup runs when demoting team admins
  - Firebase Auth account is disabled/re-enabled on revoke/restore
- **Files Modified**:
  - `lib/presentation/admin/user_management_screen.dart` - Uses `CloudFunctionsService` for:
    - `updateUserRole()` - Role promotion/demotion with notification
    - `revokeUserAccess()` - Access revocation with notification + Auth disable
    - `restoreUserAccess()` - Access restoration with notification + Auth re-enable
  - `lib/data/services/cloud_functions_service.dart` - Added `restoreUserAccess()` method
- **Backend Updates Required**:
  - `src/triggers/authTriggers.ts` - Supports comma-separated super admin emails
  - `src/controllers/userController.ts` - Added `restoreUserAccess` function
  - `src/index.ts` - Exports `restoreUserAccess`
- **Firebase Config Required**:
  ```bash
  firebase functions:config:set app.super_admin_email="div.makar@gmail.com,ritesh@assomac.in"
  firebase deploy --only functions
  ```

### 📋 Task Creation & Display Improvements (Dec 12, 2025)

#### Multiple Assignees Support
- **Feature**: Create Task now supports selecting multiple individual assignees
- **Backend Change**: `assignTask` function in `src/controllers/taskController.ts` now accepts `assignedTo` as `string | string[]`
- **Behavior**: When multiple assignees selected, creates separate tasks for each (similar to team assignment)
- **Files Modified**:
  - `lib/presentation/tasks/create_task_screen.dart` - Multi-select with chips UI
  - `lib/data/services/cloud_functions_service.dart` - `assignedTo` accepts dynamic (String or List)
  - `todo-backend/src/types/index.ts` - Updated `AssignTaskInput` type
  - `todo-backend/src/controllers/taskController.ts` - Handles array of assignees

#### Created Tab Assignee Display
- **Feature**: 'Created' tab now shows assignee name instead of creator name
- **Files Modified**:
  - `lib/presentation/home/widgets/task_card.dart` - Added `assignee`, `showAssignee` props
  - `lib/presentation/home/home_screen.dart` - Passes `showAssignee: true` for Created tab

#### Completed Task Timestamps
- **Feature**: Completed tasks now display both deadline and completion timestamp
- **TaskModel Update**: Added `completedAt` and `completionRemark` fields
- **UI**: Shows "Completed on time" or "Completed after deadline" indicator
- **Files Modified**:
  - `lib/data/models/task_model.dart` - Added `completedAt`, `completionRemark`
  - `lib/presentation/tasks/task_detail_screen.dart` - Deadline info card with completion details

#### Task Creation Validation Improvements
- **Change**: Removed optimistic update pattern from task creation
- **Behavior**: Now waits for server confirmation before showing success
- **Validation**: Added check to prevent selecting past deadline time
- **Files Modified**:
  - `lib/presentation/tasks/create_task_screen.dart` - Synchronous submission with loading state

### 📊 Dashboard & Task Display Improvements (Dec 12, 2025)

#### Dashboard Active Tasks
- **Change**: Dashboard stat card now shows 'Active Tasks' instead of 'Total Tasks'
- **Behavior**: Only counts ongoing tasks, not completed/cancelled
- **Files Modified**:
  - `lib/presentation/admin/admin_dashboard_screen.dart` - Uses `getAllActiveTasksStream()`
  - `lib/data/repositories/task_repository.dart` - Added `getAllActiveTasksStream()` method

#### Task Tiles Show Creator & Assignee
- **Feature**: Task cards now show both creator and assignee info
- **UI**: New row with "Created by → Assigned to" format
- **Files Modified**:
  - `lib/presentation/home/widgets/task_card.dart` - Shows both creator and assignee
  - `lib/presentation/home/home_screen.dart` - Always prefetches both user types

#### User Filter for Task Tabs
- **Feature**: Each tab (Ongoing, Past, Created) has a filter dropdown
- **Behavior**: Filter by assignee - shows count per user, supports "All assignees"
- **Files Modified**:
  - `lib/presentation/home/home_screen.dart` - Added `_buildFilterableTaskList()` with filter state

### 👥 Super Admin Team Creation Fix (Dec 12, 2025)
- **Bug Fixed**: Super Admin was auto-added as Team Admin to every team they created
- **New Behavior**: 
  - Super Admin selects members first
  - Then selects one of the members as Team Admin
  - Super Admin is NOT auto-added to the team
- **Files Modified**:
  - `lib/presentation/admin/create_team_screen.dart` - Added Team Admin dropdown selector

### 📅 Calendar Integration - Server Auth Code Flow (Dec 12, 2025)

#### Problem Solved
The previous implementation stored `idToken` as `googleRefreshToken`, which is incorrect.
`idToken` is a JWT for identity verification, NOT a refresh token. This caused:
- Calendar operations failing after ~1 hour (access token expiry)
- Backend unable to refresh tokens when app is closed

#### Solution: Server Auth Code Flow
```
1. App gets serverAuthCode via GoogleSignIn (with serverClientId)
2. App sends serverAuthCode to backend Cloud Function
3. Backend exchanges it for REAL access_token + refresh_token
4. Backend stores tokens in Firestore
5. Backend can now auto-refresh tokens anytime (even if app closed)
```

#### Files Modified
**Backend:**
- `src/services/calendarService.ts` - Added `exchangeCalendarAuthCode` Cloud Function
- `src/index.ts` - Exported new function

**Frontend:**
- `lib/data/services/calendar_service.dart`:
  - Added `serverClientId` configuration for auth code flow
  - Updated `connect()` to use serverAuthCode and call backend
  - Removed incorrect `idToken` storage as refresh token
  - Added `_saveLocalTokens()` fallback method
- `lib/data/services/cloud_functions_service.dart` - Added `exchangeCalendarAuthCode()`

#### Configuration
The Web Client ID is automatically read from `google-services.json` (`client_type: 3`).
No additional configuration needed - it's hardcoded in `calendar_service.dart`.

#### Existing Tasks Sync
When a user connects their calendar, all existing ongoing tasks are automatically
synced to Google Calendar (runs in background after token exchange).

#### Other Fixes
- Fixed timezone hardcoding to use device timezone (`DateTime.now().timeZoneName`)

### 📄 PDF Report Enhancement & Delete Account (Dec 13, 2025)

#### PDF Report Improvements
- **Enhanced Design**: Professional card-based layout with status badges
- **More Details**: Task subtitle, completion date, created date, overdue indicators
- **Summary Cards**: Total tasks, completed %, in progress, overdue count
- **Files Modified**:
  - `todo-backend/src/controllers/reportController.ts` - Complete redesign of `generateTasksPDF()`

#### Export Report Flow Simplified
- **Direct Download**: No confirmation dialog - exports directly on tap
- **System Notification**: Shows download notification in notification bar
- **Save Location**: Saves to `Todo Manager` folder at root of internal storage (Android)
- **Files Modified**:
  - `lib/presentation/admin/widgets/export_report_dialog.dart` - Added notification, direct download
  - `pubspec.yaml` - Added `open_filex` package

#### Delete Account Feature (Play Store Compliance)
- **New Feature**: Users can delete their own account from Settings
- **Double Confirmation**: Requires typing "DELETE" to confirm
- **Cleanup**: Deletes user data, cancels tasks, removes from teams
- **Files Modified**:
  - `lib/presentation/settings/settings_screen.dart` - Added Account section with delete button
  - `lib/data/services/cloud_functions_service.dart` - Added `deleteOwnAccount()`
  - `todo-backend/src/controllers/userController.ts` - Added `deleteOwnAccount` Cloud Function
  - `todo-backend/src/config/constants.ts` - Added `NOTIFICATIONS` collection
  - `todo-backend/src/index.ts` - Exported new function

### 📧 Invite System UX Improvements (Dec 13, 2025)

#### Auto-Expire Pending Invites
- **Backend**: `getInvites` now auto-marks expired pending invites
- **Frontend**: Displays "Expired" status for pending invites past expiration date
- **Files Modified**:
  - `todo-backend/src/controllers/inviteController.ts` - Added auto-expire in `getInvites`

#### Per-Item Loading State for Cancel/Resend
- **Before**: Whole list refreshed with loading indicator when canceling
- **After**: Only the specific invite shows loading indicator
- **Optimistic Update**: Cancelled invite updates immediately in UI
- **Files Modified**:
  - `lib/presentation/admin/invite_users_screen.dart`:
    - Added `_processingInviteIds` Set for per-item tracking
    - Updated `_cancelInvite` for optimistic update
    - Updated `_resendInvite` with loading state
    - Updated `_buildInviteCard` with loading indicator and expired detection

### 📅 Calendar Integration Improvements (Dec 16, 2025)

Backend changes improve calendar event handling for multi-assignee tasks and token management:

#### Token Preservation on Disconnect
- Disconnect now only sets `googleCalendarConnected: false`
- Tokens preserved for seamless reconnect (no re-authentication needed)
- Tokens only deleted on account deletion

#### Multi-Assignee Calendar Event Updates
- `updateTask` now iterates assignments and updates each assignee's calendar event
- Previously only single-assignee tasks had their calendar events updated

#### Stale Event ID Cleanup
- Calendar event IDs cleared from Firestore after successful deletion
- Prevents orphan references in task/assignment documents

#### Less Aggressive Auth Error Handling
- Only resets connection for true auth errors (401, invalid_grant)
- Rate-limits (429) and quota errors (403) no longer trigger reconnect

**Frontend Impact**: None - existing `calendar_service.dart` already delegates to backend Cloud Functions.

**Backend Files Modified**:
- `src/services/calendarService.ts` - Token preservation, auth error handling
- `src/controllers/taskController.ts` - Multi-assignee updates, event ID cleanup

### 🎨 Task Detail People Section UI Fix (Dec 16, 2025)

Fixed layout issue in the "People" section of Task Detail screen where assignee/creator name and avatar had poor alignment with long names.

#### Problem
- Avatar appeared between label and name, creating visual disconnect
- Long names would overflow or break the layout
- Name and role text were misaligned with the avatar

#### Solution
- Moved avatar to the **right** of the name/role column
- Wrapped user info in `Flexible` widget to handle long names
- Added `maxLines: 1` and `overflow: TextOverflow.ellipsis` to name text
- Increased spacing between name column and avatar

#### Files Modified
- `lib/presentation/tasks/task_detail_screen.dart`
  - `_buildCompactUserRow()` method - Restructured layout

### 🔧 Bug Fixes & UI Improvements (Dec 16, 2025 - v1.0.10)

#### Issue 2: Task Details Name Overflow Fix
- Changed `_buildCompactUserRow()` layout to use fixed-width label (100px) and `Expanded` for user info
- Names now have more space and won't be truncated too aggressively

#### Issue 3: Swipeable Tabs in All Tasks Screen
- Wrapped body content in `TabBarView` for swipe navigation between tabs
- Removed manual `onTap` callback since TabBarView handles tab changes

#### Issue 4: Keyboard Auto-Open After Assignee Selection
- Added `FocusManager.instance.primaryFocus?.unfocus()` after returning from AssigneeSelectionScreen
- Prevents keyboard from auto-opening on Description field

#### Issue 5: Supervisor IDs Not Cleared on Assignment Type Change
- Added `_supervisorIds.clear()` in `onSelectionChanged` callback of SegmentedButton
- Prevents stale supervisor tags from persisting when switching between Member/Team/Self

#### Issue 6: Multi-Assignee Tasks - People Section & Permissions
- Added Firestore rules for `tasks/{taskId}/assignments/{assignmentId}` subcollection
- Modified People section to show ALL assignees for multi-assignee tasks (not just primary)
- Supervisors now shown with supervisor icon in the assignee list

#### Files Modified
- `lib/presentation/tasks/task_detail_screen.dart`
  - `_buildCompactUserRow()` - Fixed layout for better name display
  - People section - Now shows all assignees for multi-assignee tasks
- `lib/presentation/admin/all_tasks_screen.dart`
  - Added `TabBarView` for swipeable tabs
- `lib/presentation/tasks/create_task_screen.dart`
  - Clear `_supervisorIds` on assignment type change
  - Unfocus after assignee selection
- `firestore.rules`
  - Added rules for assignments subcollection

### 🔐 Auth & Splash Screen Fix (Dec 16, 2025 - v1.0.11)

#### Problem
When app opened, even logged-in users saw the login page and had to tap "Continue with Google" because:
- `_isLoading` started as `false`
- Router saw `isLoading=false` + `isAuthenticated=false` (user data not loaded yet)
- Router immediately redirected to login instead of showing splash while checking auth

#### Solution
Changed `_isLoading` initial value to `true` in `AuthProvider`:
- App starts with splash screen visible
- Firebase auth state is checked in background
- If logged in → user data loads → redirects to home
- If not logged in → `_clearUser()` sets `_isLoading=false` → redirects to login

#### Files Modified
- `lib/data/providers/auth_provider.dart`
  - Changed `_isLoading = false` to `_isLoading = true`

### 🔐 Auth Persistence Fix v2 (Dec 17, 2025)

#### Problem
Despite the v1.0.11 fix, users still saw the login page on app relaunch because:
- `authStateChanges` stream fires `null` before Firebase finishes restoring persisted credentials
- `isAuthenticated` was based on Firestore `_currentUser` (not Firebase auth state)
- App concluded "no session" before Firebase had a chance to restore it

Cold-start logs showed:
```
🔓 Initial auth check: No active session
🔀 Router Redirect - Path: /, Auth: false, Loading: false, User: null
🔀 Not authenticated, redirecting to login
```

#### Root Cause
Firebase Auth restores sessions asynchronously from disk. Subscribing to `authStateChanges` immediately may receive `null` before restoration completes.

#### Solution
1. **Track Firebase auth separately**: Added `_firebaseUser` field in `AuthProvider`
2. **Synchronous check first**: Check `currentFirebaseUser` BEFORE subscribing to stream
3. **Updated `isAuthenticated`**: Now returns `_firebaseUser != null` (Firebase auth presence, not Firestore user)
4. **Auth bootstrap + silent Google restore**: If no restored Firebase session is found, keep splash visible and attempt to restore session via `GoogleSignIn.signInSilently()` and re-authenticate Firebase.

Auth flow now:
1. App starts → `_isLoading = true` → splash screen shown
2. `_initAuthListener()` checks `currentFirebaseUser` synchronously
3. If user found → sets `_firebaseUser` + loads Firestore data
4. Router sees `isAuthenticated=true` + `currentUser=null` → stays on splash
5. Firestore data loads → `currentUser` populated → redirects to home
6. If no Firebase user restored → `_bootstrapInitialAuth()` attempts silent Google Sign-In
7. If silent Google Sign-In restores a user → Firebase user set + Firestore loads → redirects to home
8. If no session after bootstrap → `_clearUser()` → redirects to login

#### Files Modified
- `lib/data/providers/auth_provider.dart`
  - Added `_firebaseUser` field to track Firebase auth state
  - Added `firebaseUser` getter
  - Updated `isAuthenticated` to use `_firebaseUser != null`
  - Rewrote `_initAuthListener()` to check `currentFirebaseUser` first
  - Updated `_clearUser()` to also clear `_firebaseUser`
  - Added `_isBootstrappingAuth` + `_bootstrapInitialAuth()` to prevent premature logout and restore session via silent Google Sign-In
- `lib/data/repositories/auth_repository.dart`
  - Added `signInWithGoogleSilently()` to restore a Google session and re-authenticate Firebase without user interaction

### 📄 Report Export Android Storage Fix (Dec 16, 2025 - v1.0.11)

#### Problem
Report export failed on Android 11+ with:
```
PathAccessException: Creation failed, path = '/storage/emulated/0/Todo Manager'
(OS Error: Permission denied, errno = 13)
```
Android 11+ Scoped Storage restrictions prevent apps from writing to arbitrary external storage locations.

#### Solution
Changed `_getReportDirectory()` to use app-specific external storage instead:
- Uses `getExternalStorageDirectory()` which returns `/storage/emulated/0/Android/data/<package>/files/`
- Creates `Reports` subfolder within app's external storage
- No special permissions required
- Files survive app updates but are deleted on uninstall

#### Files Modified
- `lib/presentation/admin/widgets/export_report_dialog.dart`
  - Updated `_getReportDirectory()` to save to public Downloads folder (`/storage/emulated/0/Download`)
  - Added storage permission request for Downloads folder access
  - Download notification appears in notification bar when report is saved

---

### 📄 Report PDF & TaskTile Overdue Fix (Dec 16, 2025 - v1.0.12)

#### Problems
1. **PDF Report text overlapping**: Bottom info row (Assignee, Deadline, Created, Completed) was stacking on top of each other
2. **PDF Report task ordering**: Tasks appeared in random order instead of Ongoing → Completed → Cancelled
3. **TaskTile overdue indicator**: "X days overdue" was showing for Completed/Cancelled tasks in admin All Tasks view

#### Solutions
1. **Backend PDF layout fix** (`todo-backend/src/controllers/reportController.ts`):
   - Changed bottom info from single row to two rows to avoid overlap
   - Row 1: Assignee (left) + Deadline (right)
   - Row 2: Completed date (left) + Created date (right)
   - Increased card height from 85px to 100px to accommodate

2. **Backend task sorting** (`todo-backend/src/controllers/reportController.ts`):
   - Added status-based sorting: ongoing (0) → completed (1) → cancelled (2)
   - Within same status, tasks sorted by deadline (most recent first)

3. **Frontend overdue fix** (`lib/presentation/common/list_items/task_tile.dart`):
   - Modified `_formatDeadline()` to only show "X days overdue" for ongoing tasks
   - Completed/Cancelled tasks now show regular date format instead

#### Files Modified
- `todo-backend/src/controllers/reportController.ts` - PDF layout and task sorting
- `lib/presentation/common/list_items/task_tile.dart` - Overdue text logic

---

**Top-Level Rules**:
1. **Absolute Paths**: Always use absolute paths for file operations.
2. **Design System**: Strictly follow `design_system.md`.
3. **State Management**: Use Provider; avoid `setState` for complex state.
4. **Async/Await**: Handle all Futures properly; show loading states.

