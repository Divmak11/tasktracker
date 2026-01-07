import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/approval_request_model.dart';
import '../repositories/user_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/approval_repository.dart';
import '../repositories/task_repository.dart';
import '../repositories/team_repository.dart';

/// A global provider to cache data that should persist across navigation changes.
/// This prevents flickering (disappearing/reappearing) of user data and counters
/// when widgets are disposed and recreated during navigation.
class DataCacheProvider extends ChangeNotifier {
  final UserRepository _userRepository = UserRepository();
  final NotificationRepository _notificationRepository = NotificationRepository();
  final ApprovalRepository _approvalRepository = ApprovalRepository();
  final TaskRepository _taskRepository = TaskRepository();
  final TeamRepository _teamRepository = TeamRepository();

  // --- User Caching ---
  final Map<String, UserModel> _userCache = {};
  final Set<String> _fetchingUserIds = {};

  UserModel? getUser(String? id) => id != null ? _userCache[id] : null;

  /// Fetch users if not already in cache.
  Future<void> prefetchUsers(Set<String> userIds) async {
    final uncachedIds = userIds
        .where((id) => !_userCache.containsKey(id) && !_fetchingUserIds.contains(id))
        .toList();
    
    if (uncachedIds.isEmpty) return;

    _fetchingUserIds.addAll(uncachedIds);
    
    try {
      final futures = uncachedIds.map((id) => _userRepository.getUser(id));
      final users = await Future.wait(futures);

      bool changed = false;
      for (int i = 0; i < uncachedIds.length; i++) {
        final user = users[i];
        if (user != null) {
          _userCache[uncachedIds[i]] = user;
          changed = true;
        }
      }
      
      if (changed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error prefetching users: $e');
    } finally {
      _fetchingUserIds.removeAll(uncachedIds);
    }
  }

  // --- Global Counters (Persistent Badges) ---
  int _unreadCount = 0;
  int _pendingReschedulesCount = 0;
  
  // Member Dashboard Counts
  int _assignedCount = 0;
  int _createdCount = 0;
  int _overdueCount = 0;
  int _completedCount = 0;

  // Admin Dashboard Counts
  int _totalUsersCount = 0;
  int _pendingUsersCount = 0;
  int _totalTeamsCount = 0;
  int _activeTasksCount = 0;
  int _adminOverdueTasksCount = 0;
  int _adminMyTasksCount = 0;
  int _adminPendingReschedulesCount = 0;
  List<UserModel> _allUsers = [];
  
  int get unreadCount => _unreadCount;
  int get pendingReschedulesCount => _pendingReschedulesCount;
  int get assignedCount => _assignedCount;
  int get createdCount => _createdCount;
  int get overdueCount => _overdueCount;
  int get completedCount => _completedCount;

  int get totalUsersCount => _totalUsersCount;
  int get pendingUsersCount => _pendingUsersCount;
  int get totalTeamsCount => _totalTeamsCount;
  int get activeTasksCount => _activeTasksCount;
  int get adminOverdueTasksCount => _adminOverdueTasksCount;
  int get adminMyTasksCount => _adminMyTasksCount;
  int get adminPendingReschedulesCount => _adminPendingReschedulesCount;
  List<UserModel> get allUsers => _allUsers;

  StreamSubscription? _unreadSubscription;
  StreamSubscription? _rescheduleSubscription;
  StreamSubscription? _assignedSubscription;
  StreamSubscription? _createdSubscription;
  StreamSubscription? _overdueSubscription;
  StreamSubscription? _completedSubscription;

  // Admin Subscriptions
  StreamSubscription? _usersSubscription;
  StreamSubscription? _teamsSubscription;
  StreamSubscription? _activeTasksSubscription;
  StreamSubscription? _adminOverdueSubscription;
  StreamSubscription? _adminMyTasksSubscription;
  StreamSubscription? _adminRescheduleSubscription;

  /// Initialize global listeners for a specific user.
  /// Should be called on login/app startup.
  void init(String userId, {bool isSuperAdmin = false}) {
    cancelAll();
    
    // Listen to notification unread count
    _unreadSubscription = _notificationRepository.getUnreadCountStream(userId).listen((count) {
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    });

    // Listen to pending reschedule requests (common for both roles)
    _rescheduleSubscription = _approvalRepository.getPendingRescheduleRequestsStream(userId).listen((list) {
      if (_pendingReschedulesCount != list.length) {
        _pendingReschedulesCount = list.length;
        notifyListeners();
      }
    });

    if (!isSuperAdmin) {
      // Task counts for Member Dashboard
      _assignedSubscription = _taskRepository
          .getOngoingAssignedTasksStream(userId)
          .map((tasks) => tasks.where((t) => t.createdBy != userId && !t.isOverdue).toList())
          .listen((list) {
        if (_assignedCount != list.length) {
          _assignedCount = list.length;
          notifyListeners();
        }
      });

      _createdSubscription = _taskRepository
          .getCreatedTasksStream(userId)
          .map((tasks) => tasks.where((t) => t.status == TaskStatus.ongoing && !t.isOverdue).toList())
          .listen((list) {
        if (_createdCount != list.length) {
          _createdCount = list.length;
          notifyListeners();
        }
      });

      _overdueSubscription = _taskRepository
          .getUserCalendarTasksStream(userId)
          .map((tasks) => tasks.where((t) => t.status == TaskStatus.ongoing && t.isOverdue).toList())
          .listen((list) {
        if (_overdueCount != list.length) {
          _overdueCount = list.length;
          notifyListeners();
        }
      });

      _completedSubscription = _taskRepository.getPastAssignedTasksStream(userId).listen((list) {
        if (_completedCount != list.length) {
          _completedCount = list.length;
          notifyListeners();
        }
      });
    } else {
      // Admin Dashboard Specific Listeners
      _usersSubscription = _userRepository.getAllUsersStream().listen((users) {
        _allUsers = users;
        // Also update individual cache for quick lookup
        for (final user in users) {
          _userCache[user.id] = user;
        }
        final total = users.length;
        final pending = users.where((u) => u.status == UserStatus.pending).length;
        if (_totalUsersCount != total || _pendingUsersCount != pending) {
          _totalUsersCount = total;
          _pendingUsersCount = pending;
          notifyListeners();
        } else {
          // Even if counts don't change, the list itself might have changed
          notifyListeners();
        }
      });

      _teamsSubscription = _teamRepository.getAllTeamsStream().listen((teams) {
        if (_totalTeamsCount != teams.length) {
          _totalTeamsCount = teams.length;
          notifyListeners();
        }
      });

      _activeTasksSubscription = _taskRepository.getAllActiveTasksStream().listen((tasks) {
        if (_activeTasksCount != tasks.length) {
          _activeTasksCount = tasks.length;
          notifyListeners();
        }
      });

      _adminOverdueSubscription = _taskRepository.getOverdueTasksStream().listen((tasks) {
        if (_adminOverdueTasksCount != tasks.length) {
          _adminOverdueTasksCount = tasks.length;
          notifyListeners();
        }
      });

      _adminMyTasksSubscription = _taskRepository.getOngoingAssignedTasksStream(userId).listen((tasks) {
        if (_adminMyTasksCount != tasks.length) {
          _adminMyTasksCount = tasks.length;
          notifyListeners();
        }
      });

      _adminRescheduleSubscription = _approvalRepository.getAllRescheduleRequestsStream(status: ApprovalRequestStatus.pending).listen((requests) {
        if (_adminPendingReschedulesCount != requests.length) {
          _adminPendingReschedulesCount = requests.length;
          notifyListeners();
        }
      });
    }
  }

  /// Cancel all subscriptions (e.g. on logout)
  void cancelAll() {
    _unreadSubscription?.cancel();
    _rescheduleSubscription?.cancel();
    _assignedSubscription?.cancel();
    _createdSubscription?.cancel();
    _overdueSubscription?.cancel();
    _completedSubscription?.cancel();
    _usersSubscription?.cancel();
    _teamsSubscription?.cancel();
    _activeTasksSubscription?.cancel();
    _adminOverdueSubscription?.cancel();
    _adminMyTasksSubscription?.cancel();
    _adminRescheduleSubscription?.cancel();

    _unreadCount = 0;
    _pendingReschedulesCount = 0;
    _assignedCount = 0;
    _createdCount = 0;
    _overdueCount = 0;
    _completedCount = 0;
    _totalUsersCount = 0;
    _pendingUsersCount = 0;
    _totalTeamsCount = 0;
    _activeTasksCount = 0;
    _adminOverdueTasksCount = 0;
    _adminMyTasksCount = 0;
    _adminPendingReschedulesCount = 0;
    _allUsers = [];
  }

  @override
  void dispose() {
    cancelAll();
    super.dispose();
  }
}
