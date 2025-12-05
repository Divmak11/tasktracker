# TODO Planner - CodeMap & Technical Reference

**Version:** 1.0.0  
**Last Updated:** 2025-11-24  
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

#### Tasks Collection
**Path:** `/tasks/{taskId}`
- `id` (string): UUID
- `title` (string): Task title
- `subtitle` (string): Description
- `assignedTo` (string): User ID or Team ID
- `assignedType` (string): 'member' | 'team'
- `status` (string): 'ongoing' | 'completed' | 'cancelled'
- `deadline` (timestamp): Due date
- `calendarEventId` (string): Google Calendar Event ID

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
- `UserModel`: id, name, email, role, teamIds, status, calendar tokens
- `TeamModel`: id, name, adminId, memberIds, createdBy
- `TaskModel`: id, title, subtitle, assignedType, assignedTo, status, deadline
- `RemarkModel`: id, taskId, userId, message
- `ApprovalRequestModel`: id, type, requesterId, targetId, payload, status
- `RescheduleLogModel`: id, taskId, requestedBy, deadlines, approvedBy

**Error Handling**:
- Repositories catch Firebase exceptions and throw custom `AppException`.
- UI catches `AppException` and shows `SnackBar` or `AlertDialog`.

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
- `RequestPendingScreen` - Approval waiting state
- `OnboardingScreen` - 3-step PageView flow

**Admin Module** (`presentation/admin/`):
- `AdminDashboardScreen` - Stats overview + Quick Actions
- `TeamManagementScreen` - Team list with FAB (conditional)
- `CreateTeamScreen` - Team creation form
- `TeamDetailScreen` - Team members view
- `ApprovalQueueScreen` - **NEW** - Approve/reject pending users (Super Admin)
- `UserManagementScreen` - **NEW** - Manage all users, change roles (Super Admin)

**Task Module** (`presentation/tasks/`):
- `CreateTaskScreen` - Task form with date picker
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
  static bool canCreateTeam(UserRole? role)        // Super Admin only
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
  ↓ Check: user.status == 'pending'?
  │   YES → Navigate to RequestPendingScreen
  │   NO → Continue
  ↓ Check: user.status == 'revoked'?
  │   YES → Force logout → Navigate to LoginScreen
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

**User Status Handling**:
- `pending`: Redirect to RequestPendingScreen (wait for admin approval)
- `active`: Allow app access
- `revoked`: Force logout and redirect to login

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

### Task Creation Flow (UI Only)
```
HomeScreen
  ↓ User taps FAB
  ↓ context.go('/task/create')
  ↓
CreateTaskScreen
  ↓ User fills form (title, description, deadline, assignee)
  ↓ User taps "Create Task"
  ↓ Validate form
  ↓ Currently: Mock delay → context.pop()
  ↓
Future: 
  ↓ TaskProvider.createTask(data)
  ↓ TaskRepository.create(task)
  ↓ Firestore creates document
  ↓ Cloud Function triggers → Create calendar event + Send notification
```

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
| `/request-pending` | RequestPendingScreen | Authenticated (pending) |
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
| **Auth Triggers** | `createUserProfile`, `onUserDeleted` |
| **Notification Triggers** | `notifyAdminNewUser`, `notifyUserStatusChange`, `notifyTeamCreation`, `notifyTeamMemberChange`, `notifyTaskAssignment`, `notifyTaskStatusChange` |
| **Scheduled** | `checkDeadlines`, `checkOverdueTasks`, `cleanupInactiveTracking` |

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
| Dashboard | `admin_dashboard_screen.dart` | Overview stats + Quick Actions (real-time) |
| Team Management | `team_management_screen.dart` | List all teams |
| Create Team | `create_team_screen.dart` | Team creation form |
| Team Detail | `team_detail_screen.dart` | View team members |
| **Edit Team** | **`edit_team_screen.dart`** | **Edit team name/members/admin** |
| **Approval Queue** | **`approval_queue_screen.dart`** | **Approve/reject pending users (Super Admin)** |
| **User Management** | **`user_management_screen.dart`** | **Manage all users, change roles (Super Admin)** |

**Tasks** (`lib/presentation/tasks/`):
| Screen | File | Purpose |
|--------|------|---------|
| Create Task | `create_task_screen.dart` | Task creation with member/team assignment |
| Task Detail | `task_detail_screen.dart` | View task info with conditional actions |
| **Edit Task** | **`edit_task_screen.dart`** | **Edit task title/description/deadline** |

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

### Utilities Catalog

| Utility | File | Purpose | Key Methods |
|---------|------|---------|-------------|
| **PermissionUtils** | **`core/utils/permission_utils.dart`** | **Role-based access control** | **`canCreateTeam()`, `canApproveUsers()`, `canManageUsers()`** |

### Services Catalog

| Service | File | Purpose | Key Methods |
|---------|------|---------|-------------|
| **FCMService** | **`data/services/fcm_service.dart`** ✅ | **Firebase Cloud Messaging** | **`initialize()`, `reset()`, `requestPermission()`** |
| **CalendarService** | **`data/services/calendar_service.dart`** ✅ | **Google Calendar integration** | **`connect()`, `disconnect()`, `createTaskEvent()`, `updateTaskEvent()`, `deleteTaskEvent()`** |
| **NotificationService** | **`data/services/notification_service.dart`** ✅ | **Local notifications** | N/A |

### Repositories Catalog

| Repository | File | Purpose | Key Methods |
|------------|------|---------|-------------|
| **AuthRepository** | **`data/repositories/auth_repository.dart`** ✅ | **Firebase Auth operations** | **`signInWithGoogle()`, `signInWithApple()`, `signOut()`** |
| **UserRepository** | **`data/repositories/user_repository.dart`** ✅ | **Firestore user CRUD** | **`getUserStream()`, `getUser()`, `createUser()`, `updateUser()`** |
| **TeamRepository** | **`data/repositories/team_repository.dart`** ✅ | **Firestore team CRUD** | **`getTeamStream()`, `createTeam()`, `updateTeam()`, `getAllTeamsStream()`** |
| **TaskRepository** | **`data/repositories/task_repository.dart`** ✅ | **Firestore task CRUD** | **`createTask()`, `getUserTasksStream()`, `completeTask()`, `cancelTask()`, `getAllTasksStream()`** |
| **ApprovalRepository** | **`data/repositories/approval_repository.dart`** ✅ | **Reschedule requests** | **`createRescheduleRequest()`, `approveRescheduleRequest()`, `rejectRescheduleRequest()`, `getAllRescheduleRequestsStream()`** |
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
- [x] **`.env`**: Update `SUPER_ADMIN_EMAIL`.
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

**Top-Level Rules**:
1. **Absolute Paths**: Always use absolute paths for file operations.
2. **Design System**: Strictly follow `design_system.md`.
3. **State Management**: Use Provider; avoid `setState` for complex state.
4. **Async/Await**: Handle all Futures properly; show loading states.

