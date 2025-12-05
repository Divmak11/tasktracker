# TODO Planner & Task Management - Detailed Task Breakdown

**Project**: TODO Planner & Task Management App (MVP - Phase 1)  
**Timeline**: 4-6 weeks  
**Stack**: Flutter (Frontend) + Firebase (Backend)

---

## Module 1: Authentication & Onboarding

### Backend Tasks
- [ ] **FB-AUTH-001**: Set up Firebase Authentication (Email/Password)
  - Configure Firebase project (Dev & Prod)
  - Enable Email/Password authentication method
  - Configure password requirements and security settings
  
- [ ] **FB-AUTH-002**: Create Cloud Function trigger for new user signup
  - `createUserProfile` function
  - Check if email matches Super Admin email from config
  - Create user document in Firestore with role and status
  - Create approval request if status is 'pending'
  
- [ ] **FB-AUTH-003**: Implement Super Admin notification system
  - Send FCM notification when new user requests access
  - Include user email and timestamp in notification payload

### Frontend Tasks
- [ ] **FE-AUTH-001**: Design and implement Login screen
  - Email input field (with validation)
  - Password input field (with show/hide toggle)
  - "Login" button
  - "Sign Up" link navigation
  - Error handling for invalid credentials
  
- [ ] **FE-AUTH-002**: Design and implement Signup screen
  - Name input field
  - Email input field (with validation)
  - Password input field (min 8 characters)
  - Confirm password field
  - "Sign Up" button
  - Navigate to "Request Pending" on success
  
- [ ] **FE-AUTH-003**: Implement "Request Pending" screen
  - Display pending status message
  - Show illustration/icon
  - "Logout" button
  - No navigation to other screens allowed
  
- [ ] **FE-AUTH-004**: Create onboarding flow (after approval)
  - Welcome screen
  - Permissions explanation screen (Push Notifications, Calendar)
  - Request notification permission
  - Prompt for Google Calendar connection (optional skip)
  - Navigate to homepage on completion
  
- [ ] **FE-AUTH-005**: Implement authentication state management
  - Listen to Firebase Auth state changes
  - Route to appropriate screen based on user status (pending/active)
  - Persist login state
  
- [ ] **FE-AUTH-006**: Add logout functionality
  - Sign out from Firebase Auth
  - Clear local state
  - Navigate to Login screen

### Acceptance Criteria
- ✓ New users can sign up and are shown "Request Pending"
- ✓ Super Admin receives notification for new user requests
- ✓ Approved users can log in and see onboarding
- ✓ Unapproved users cannot access app content

---

## Module 2: Roles & Access Control

### Backend Tasks
- [ ] **FB-ROLE-001**: Define Firestore security rules for role-based access
  - Super Admin can read/write all documents
  - Team Admin can read/write within their teams
  - Members can read/write only their assigned tasks
  
- [ ] **FB-ROLE-002**: Create approval/rejection Cloud Function
  - `approveUserAccess` callable function
  - Update user status to 'active'
  - Update approval request status
  - Send notification to approved user
  
- [ ] **FB-ROLE-003**: Create role change Cloud Function
  - `updateUserRole` callable function
  - Validate requester is Super Admin
  - Handle Team Admin demotion when promoting new admin
  - Update user role in Firestore
  
- [ ] **FB-ROLE-004**: Create user revoke/delete Cloud Function
  - `revokeUserAccess` / `deleteUser` functions
  - Auto-cancel all ongoing tasks assigned to deleted user
  - Update task creator references to show "[Deleted User]"
  - Remove user from all teams

### Frontend Tasks
- [ ] **FE-ROLE-001**: Create permission utility class
  - `canCreateTask()` - Returns true for all active users
  - `canCreateTeam()` - Super Admin only
  - `canApproveUsers()` - Super Admin only
  - `canPromoteTeamAdmin()` - Super Admin only
  - `canReopenTask()` - Super Admin only
  
- [ ] **FE-ROLE-002**: Implement role-based UI rendering
  - Conditionally show/hide features based on user role
  - Admin-only navigation items
  - Feature-gating for restricted actions
  
- [ ] **FE-ROLE-003**: Build approval queue screen (Super Admin)
  - List of pending user access requests
  - Show user email, request date
  - "Approve" and "Reject" buttons
  - Real-time updates when new requests arrive
  
- [ ] **FE-ROLE-004**: Create user management screen (Super Admin)
  - List all users with role badges
  - Filter by role (All, Super Admin, Team Admin, Member)
  - Actions: Change role, Revoke access, Delete user
  - Confirmation dialogs for destructive actions
  
- [ ] **FE-ROLE-005**: Implement Team Admin promotion flow
  - Display warning if existing Team Admin will be demoted
  - Confirmation dialog before promotion
  - Show success/error feedback

### Acceptance Criteria
- ✓ Role checks are enforced on frontend and backend
- ✓ Only Super Admin can approve users and change roles
- ✓ Team Admin cannot perform Super Admin actions
- ✓ Deleted users' tasks show "[User Name] [Deleted]"

---

## Module 3: Team Management

### Backend Tasks
- [ ] **FB-TEAM-001**: Create team creation Cloud Function
  - `createTeam` callable function
  - Validate requester is Super Admin
  - Create team document with name and members
  - Add team ID to all member users
  
- [ ] **FB-TEAM-002**: Create team update Cloud Function
  - `updateTeam` callable function (add/remove members)
  - Update team memberIds array
  - Update user teamIds arrays
  
- [ ] **FB-TEAM-003**: Create team deletion Cloud Function
  - `deleteTeam` callable function
  - Remove team ID from all member users
  - Auto-cancel all ongoing team tasks
  
- [ ] **FB-TEAM-004**: Implement Team Admin assignment logic
  - Validate only one Team Admin per team
  - Demote previous admin if promoting new one
  - Update team adminId field

### Frontend Tasks
- [ ] **FE-TEAM-001**: Build team creation screen (Super Admin only)
  - Team name input field
  - Member selection (multi-select from users list)
  - Team Admin selection (single select from chosen members)
  - "Create Team" button
  - Validation: At least 1 member required
  
- [ ] **FE-TEAM-002**: Create teams list screen
  - Display all teams user belongs to
  - Show team name, member count, Team Admin name
  - Navigate to team detail on tap
  
- [ ] **FE-TEAM-003**: Build team detail screen
  - Display team name and metadata
  - List all team members with avatars
  - Show Team Admin badge
  - Admin actions: Add/Remove members, Change Team Admin
  - View overall team task status (ongoing/completed count)
  
- [ ] **FE-TEAM-004**: Implement Team Admin promotion dialog
  - Alert: "Promoting [Name] will demote [Current Admin]. Continue?"
  - Confirm/Cancel buttons
  
- [ ] **FE-TEAM-005**: Add invite member to team flow
  - Email input field
  - Send invite email with team join link
  - Show pending invites list

### Acceptance Criteria
- ✓ Super Admin can create teams and assign Team Admins
- ✓ Only one Team Admin per team (with demotion warning)
- ✓ Team members can view their teams and team tasks
- ✓ Deleted teams auto-cancel ongoing tasks

---

## Module 4: Task CRUD & Assignment

### Backend Tasks
- [ ] **FB-TASK-001**: Implement `assignTask` Cloud Function
  - Validate title and deadline fields
  - Handle individual member assignment
  - Handle team assignment (create individual tasks for each member)
  - Store task in Firestore with status 'ongoing'
  
- [ ] **FB-TASK-002**: Integrate calendar event creation in `assignTask`
  - Check if assignee has Google Calendar connected
  - Call `createCalendarEvent` for each assignee
  - Save calendarEventId to task document
  - Send notification if calendar not connected
  
- [ ] **FB-TASK-003**: Implement task update Cloud Function
  - `updateTask` callable function
  - Allow creator or Super Admin to edit task
  - Update title, subtitle, deadline
  - Validate permissions before update
  
- [ ] **FB-TASK-004**: Implement task deletion/cancellation
  - `cancelTask` callable function
  - Update task status to 'cancelled'
  - Delete associated calendar event
  - Notify assignee of cancellation
  
- [ ] **FB-TASK-005**: Create task completion function
  - `completeTask` callable function
  - Allow only assignee to mark complete
  - Update task status to 'completed'
  - Add optional completion remark
  
- [ ] **FB-TASK-006**: Implement task reopen function (Admin only)
  - `reopenTask` callable function
  - Require new deadline when reopening
  - Update task status back to 'ongoing'
  - Create new calendar event
  - Notify assignee

### Frontend Tasks
- [x] **FE-TASK-001**: Build task creation screen
  - Title input field (required, max 100 chars)
  - Subtitle/description input (multiline, max 500 chars)
  - Assignment type toggle: "Member" or "Team"
  - Assignee dropdown (filtered based on type)
  - Deadline date and time picker
  - "Create Task" button
  - Loading state during creation
  
- [x] **FE-TASK-002**: Implement homepage task list
  - Fetch tasks where assignedTo = current user ID
  - Tab bar: Ongoing | Past (filter by status)
  - Display task cards with:
    - Title (bold, 1 line with ellipsis)
    - Deadline (formatted: "Due Nov 23, 3:00 PM")
    - Status badge (Ongoing/Overdue/Completed)
    - Creator avatar/name
  - Sort by deadline (ascending)
  - Pull-to-refresh functionality
  
- [x] **FE-TASK-003**: Design task card component
  - Reusable widget for task list items
  - Color-coded status indicator
  - Overdue tasks highlighted in red
  - Tap animation (scale down)
  - Navigate to task detail on tap
  
- [x] **FE-TASK-004**: Build task detail screen
  - Display full title and subtitle
  - Metadata section:
    - Assigned to (name + avatar)
    - Created by (name + avatar, show [Deleted] if user removed)
    - Deadline (formatted with countdown)
    - Status badge
  - Remarks section (collapsible)
  - Sticky bottom action bar
  
- [x] **FE-TASK-005**: Implement task detail action bar
  - "Add Remark" button → Opens remark input dialog
  - "Mark Complete" button (only if assignee and ongoing)
  - "Request Reschedule" button → Opens reschedule dialog
  - "Cancel Task" button (only if creator or admin)
  - "Reopen" button (admin only, if completed)
  
- [x] **FE-TASK-006**: Create task edit screen
  - Pre-fill form with existing task data
  - Allow editing title, subtitle, deadline
  - Cannot change assignee (show read-only)
  - "Save Changes" button
  - Validate creator or admin permissions
  
- [x] **FE-TASK-007**: Implement empty state for task list
  - Display when no tasks found
  - Illustration + message: "No tasks yet"
  - "Create Task" button (if user has permission)

### Acceptance Criteria
- ✓ Any user can create and assign tasks
- ✓ Assigning to team creates individual tasks for each member
- ✓ Each task displays assignee, deadline, and status
- ✓ Only assignee can mark task complete
- ✓ Only creator or admin can cancel/edit task
- ✓ Admin can reopen completed tasks with new deadline

---

## Module 5: Remarks & Comments

### Backend Tasks
- [x] **FB-REMARK-001**: Create add remark Cloud Function ✅
  - `addRemark` callable function
  - Validate user has permission (assignee, creator, or admin)
  - Create remark document in Firestore
  - Send notification to task participants
  
- [x] **FB-REMARK-002**: Implement remark visibility rules ✅
  - Security rules: Only assignee, creator, and admins can read remarks
  - Filter remarks by taskId

### Frontend Tasks
- [x] **FE-REMARK-001**: Build remarks section in task detail
  - Display all remarks for the task
  - Show commenter name, timestamp, message
  - Sort by creation time (newest first)
  - Real-time updates when new remarks added
  
- [x] **FE-REMARK-002**: Create add remark dialog
  - Text input field (multiline, max 300 chars)
  - Character counter
  - "Submit" button
  - Close dialog after submission
  
- [x] **FE-REMARK-003**: Implement remark list item design
  - Avatar + commenter name
  - Remark text
  - Timestamp (formatted: "2 hours ago")
  - Subtle border/divider between remarks

### Acceptance Criteria
- ✓ Only assignee, creator, and admins can view remarks
- ✓ Remarks display in chronological order
- ✓ All task participants can add remarks

---

## Module 6: Approval & Rescheduling Workflow

### Backend Tasks
- [x] **FB-RESCHEDULE-001**: Create reschedule request Cloud Function ✅
  - `requestReschedule` callable function
  - Validate user is the assignee
  - Create approval request document
  - Send notification to task creator (not admin)
  
- [x] **FB-RESCHEDULE-002**: Implement reschedule approval function ✅
  - `approveReschedule` callable function
  - Validate approver is task creator
  - Update task deadline if approved
  - Update calendar event to new deadline
  - Create reschedule log entry (for admin visibility)
  - Send notification to requester with result
  
- [ ] **FB-RESCHEDULE-003**: Create reschedule log for admin
  - Log all reschedule requests (approved/rejected)
  - Store original deadline, new deadline, dates
  - Allow Super Admin to query logs

### Frontend Tasks
- [x] **FE-RESCHEDULE-001**: Build reschedule request dialog
  - Current deadline display (read-only)
  - New deadline picker (must be later than current)
  - Reason text field (optional, max 200 chars)
  - "Submit Request" button
  - Validation: New deadline must be in future
  
- [x] **FE-RESCHEDULE-002**: Create approval screen (for task creators)
  - List of pending reschedule requests for tasks created by user
  - Display task title, current deadline, requested deadline, reason
  - "Approve" and "Reject" buttons
  - Real-time updates when new requests arrive
  
- [x] **FE-RESCHEDULE-003**: Build reschedule log screen (Super Admin)
  - List all reschedule requests (pending/approved/rejected)
  - Filter by status, team, date range
  - Show task title, requester, approver, old/new deadlines
  - Read-only view (admin cannot override, only monitor)
  
- [x] **FE-RESCHEDULE-004**: Add notification handling for reschedule results
  - Display toast/snackbar when request approved/rejected
  - Update task detail screen automatically

### Acceptance Criteria
- ✓ Reschedule requests sent to task creator (not admin)
- ✓ All reschedule requests logged for admin visibility
- ✓ Approved reschedules update task deadline and calendar event
- ✓ Assignee receives notification of approval/rejection

---

## Module 7: Google Calendar Integration

### Backend Tasks
- [ ] **FB-CAL-001**: Set up Google Calendar API credentials
  - Create OAuth 2.0 client ID in Google Cloud Console
  - Add calendar.events scope
  - Configure authorized redirect URIs
  
- [ ] **FB-CAL-002**: Implement calendar connection Cloud Function
  - `connectCalendar` callable function
  - Exchange authorization code for access/refresh tokens
  - Store tokens securely in user document
  - Update googleCalendarConnected flag
  
- [x] **FB-CAL-003**: Create calendar event creation service ✅
  - `createCalendarEvent` helper function
  - Check user has calendar connected
  - Use googleapis library to create event
  - Event includes: title, subtitle (description), deadline (start/end time)
  - Save eventId to task document
  - Handle token refresh if access token expired
  
- [x] **FB-CAL-004**: Implement calendar event update service ✅
  - `updateCalendarEvent` helper function
  - Patch event with new start/end times
  - Handle errors gracefully (notify user if failed)
  
- [x] **FB-CAL-005**: Create calendar disconnect function ✅
  - `disconnectCalendar` callable function
  - Fetch all user's tasks with calendarEventId
  - Delete all calendar events via API
  - Clear tokens from user document
  - Update googleCalendarConnected to false

### Frontend Tasks
- [ ] **FE-CAL-001**: Implement Google Sign-In for calendar access
  - Use google_sign_in package
  - Request calendar.events scope
  - Extract authorization code
  - Call backend to exchange for tokens
  
- [x] **FE-CAL-002**: Build calendar connection screen (in Settings) ✅
  - Show connection status (Connected/Not Connected)
  - "Connect Google Calendar" button
  - Display connected Google account email
  - "Disconnect" button with confirmation dialog
  
- [ ] **FE-CAL-003**: Create in-app calendar view
  - Display user's tasks in calendar grid format
  - Use table_calendar or similar package
  - Mark dates with tasks (dots/badges)
  - Tap date to see tasks for that day
  - Optional: Show read-only Google Calendar events
  
- [ ] **FE-CAL-004**: Add calendar prompts in onboarding
  - Ask user to connect calendar during setup
  - "Connect Now" and "Skip" options
  - Explain benefits of calendar sync
  
- [ ] **FE-CAL-005**: Handle calendar disconnection
  - Show confirmation: "This will delete all task events from your calendar"
  - Display loading state during deletion
  - Update UI after disconnection

### Acceptance Criteria
- ✓ Users can connect Google Calendar via OAuth
- ✓ Tasks create calendar events with title + subtitle
- ✓ Rescheduling updates calendar events automatically
- ✓ Disconnecting deletes all task-related calendar events
- ✓ Users without calendar connected receive notification prompts

---

## Module 8: Notifications

### Backend Tasks
- [ ] **FB-NOTIF-001**: Set up Firebase Cloud Messaging (FCM)
  - Configure FCM in Firebase Console
  - Set up APNs for iOS (if targeting iOS)
  - Generate server key
  
- [ ] **FB-NOTIF-002**: Create notification sending service
  - `sendNotification` helper function
  - Fetch user's FCM token from Firestore
  - Send notification via FCM Admin SDK
  - Include deep link data for navigation
  
- [ ] **FB-NOTIF-003**: Implement task assignment notification
  - Trigger when new task created
  - Send to assignee: "New Task Assigned: [Title]"
  - Send to creator: "Task created successfully"
  
- [ ] **FB-NOTIF-004**: Create scheduled deadline reminder function
  - `checkDeadlines` scheduled function (runs every hour)
  - Query tasks with deadline in 24 hours
  - Send notification to assignee and creator
  - Query tasks with deadline in 6 hours
  - Send notification to assignee and creator
  
- [ ] **FB-NOTIF-005**: Implement overdue task notifications
  - Part of `checkDeadlines` scheduled function
  - Query tasks past deadline with status 'ongoing'
  - Send notification to assignee, creator, and Super Admin
  - Run once per day per overdue task
  
- [ ] **FB-NOTIF-006**: Add notifications for approval workflow
  - Reschedule request: Notify task creator
  - Reschedule approved/rejected: Notify requester
  - User access approved: Notify new user

### Frontend Tasks
- [x] **FE-NOTIF-001**: Initialize FCM in app
  - Request notification permission (iOS/Android)
  - Get FCM token on app start
  - Save token to user document in Firestore
  - Handle token refresh
  
- [x] **FE-NOTIF-002**: Implement foreground notification handling
  - Display local notification when app is open
  - Use flutter_local_notifications package
  - Show as banner or alert
  
- [x] **FE-NOTIF-003**: Implement background notification tap handling
  - Parse notification payload
  - Deep link to task detail if taskId present
  - Navigate to approval screen if approval-related
  
- [ ] **FE-NOTIF-004**: Create notification preferences screen (Settings)
  - Toggle: Enable/Disable task notifications
  - Toggle: Enable/Disable deadline reminders
  - (Optional) Custom reminder timing
  
- [x] **FE-NOTIF-005**: Add in-app notification center
  - List all notifications (read/unread)
  - Mark as read functionality
  - Navigate to related item on tap
  - Badge count on navigation bar

### Acceptance Criteria
- ✓ Users receive push notifications for task assignments
- ✓ Reminders sent 1 day and 6 hours before deadline
- ✓ Overdue tasks notify assignee, creator, and Super Admin
- ✓ Notifications include deep links to relevant screens
- ✓ Users can tap notification to jump to task detail

---

## Module 9: Super Admin Dashboard & Reporting

### Backend Tasks
- [ ] **FB-ADMIN-001**: Create dashboard metrics Cloud Function
  - `getDashboardMetrics` callable function
  - Calculate: Total active tasks, overdue tasks, completed tasks
  - Count: Active teams, pending approvals, total users
  - Return aggregated data
  
- [ ] **FB-ADMIN-002**: Implement member management functions
  - `getAllUsers` callable function (Super Admin only)
  - `getUserTasks` callable function (fetch tasks by userId)
  - Filter/sort capabilities
  
- [ ] **FB-ADMIN-003**: Create PDF report export function
  - `exportReport` callable function
  - Accept parameters: date range, team, user, status
  - Query tasks based on filters
  - Generate PDF using pdfkit or puppeteer
  - Upload PDF to Cloud Storage
  - Return download URL
  - Send email with report link (optional)

### Frontend Tasks
- [ ] **FE-ADMIN-001**: Build Super Admin dashboard screen
  - Metric cards grid (2 columns):
    - Active Tasks (count + icon)
    - Overdue Tasks (count + icon)
    - Active Teams (count + icon)
    - Pending Approvals (count + icon)
  - Real-time updates
  - Tap card to navigate to detail view
  
- [ ] **FE-ADMIN-002**: Create quick actions section
  - "Approve Requests" button → Approval queue
  - "Manage Teams" button → Teams list
  - "View All Users" button → User management
  - "Export Report" button → Report generation
  
- [ ] **FE-ADMIN-003**: Build report export dialog
  - Date range picker (from/to)
  - Team filter dropdown (All Teams or specific)
  - User filter dropdown (All Users or specific)
  - Status filter: All, Ongoing, Completed, Cancelled, Overdue
  - "Generate PDF" button
  - Show loading spinner during generation
  - Download or share PDF after generation
  
- [ ] **FE-ADMIN-004**: Implement overdue tasks screen
  - List all overdue tasks
  - Show task title, assignee, original deadline, days overdue
  - Sort by most overdue first
  - Tap to view task detail
  
- [ ] **FE-ADMIN-005**: Create team tasks overview screen
  - Select team from dropdown
  - Display all tasks for that team
  - Breakdown: Ongoing, Completed, Cancelled
  - Chart/graph visualization (optional)

### Acceptance Criteria
- ✓ Super Admin dashboard shows real-time metrics
- ✓ Admin can view all users, teams, and tasks
- ✓ Admin can export PDF reports with filters
- ✓ Reports include task title, assignee, status, dates
- ✓ Admin can view reschedule logs

---

## Module 10: Settings & Theme

### Backend Tasks
- [ ] **FB-SETTINGS-001**: Create user profile update function
  - `updateProfile` callable function
  - Allow updating name, avatar
  - Validate user is updating their own profile

### Frontend Tasks
- [ ] **FE-SETTINGS-001**: Build settings screen
  - User profile section:
    - Avatar (tap to change)
    - Name (editable)
    - Email (read-only)
    - Role badge (read-only)
  - App settings:
    - Theme toggle (Light/Dark/System)
    - Notification preferences
  - Account actions:
    - "Logout" button
  
- [ ] **FE-SETTINGS-002**: Implement theme toggle functionality
  - Use Provider or Riverpod for theme state
  - Persist theme preference to local storage
  - Apply theme immediately on toggle
  - Smooth transition animation
  
- [ ] **FE-SETTINGS-003**: Create profile edit screen
  - Name input field
  - Avatar picker (camera or gallery)
  - Upload avatar to Firebase Storage
  - "Save" button

### Acceptance Criteria
- ✓ Users can toggle between light/dark/system theme
- ✓ Theme preference persists across app restarts
- ✓ Users can edit their profile name and avatar
- ✓ Logout clears authentication state

---

## Module 11: Quality Assurance & Testing

### Testing Tasks
- [ ] **QA-001**: Unit test authentication logic
  - Test email validation
  - Test password strength validation
  - Test login error handling
  
- [ ] **QA-002**: Unit test permission utilities
  - Test role-based access functions
  - Test edge cases (null user, missing role)
  
- [ ] **QA-003**: Widget test task list screen
  - Test empty state rendering
  - Test task card rendering
  - Test tab switching
  
- [ ] **QA-004**: Integration test task creation flow
  - Create task → Verify in list → Open detail
  - Test validation errors
  
- [ ] **QA-005**: Integration test reschedule workflow
  - Request reschedule → Approve → Verify deadline updated
  
- [ ] **QA-006**: Test calendar integration
  - Connect calendar → Create task → Verify event in Google Calendar
  - Disconnect calendar → Verify events deleted
  
- [ ] **QA-007**: Test notification delivery
  - Trigger task assignment → Verify FCM received
  - Test deep link navigation from notification
  
- [ ] **QA-008**: Backend function testing
  - Test all Cloud Functions with mock data
  - Test security rules with different user roles
  
- [ ] **QA-009**: Performance testing
  - Test app with 100+ tasks
  - Measure list scroll performance
  - Test Firebase query efficiency
  
- [ ] **QA-010**: Cross-platform testing
  - Test on iOS (iPhone, iPad)
  - Test on Android (various screen sizes)
  - Test dark mode on both platforms

### Acceptance Criteria
- ✓ All MVP acceptance criteria from PDF met
- ✓ No critical bugs in task creation/assignment flow
- ✓ Notifications delivered reliably
- ✓ Calendar sync works correctly

---

## Module 12: Deployment & Handover

### Deployment Tasks
- [ ] **DEPLOY-001**: Set up Firebase hosting (if web app needed)
  
- [ ] **DEPLOY-002**: Configure Firebase environment variables
  - Set super_admin_email config
  - Set SendGrid/email service keys
  - Set OAuth client credentials
  
- [ ] **DEPLOY-003**: Deploy Cloud Functions to Prod
  - Run `firebase deploy --only functions --project prod`
  - Test all functions in Prod environment
  
- [ ] **DEPLOY-004**: Deploy Firestore security rules
  - Run `firebase deploy --only firestore:rules --project prod`
  - Verify rules are enforced
  
- [ ] **DEPLOY-005**: Build Flutter app for production
  - Android: `flutter build apk --release`
  - iOS: `flutter build ios --release`
  - Configure app signing
  
- [ ] **DEPLOY-006**: Submit to app stores (if applicable)
  - Prepare screenshots, app description
  - Submit to Google Play Store
  - Submit to Apple App Store
  
- [ ] **DEPLOY-007**: Set up monitoring and logging
  - Enable Firebase Crashlytics
  - Set up Cloud Logging alerts
  - Monitor Cloud Function errors

### Documentation Tasks
- [ ] **DOC-001**: Create API documentation
  - Document all Cloud Functions (parameters, responses)
  - Include authentication requirements
  
- [ ] **DOC-002**: Write deployment guide
  - Step-by-step Firebase setup
  - Environment configuration
  - Build and release process
  
- [ ] **DOC-003**: Create user manual
  - How to create tasks
  - How to use reschedule feature
  - How to connect Google Calendar
  
- [ ] **DOC-004**: Document admin workflows
  - How to approve users
  - How to manage teams
  - How to generate reports

### Acceptance Criteria
- ✓ Production apps deployed to Firebase/App Stores
- ✓ All documentation complete and accurate
- ✓ Monitoring and alerts configured
- ✓ Handover meeting completed

---

## Summary by Role

### Backend Developer Checklist (38 tasks)
- Authentication & User Management: 7 tasks
- Role & Permission System: 4 tasks
- Team Management: 4 tasks
- Task CRUD & Assignment: 6 tasks
- Remarks: 2 tasks
- Reschedule Workflow: 3 tasks
- Google Calendar Integration: 5 tasks
- Notifications: 6 tasks
- Admin Dashboard: 3 tasks
- Settings: 1 task
- Testing & Deployment: 7 tasks

### Frontend Developer Checklist (53 tasks)
- Authentication & Onboarding: 6 tasks
- Role-based UI: 5 tasks
- Team Management: 5 tasks
- Task CRUD & Assignment: 7 tasks
- Remarks: 3 tasks
- Reschedule Workflow: 4 tasks
- Google Calendar Integration: 5 tasks
- Notifications: 5 tasks
- Admin Dashboard: 5 tasks
- Settings & Theme: 3 tasks
- Testing: 10 tasks
- Deployment: 7 tasks

### QA Engineer Checklist (10 tasks)
- Unit testing
- Widget testing
- Integration testing
- Cross-platform testing
- Performance testing

---

## Dependencies & Prerequisites

### Before Starting Development
1. Firebase project created (Dev & Prod)
2. Google Cloud Console project for Calendar API
3. SendGrid account (or Firebase email extension)
4. Flutter SDK installed
5. Firebase CLI installed
6. Design assets ready (logo, icons)

### Module Dependencies
- **Module 2** (Roles) depends on **Module 1** (Auth)
- **Module 3** (Teams) depends on **Module 2** (Roles)
- **Module 4** (Tasks) depends on **Module 3** (Teams)
- **Module 6** (Reschedule) depends on **Module 4** (Tasks)
- **Module 7** (Calendar) depends on **Module 4** (Tasks)
- **Module 8** (Notifications) depends on **Module 4** (Tasks)
- **Module 9** (Dashboard) depends on **Modules 2, 3, 4**

---

## Risk Mitigation

### High-Risk Tasks
1. **Google Calendar OAuth** - Complex token management
   - Mitigation: Test with throwaway accounts first
   
2. **FCM Notification Delivery** - Platform-specific issues
   - Mitigation: Test on real devices early
   
3. **Scheduled Functions Reliability** - Cloud Functions may timeout
   - Mitigation: Implement batch processing, monitor logs
   
4. **PDF Report Generation** - Memory intensive
   - Mitigation: Limit report size, use streaming

---

## Post-MVP Enhancements (Phase 2 & 3)

### Phase 2 Tasks (Not in current scope)
- Offline support with local database
- Task attachments (images/documents)
- Advanced reporting filters
- Custom roles and permissions
- Audit logs for all actions

### Phase 3 Tasks (AI/Voice)
- AI voice-based task creation
- Natural language processing for task details
- Smart assignee suggestions
- Deadline prediction based on workload

---

**End of Task Breakdown**
