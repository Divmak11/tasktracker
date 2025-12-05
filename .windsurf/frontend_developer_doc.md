# Frontend Developer Documentation
**TODO Planner & Task Management - Flutter MVP**

## Project Setup

### Prerequisites
- Flutter SDK 3.16+ (stable channel)
- Dart 3.2+
- iOS: Xcode 15+, CocoaPods
- Android: Android Studio, Gradle 8+

### Initial Setup
```bash
flutter create --org com.yourcompany todo_planner
cd todo_planner
flutter pub add firebase_core firebase_auth cloud_firestore firebase_messaging
flutter pub add google_sign_in_ios google_sign_in_android
flutter pub add provider go_router intl
flutter pub add flutter_dotenv firebase_storage
```

### Project Structure
```
lib/
├── core/
│   ├── theme/           # AppTheme (light/dark)
│   ├── constants/       # Routes, Strings, Config
│   └── utils/           # Helpers, Extensions
├── data/
│   ├── models/          # User, Task, Team, ApprovalRequest
│   ├── repositories/    # Firebase data access layer
│   └── services/        # CalendarService, NotificationService
├── presentation/
│   ├── common/          # Reusable widgets (AppButton, AppCard)
│   ├── auth/            # Login, Signup, Onboarding screens
│   ├── home/            # Task list (Member view)
│   ├── task/            # Task detail, Create, Edit
│   ├── admin/           # Dashboard, Team management
│   ├── approvals/       # Reschedule approval screens
│   └── settings/        # Profile, Theme toggle
└── main.dart
```

---

## Core Implementation

### 1. Firebase Initialization

**`main.dart`**
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
```

## UI Architecture & Design System

This project follows a strict component-driven UI architecture based on `design_system.md`.

### 1. Design System Integration
The `design_system.md` file is the **single source of truth** for all visual styles and behaviors.
- **Foundations**: Colors, Typography, Spacing are mapped in `AppTheme`.
- **Components**: Reusable widgets are built in `lib/presentation/common/` matching the design specs.

### 2. Theme Configuration
**`core/theme/app_theme.dart`**
Extends Flutter's `ThemeData` to match the Design System tokens.

```dart
class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    // Primary Colors from design_system.md
    primaryColor: Color(0xFF2563EB), 
    scaffoldBackgroundColor: Color(0xFFFFFFFF),
    
    // Semantic Colors via ColorScheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: Color(0xFF2563EB),
      primary: Color(0xFF2563EB),
      secondary: Color(0xFF2563EB), // Adjust if needed
      surface: Color(0xFFF9FAFB),
      error: Color(0xFFEF4444),
    ),

    // Typography (Mapping 'Inter' scale)
    textTheme: TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2), // H1
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),     // H2
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),    // H3
      bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    ),
    
    // Component Themes
    cardTheme: CardTheme(
      color: Color(0xFFF9FAFB), // Surface
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Color(0xFFE5E7EB)), // Border color
      ),
    ),
  );
  
  // ... Dark theme implementation similarly
}
```

### 3. Reusable Components (`lib/presentation/common/`)
Do not build UI elements from scratch in page files. Use these shared widgets:

| Design System Component | Widget Name | Location | Usage |
|-------------------------|-------------|----------|-------|
| **Primary Button** | `AppButton` | `common/buttons/` | `AppButton(text: 'Save', onPressed: ...)` |
| **Secondary Button** | `AppButton` | `common/buttons/` | `AppButton(text: 'Cancel', variant: ButtonVariant.secondary)` |
| **Standard Card** | `AppCard` | `common/cards/` | `AppCard(child: ...)` |
| **Input Field** | `AppTextField` | `common/inputs/` | `AppTextField(label: 'Email', ...)` |
| **Status Badge** | `StatusBadge` | `common/badges/` | `StatusBadge(status: 'ongoing')` |

### 4. Page Composition Strategy
Pages are compositions of the above components arranged using the Spacing System.

- **Layout**: `Scaffold` > `SafeArea` > `Column` / `ListView`.
- **Spacing**: Use `SizedBox` with 4px-grid values: `4, 8, 12, 16, 24, 32, 48`.
- **Typography**: Always use `Theme.of(context).textTheme.x` styles.

**Example Page Structure:**
```dart
Scaffold(
  appBar: CustomAppBar(title: 'Task Details'),
  body: Padding(
    padding: EdgeInsets.all(16), // Screen padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Task Title', style: Theme.of(context).textTheme.headlineMedium), // H1
        SizedBox(height: 24), // xl spacing
        AppCard(child: TaskMetadata(...)),
        SizedBox(height: 32), // 2xl spacing
        AppButton(text: 'Complete Task', onPressed: ...),
      ],
    ),
  ),
)
```

---

## Data Models

### User Model
```dart
class UserModel {
  final String id;
  final String name;
  final String email;
  final String role; // 'super_admin', 'team_admin', 'member'
  final List<String> teamIds;
  final String status; // 'pending', 'active', 'revoked'
  final bool googleCalendarConnected;
  final DateTime createdAt;

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'member',
      teamIds: List<String>.from(data['teamIds'] ?? []),
      status: data['status'] ?? 'pending',
      googleCalendarConnected: data['googleCalendarConnected'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'email': email,
    'role': role,
    'teamIds': teamIds,
    'status': status,
    'googleCalendarConnected': googleCalendarConnected,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
```

### Task Model
```dart
class TaskModel {
  final String id;
  final String title;
  final String subtitle;
  final String assignedType; // 'member' or 'team'
  final String assignedTo; // userId or teamId
  final String createdBy; // userId
  final String status; // 'ongoing', 'completed', 'cancelled'
  final DateTime deadline;
  final String? calendarEventId;
  final DateTime createdAt;

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      assignedType: data['assignedType'] ?? 'member',
      assignedTo: data['assignedTo'] ?? '',
      createdBy: data['createdBy'] ?? '',
      status: data['status'] ?? 'ongoing',
      deadline: (data['deadline'] as Timestamp).toDate(),
      calendarEventId: data['calendarEventId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'subtitle': subtitle,
    'assignedType': assignedType,
    'assignedTo': assignedTo,
    'createdBy': createdBy,
    'status': status,
    'deadline': Timestamp.fromDate(deadline),
    'calendarEventId': calendarEventId,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
```

---

## Key Screens Implementation

### 1. Authentication Flow

**Signup Screen**
- Email + Password fields
- "Sign Up" button → Creates Firebase Auth user → Sets status = 'pending'
- Navigates to "Request Pending" screen

**Request Pending Screen**
```dart
class RequestPendingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 80, color: Colors.blue),
            SizedBox(height: 24),
            Text('Request Submitted', style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: 12),
            Text('We'll notify you once approved', textAlign: TextAlign.center),
            SizedBox(height: 32),
            ElevatedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: Text('Logout')),
          ],
        ),
      ),
    );
  }
}
```

### 2. Homepage (Task List)

**Features:**
- Tab bar: Ongoing | Past
- Task list (filtered by logged-in user's assigned tasks)
- FAB to create task (if user has permission)

```dart
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('My Tasks'),
          bottom: TabBar(tabs: [Tab(text: 'Ongoing'), Tab(text: 'Past')]),
        ),
        body: TabBarView(
          children: [
            TaskListView(userId: userId, filter: 'ongoing'),
            TaskListView(userId: userId, filter: 'past'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen())),
          child: Icon(Icons.add),
        ),
      ),
    );
  }
}
```

### 3. Task Detail Screen

**Features:**
- Display title, subtitle, assignee, deadline, status
- Remarks section (visible to assignee + assigner + admin)
- Action buttons: Add Remark, Mark Complete, Request Reschedule

```dart
class TaskDetailScreen extends StatelessWidget {
  final TaskModel task;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Task Details')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: Theme.of(context).textTheme.headlineMedium),
            SizedBox(height: 8),
            Text(task.subtitle),
            SizedBox(height: 24),
            _buildMetadata(),
            Divider(height: 32),
            _buildRemarksSection(),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBar(context),
    );
  }
  
  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
      ),
      child: Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: _addRemark, child: Text('Add Remark'))),
          SizedBox(width: 8),
          Expanded(child: ElevatedButton(onPressed: _markComplete, child: Text('Complete'))),
        ],
      ),
    );
  }
}
```

### 4. Create Task Screen

**Fields:**
- Title (TextField)
- Subtitle (TextField, multiline)
- Assign to: Dropdown (Team or Member selection)
- Deadline: DateTimePicker

**Logic:**
- Call Cloud Function `assignTask` (handles task creation + calendar + notification)

```dart
Future<void> _createTask() async {
  final callable = FirebaseFunctions.instance.httpsCallable('assignTask');
  try {
    await callable.call({
      'title': titleController.text,
      'subtitle': subtitleController.text,
      'assignedType': selectedType, // 'member' or 'team'
      'assignedTo': selectedId,
      'deadline': deadline.toIso8601String(),
    });
    Navigator.pop(context);
  } catch (e) {
    // Show error
  }
}
```

---

## Role-Based UI

### Permission Checks

**`core/utils/permissions.dart`**
```dart
class Permissions {
  static bool canCreateTask(UserModel user) {
    return true; // All users can create tasks
  }
  
  static bool canCreateTeam(UserModel user) {
    return user.role == 'super_admin';
  }
  
  static bool canApproveUsers(UserModel user) {
    return user.role == 'super_admin';
  }
  
  static bool canReopenTask(UserModel user) {
    return user.role == 'super_admin';
  }
}
```

### Conditional Navigation

```dart
BottomNavigationBar(
  items: [
    BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Tasks'),
    if (user.role == 'super_admin') 
      BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
  ],
)
```

---

## Google Calendar Integration

### OAuth Flow

**Install packages:**
```bash
flutter pub add google_sign_in googleapis
```

**Calendar Service:**
```dart
class CalendarService {
  Future<void> connectCalendar() async {
    final googleSignIn = GoogleSignIn(scopes: ['https://www.googleapis.com/auth/calendar']);
    final account = await googleSignIn.signIn();
    final auth = await account!.authentication;
    
    // Save tokens to Firestore
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'googleCalendarConnected': true,
      'googleAccessToken': auth.accessToken,
      'googleRefreshToken': auth.refreshToken,
    });
  }
  
  Future<void> disconnectCalendar() async {
    // Call Cloud Function to delete existing calendar events
    final callable = FirebaseFunctions.instance.httpsCallable('disconnectCalendar');
    await callable.call();
    
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'googleCalendarConnected': false,
    });
  }
}
```

---

## Notifications

### FCM Setup

**Android (`android/app/src/main/AndroidManifest.xml`):**
```xml
<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" value="task_notifications"/>
```

**iOS:** Configure APNs in Firebase Console

### Handling Notifications

**`data/services/notification_service.dart`**
```dart
class NotificationService {
  Future<void> initialize() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // Request permission
    await messaging.requestPermission();
    
    // Get FCM token
    String? token = await messaging.getToken();
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'fcmToken': token});
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
    
    // Handle taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToTask(message.data['taskId']);
    });
  }
}
```

---

## State Management

Use **Provider** for simplicity:

**`main.dart`**
```dart
runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => TaskProvider()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: MyApp(),
  ),
);
```

**`ThemeProvider` Example:**
```dart
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
```

---

## Testing Strategy

### Unit Tests
- Model serialization (fromFirestore, toFirestore)
- Permission logic
- Date formatting helpers

### Widget Tests
- Login form validation
- Task list rendering
- Empty states

### Integration Tests
- Full auth flow (signup → pending screen)
- Create task → view in list
- Reschedule request flow

---

## Unclarified Items for Frontend

1. **App Icon/Logo**: Needs to be provided by designer
2. **Email Verification**: Should we verify emails before allowing access? (Currently not specified)
3. **Network Error Handling**: Standard retry strategy or custom UI?
4. **Data Caching**: Use offline persistence (Firestore cache) or custom local DB?

---

## Environment Configuration

**`.env` file:**
```
SUPER_ADMIN_EMAIL=admin@company.com
```

**Load in `main.dart`:**
```dart
await dotenv.load(fileName: ".env");
```

---

## Build & Release

### Development
```bash
flutter run --flavor dev
```

### Production
```bash
flutter build apk --release
flutter build ios --release
```

See `backend_developer_doc.md` for Firebase project setup per environment.
