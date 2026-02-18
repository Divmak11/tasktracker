import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  
  // Track initialized user to prevent destructive re-initialization
  String? _currentUserId;


  // --- User Caching ---
  final Map<String, UserModel> _userCache = {};
  final Map<String, DateTime> _userCacheTimestamps = {};
  final Set<String> _fetchingUserIds = {};
  static const _userCacheTtl = Duration(minutes: 10);

  UserModel? getUser(String? id) => id != null ? _userCache[id] : null;

  /// Fetch users if not already in cache, or if cached data is stale.
  Future<void> prefetchUsers(Set<String> userIds) async {
    final now = DateTime.now();

    // Identify stale entries that need background refresh
    final staleIds = userIds
        .where((id) => _userCache.containsKey(id) &&
            _userCacheTimestamps.containsKey(id) &&
            now.difference(_userCacheTimestamps[id]!) > _userCacheTtl &&
            !_fetchingUserIds.contains(id))
        .toList();

    // Identify completely uncached entries that need immediate fetch
    final uncachedIds = userIds
        .where((id) => !_userCache.containsKey(id) && !_fetchingUserIds.contains(id))
        .toList();

    // Background refresh stale entries
    if (staleIds.isNotEmpty) {
      _fetchingUserIds.addAll(staleIds);
      _fetchUserBatch(staleIds)
        .catchError((_) {}) // Suppress background refresh errors
        .whenComplete(() {
          _fetchingUserIds.removeAll(staleIds);
        });
    }

    // Immediate fetch for uncached entries
    if (uncachedIds.isEmpty) return;

    _fetchingUserIds.addAll(uncachedIds);

    try {
      await _fetchUserBatch(uncachedIds);
    } catch (e) {
      debugPrint('DataCacheProvider: Error prefetching users: $e');
    } finally {
      _fetchingUserIds.removeAll(uncachedIds);
    }
  }

  Future<void> _fetchUserBatch(List<String> ids) async {
    final futures = ids.map((id) => _userRepository.getUser(id));
    final users = await Future.wait(futures);

    bool changed = false;
    final now = DateTime.now();
    for (int i = 0; i < ids.length; i++) {
      final user = users[i];
      if (user != null) {
        _userCache[ids[i]] = user;
        _userCacheTimestamps[ids[i]] = now;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
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

  // --- Task List Cache (background fetch strategy) ---
  // Populated by the existing subscriptions; used as initialData in StreamBuilders
  // so screens show stale data immediately while the stream delivers fresh data.
  List<TaskModel> _cachedOngoingTasks = [];
  List<TaskModel> _cachedPastTasks = [];
  List<TaskModel> _cachedCreatedTasks = [];

  // --- Report Exempt List Cache ---
  // Populated by a direct Firestore stream on config/reportExemptUsers.
  // Replaces the getReportExemptList Cloud Function call.
  Set<String> _cachedExemptIds = {};
  bool _exemptListLoaded = false;
  StreamSubscription? _exemptSubscription;

  // --- User List Load State ---
  // True once the first snapshot from getAllUsersStream() has arrived.
  // Distinct from allUsers.isEmpty — an org with zero users is a valid state.
  bool _allUsersLoaded = false;
  
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

  /// True once the first snapshot from getAllUsersStream() has arrived.
  /// Use this — not allUsers.isEmpty — to distinguish loading from empty.
  bool get allUsersLoaded => _allUsersLoaded;

  /// Cached task lists — available immediately as initialData for StreamBuilders.
  List<TaskModel> get cachedOngoingTasks => _cachedOngoingTasks;
  List<TaskModel> get cachedPastTasks => _cachedPastTasks;
  List<TaskModel> get cachedCreatedTasks => _cachedCreatedTasks;

  /// Cached report-exempt user IDs — populated from `config/reportExemptUsers`.
  /// True once the first snapshot has arrived (even if empty).
  ///
  /// Returns an unmodifiable view — callers must copy before mutating:
  ///   final copy = Set<String>.from(cache.cachedExemptIds);
  Set<String> get cachedExemptIds => Set.unmodifiable(_cachedExemptIds);
  bool get exemptListLoaded => _exemptListLoaded;

  /// Update the in-memory exempt list immediately (optimistic toggle).
  /// Call this from ReportExemptScreen before the Cloud Function write.
  void setExemptIds(Set<String> ids) {
    _cachedExemptIds = Set<String>.from(ids); // defensive copy
    notifyListeners();
  }

  /// Clear the cached task lists — call on pull-to-refresh so screens
  /// show a spinner instead of stale initialData while the new stream loads.
  void clearTaskCache() {
    _cachedOngoingTasks = [];
    _cachedPastTasks = [];
    _cachedCreatedTasks = [];
    notifyListeners();
  }


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
    if (_currentUserId == userId) {
      debugPrint('DataCacheProvider: Already initialized for $userId, skipping.');
      return;
    }
    
    debugPrint('DataCacheProvider: Initializing for $userId (isSuperAdmin: $isSuperAdmin)');
    cancelAll();
    _currentUserId = userId;

    // Always listen to the exempt list (Super Admin only uses it, but
    // subscribing for all roles is harmless — Firestore rules protect the doc).
    if (isSuperAdmin) {
      _exemptSubscription = FirebaseFirestore.instance
          .collection('config')
          .doc('reportExemptUsers')
          .snapshots()
          .listen((doc) {
        final ids = doc.exists
            ? Set<String>.from((doc.data()?['userIds'] as List? ?? []))
            : <String>{};
        _cachedExemptIds = ids;
        _exemptListLoaded = true;
        notifyListeners();
      }, onError: (e) {
        debugPrint('DataCacheProvider: Error listening to exempt list: $e');
        _exemptListLoaded = true; // Unblock UI even on error
        notifyListeners();
      });
    } else {
      // Non-super-admins never use the exempt list.
      // Set loaded=true immediately so any screen that checks this flag
      // does not show a permanent spinner if routing guards ever fail.
      _exemptListLoaded = true;
    }
    
    // Listen to notification unread count
    _unreadSubscription = _notificationRepository.getUnreadCountStream(userId).listen((newCount) {
      if (_unreadCount != newCount) {
        _unreadCount = newCount;
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
          .listen((tasks) {
        _cachedOngoingTasks = tasks;
        final filtered = tasks.where((t) => t.createdBy != userId && !t.isOverdue).toList();
        if (_assignedCount != filtered.length) {
          _assignedCount = filtered.length;
        }
        notifyListeners();
      });

      _createdSubscription = _taskRepository
          .getCreatedTasksStream(userId)
          .listen((tasks) {
        _cachedCreatedTasks = tasks;
        final filtered = tasks.where((t) => t.status == TaskStatus.ongoing && !t.isOverdue).toList();
        if (_createdCount != filtered.length) {
          _createdCount = filtered.length;
        }
        notifyListeners();
      });

      _overdueSubscription = _taskRepository
          .getUserCalendarTasksStream(userId)
          .listen((tasks) {
        final filtered = tasks.where((t) => t.status == TaskStatus.ongoing && t.isOverdue).toList();
        if (_overdueCount != filtered.length) {
          _overdueCount = filtered.length;
          notifyListeners();
        }
      });

      _completedSubscription = _taskRepository.getPastAssignedTasksStream(userId).listen((tasks) {
        _cachedPastTasks = tasks;
        if (_completedCount != tasks.length) {
          _completedCount = tasks.length;
        }
        notifyListeners();
      });

    } else {
      // Admin Dashboard Specific Listeners
      _usersSubscription = _userRepository.getAllUsersStream().listen((users) {
        _allUsers = users;
        _allUsersLoaded = true; // Mark loaded on first (and every) snapshot
        // Also update individual cache for quick lookup
        final now = DateTime.now();
        for (final user in users) {
          _userCache[user.id] = user;
          _userCacheTimestamps[user.id] = now;
        }
        final total = users.length;
        final pending = users.where((u) => u.status == UserStatus.pending).length;
        if (_totalUsersCount != total || _pendingUsersCount != pending) {
          _totalUsersCount = total;
          _pendingUsersCount = pending;
        }
        // Always notify — list contents may have changed even if counts haven't
        notifyListeners();
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
    _currentUserId = null;
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
    _exemptSubscription?.cancel();

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
    _allUsersLoaded = false;

    // Clear user cache to prevent stale data across logout/login
    _userCache.clear();
    _userCacheTimestamps.clear();
    _fetchingUserIds.clear();
    _cachedOngoingTasks = [];
    _cachedPastTasks = [];
    _cachedCreatedTasks = [];
    _cachedExemptIds = {};
    _exemptListLoaded = false;
  }

  @override
  void dispose() {
    cancelAll();
    super.dispose();
  }
}
