# TODO Planner & Task Management

A professional task management Flutter application with team collaboration, role-based access control, and Google Calendar integration.

---

## ⚠️ Important: Pre-Production Setup Required

This project contains **placeholder configuration** values. Before deploying to production:

**📋 See [`.windsurf/CodeMap.md`](.windsurf/CodeMap.md) for the complete pre-production checklist.**

Key items to update:
- Firebase configuration (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`)
- Environment variables (`.env`)
- Bundle identifiers
- Design assets (app icon, splash screen, illustrations)

---

## Features

### Core Functionality
- ✅ **Task Management**: Create, assign, track, and complete tasks
- ✅ **Team Collaboration**: Assign tasks to individuals or teams
- ✅ **Role-Based Access**: Super Admin, Team Admin, and Member roles
- ✅ **User Approval Workflow**: Pending → Active user status
- ✅ **Deadline Tracking**: Visual status indicators and notifications
- ✅ **Remarks**: Add comments and updates to tasks

### Advanced Features
- 🔔 **Push Notifications**: Task assignments, deadline reminders
- 📅 **Google Calendar Sync**: Automatic calendar event creation
- 📊 **Admin Dashboard**: Metrics, team management, user approvals
- 🔄 **Reschedule Requests**: Approval workflow for deadline changes
- 🌓 **Dark Mode**: System-based or manual toggle
- 📱 **Responsive Design**: Optimized for phones and tablets

---

## Getting Started

### Prerequisites
- Flutter SDK 3.16+ (stable channel)
- Dart 3.2+
- Firebase account
- Google Cloud Platform account (for Calendar API)

### Installation

1. **Clone the repository**
   ```bash
   cd /path/to/project
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase** (⚠️ REQUIRED before running)
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli

   # Configure Firebase for your project
   flutterfire configure
   ```
   This will generate the proper `firebase_options.dart` file.

4. **Add Firebase config files**
   - **Android**: Place `google-services.json` in `/android/app/`
   - **iOS**: Place `GoogleService-Info.plist` in `/ios/Runner/`

5. **Update environment variables**
   - Edit `.env` file with your super admin email
   ```env
   SUPER_ADMIN_EMAIL=your-admin@example.com
   ENV=development
   ```

### Running the App

```bash
# Development mode
flutter run

# Production build
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

---

## Project Structure

```
lib/
├── core/               # Theme, constants, utilities
├── data/               # Models, repositories, services
├── presentation/       # UI screens and widgets
│   ├── common/        # Reusable components
│   ├── auth/          # Authentication screens
│   ├── home/          # Task list screens
│   ├── task/          # Task detail/create/edit
│   ├── admin/         # Admin dashboard
│   ├── approvals/     # Reschedule approvals
│   └── settings/      # Settings and profile
└── main.dart          # App entry point
```

See [`.windsurf/CodeMap.md`](.windsurf/CodeMap.md) for detailed architecture documentation.

---

## Tech Stack

- **Framework**: Flutter 3.16+
- **Language**: Dart 3.2+
- **State Management**: Provider
- **Navigation**: GoRouter
- **Backend**: Firebase
  - Authentication
  - Firestore Database
  - Cloud Functions
  - Cloud Messaging (FCM)
  - Cloud Storage
- **APIs**: Google Calendar API

---

## User Roles

### Super Admin
- Full system access
- User approval/revocation
- Team creation and management
- Dashboard access with metrics
- Export reports

### Team Admin
- Manage assigned team members
- Create and assign team tasks
- View team metrics

### Member
- View assigned tasks
- Complete tasks
- Add remarks
- Request reschedules

---

## Development Guidelines

### Design System
This project follows a strict design system defined in `.windsurf/design_system.md`:
- **Colors**: Blue-based professional palette
- **Typography**: Inter font family, 7 text styles
- **Spacing**: 4px base unit system
- **Components**: Reusable widgets in `lib/presentation/common/`

### Code Style
- Use reusable components from `presentation/common/`
- Follow the spacing system from `AppSpacing`
- Support both light and dark themes
- Add proper accessibility labels

### Adding New Features
1. Create data models in `data/models/`
2. Implement repository in `data/repositories/`
3. Build UI in `presentation/`
4. Update routes in `core/constants/app_routes.dart`
5. Add strings to `core/constants/app_strings.dart`

---

## Testing

```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test

# Run widget tests
flutter test test/widgets
```

---

## Environment Configuration

The app uses `.env` for environment-specific configuration:

```env
SUPER_ADMIN_EMAIL=admin@yourcompany.com
ENV=development  # or 'production'
```

---

## Firebase Setup Checklist

- [ ] Create Firebase project
- [ ] Enable Authentication (Email/Password)
- [ ] Set up Firestore Database
- [ ] Configure Security Rules
- [ ] Deploy Cloud Functions
- [ ] Enable Cloud Messaging
- [ ] Set up Cloud Storage
- [ ] Configure OAuth consent screen (for Google Calendar)

---

## Known Limitations

- Requires active internet connection (offline support planned)
- Task attachments not yet implemented
- Basic analytics only (advanced metrics planned)
- English language only (i18n planned)

---

## Roadmap

### Phase 1 - MVP (Current)
- ✅ Basic task management
- ✅ Role-based access control
- ✅ Firebase integration
- 🚧 All UI screens (in progress)

### Phase 2 - Enhancements
- [ ] Offline support
- [ ] Task attachments
- [ ] Advanced reporting
- [ ] Fine-grained permissions

### Phase 3 - AI & Voice
- [ ] Voice-based task creation
- [ ] Smart deadline suggestions
- [ ] AI-powered insights

---

## Documentation

- **Design System**: [`.windsurf/design_system.md`](.windsurf/design_system.md)
- **Frontend Specification**: [`.windsurf/frontend_developer_doc.md`](.windsurf/frontend_developer_doc.md)
- **Backend Specification**: [`.windsurf/backend_developer_doc.md`](.windsurf/backend_developer_doc.md)
- **Code Architecture**: [`.windsurf/CodeMap.md`](.windsurf/CodeMap.md)

---

## License

[Add your license here]

---

## Support

For issues or questions, please contact [your-email@example.com]

---

**Built with ❤️ using Flutter**
