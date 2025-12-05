/// App Route Names
class AppRoutes {
  // Auth
  static const String login = '/login';
  static const String signup = '/signup';
  static const String requestPending = '/request-pending';
  static const String onboarding = '/onboarding';

  // Home & Tasks
  static const String home = '/';
  static const String taskDetail = '/task/:id';
  static const String createTask = '/task/create';
  static const String editTask = '/task/:id/edit';

  // Admin
  static const String adminDashboard = '/admin';
  static const String teamManagement = '/admin/teams';
  static const String userApproval = '/admin/approvals';
  static const String userManagement = '/admin/users';
  static const String allTasks = '/admin/all-tasks';
  static const String userTaskSummary = '/admin/users/:id/tasks';
  static const String adminMyTasks = '/admin/my-tasks';
  static const String inviteUsers = '/admin/invites';

  // Approvals
  static const String approvals = '/approvals';
  static const String approvalDetail = '/approvals/:id';
  static const String rescheduleApproval = '/approvals/reschedule';
  static const String rescheduleLog = '/admin/reschedule-log';

  // Settings
  static const String settings = '/settings';
  static const String profile = '/profile';

  // Notifications
  static const String notifications = '/notifications';
}
