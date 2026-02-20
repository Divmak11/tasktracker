import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for checking app updates via Firebase Remote Config
/// 
/// Features:
/// - Checks for new versions on app launch (max once per 24h)
/// - Supports optional and forced updates
/// - Tracks dismissal timestamps for optional updates
/// - Re-prompts after 2-3 days if dismissed
/// - Platform-specific store redirects
class UpdateCheckService {
  static final UpdateCheckService _instance = UpdateCheckService._internal();
  factory UpdateCheckService() => _instance;
  UpdateCheckService._internal();

  late final FirebaseRemoteConfig _remoteConfig;
  late final PackageInfo _packageInfo;
  bool _isInitialized = false;
  static bool _isCheckingForUpdates = false;

  // Shared Preferences keys
  static const String _keyLastCheck = 'last_update_check';
  static const String _keyDismissedAt = 'update_dismissed_at';
  static const String _keyDismissedVersion = 'dismissed_version';

  // Constants
  static const Duration _checkCooldown = Duration(hours: 24);
  static const Duration _dismissalReminderDuration = Duration(days: 2, hours: 12);

  /// Default Remote Config values (fallback)
  static const Map<String, dynamic> _defaults = {
    'latest_version': '1.0.1',
    'force_update': false,
    'update_title': 'Update Available',
    'update_message':
        'A new version of TODO Planner is available. Update now to enjoy the latest features and improvements.',
    'android_store_url':
        'https://play.google.com/store/apps/details?id=com.innovlabs.taskmanager',
    'ios_store_url': 'https://apps.apple.com/app/id0000000000', // Placeholder
  };

  /// Get current app version from PackageInfo
  String get currentVersion => _packageInfo.version;

  /// Get latest version from Remote Config
  String get latestVersion => _remoteConfig.getString('latest_version');

  /// Check if update is forced
  bool get isForceUpdate => _remoteConfig.getBool('force_update');

  /// Get update dialog title
  String get updateTitle => _remoteConfig.getString('update_title');

  /// Get update dialog message
  String get updateMessage => _remoteConfig.getString('update_message');

  /// Get store URL based on platform
  String get storeUrl {
    if (Platform.isAndroid) {
      return _remoteConfig.getString('android_store_url');
    } else if (Platform.isIOS) {
      return _remoteConfig.getString('ios_store_url');
    }
    return _defaults['android_store_url'] as String;
  }

  /// Initialize the service
  /// 
  /// Must be called before using checkForUpdates()
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Remote Config
      _remoteConfig = FirebaseRemoteConfig.instance;

      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // In debug mode: Duration.zero so every launch fetches fresh config
        // from the Firebase RC server. This is the Firebase-recommended pattern
        // for development — it allows force_update flag changes to be picked up
        // immediately without waiting for the cache TTL to expire.
        //
        // In production: 1 h interval prevents excessive RC server calls.
        // Forced updates in prod take effect within 1 h of publish — acceptable.
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));

      await _remoteConfig.setDefaults(_defaults);

      // Get package info
      _packageInfo = await PackageInfo.fromPlatform();

      _isInitialized = true;

      if (kDebugMode) {
        debugPrint('UpdateCheckService initialized');
        debugPrint('   Current version: ${_packageInfo.version}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to initialize UpdateCheckService: $e');
      }
      // Continue with defaults, don't block app
    }
  }

  /// Check for app updates.
  ///
  /// Returns an [UpdateInfo] object if an update is available and should be
  /// shown, null otherwise.
  ///
  /// Flow:
  /// 1. Always fetch Remote Config so we see the latest force_update flag.
  ///    Firebase enforces its own rate limit via [minimumFetchInterval] (1 h),
  ///    so this is safe to call on every launch.
  /// 2. Compare versions. If no update needed, return null.
  /// 3. If forced → always show (bypasses cooldown + dismissal tracking).
  /// 4. If optional → apply 24 h cooldown + dismissal tracking.
  ///
  /// This ordering is critical: the cooldown must NOT gate the fetch, because
  /// a Remote Config change from force_update=false → force_update=true would
  /// never be seen until 24 h expired under the old ordering.
  Future<UpdateInfo?> checkForUpdates() async {
    if (_isCheckingForUpdates) {
      if (kDebugMode) debugPrint('Update check already in progress, skipping');
      return null;
    }

    _isCheckingForUpdates = true;

    try {
      if (!_isInitialized) {
        await initialize();
      }

      // ── Step 1: Always fetch the latest Remote Config. ─────────────────────
      // Firebase caches the result and only hits the network when
      // minimumFetchInterval (1 h) has elapsed, so this is cheap on repeat
      // launches within the same hour.
      await _fetchRemoteConfig();

      // ── Step 2: Version comparison. ─────────────────────────────────────────
      final latestVer = latestVersion;
      final currentVer = currentVersion;

      if (kDebugMode) {
        debugPrint('Version check: current=$currentVer, latest=$latestVer');
      }

      if (!_shouldUpdate(currentVer, latestVer)) {
        if (kDebugMode) debugPrint('App is up to date');
        return null;
      }

      final isForced = isForceUpdate;

      if (kDebugMode) {
        debugPrint('Update available: $latestVer (forced: $isForced)');
      }

      // ── Step 3: Forced update → always show. ────────────────────────────────
      // Bypass the 24 h cooldown and any dismissal record entirely.
      // The admin set force_update=true precisely to override user decisions.
      if (isForced) {
        return UpdateInfo(
          currentVersion: currentVer,
          latestVersion: latestVer,
          isForced: true,
          title: updateTitle,
          message: updateMessage,
          storeUrl: storeUrl,
        );
      }

      // ── Step 4: Optional update → apply cooldown + dismissal tracking. ──────
      if (!await _shouldCheckForUpdates()) {
        if (kDebugMode) debugPrint('Optional update: 24 h cooldown active, skipping');
        return null;
      }

      // Record that we consumed this optional-check slot.
      await _updateLastCheckTimestamp();

      if (!await _shouldShowAfterDismissal(latestVer)) {
        if (kDebugMode) debugPrint('Optional update dismissed recently, skipping');
        return null;
      }

      return UpdateInfo(
        currentVersion: currentVer,
        latestVersion: latestVer,
        isForced: false,
        title: updateTitle,
        message: updateMessage,
        storeUrl: storeUrl,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking for updates: $e');
      }
      return null; // Graceful degradation — never block app launch
    } finally {
      _isCheckingForUpdates = false;
    }
  }


  /// Fetch and activate Remote Config
  Future<void> _fetchRemoteConfig() async {
    try {
      await _remoteConfig.fetchAndActivate();
      if (kDebugMode) debugPrint('Remote Config fetched and activated');
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to fetch Remote Config: $e');
        debugPrint('   Using cached or default values');
      }
      // Continue with cached/default values
    }
  }

  /// Check if 24h has passed since last check
  Future<bool> _shouldCheckForUpdates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_keyLastCheck) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      return (now - lastCheck) > _checkCooldown.inMilliseconds;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking last update time: $e');
      return true; // If can't determine, allow check
    }
  }

  /// Update last check timestamp
  Future<void> _updateLastCheckTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastCheck, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) debugPrint('Error updating last check time: $e');
    }
  }

  /// Check if optional update should be shown after dismissal
  /// 
  /// Shows if:
  /// - Never dismissed this version, OR
  /// - More than 2-3 days since dismissal
  Future<bool> _shouldShowAfterDismissal(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedVersion = prefs.getString(_keyDismissedVersion);
      
      // Different version than dismissed, show it
      if (dismissedVersion != version) {
        return true;
      }

      // Same version was dismissed, check timestamp
      final dismissedAt = prefs.getInt(_keyDismissedAt) ?? 0;
      if (dismissedAt == 0) {
        return true; // No dismissal recorded
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - dismissedAt;
      
      return elapsed > _dismissalReminderDuration.inMilliseconds;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking dismissal: $e');
      return true; // If can't determine, show dialog
    }
  }

  /// Record that user dismissed the optional update
  Future<void> dismissOptionalUpdate(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDismissedVersion, version);
      await prefs.setInt(_keyDismissedAt, DateTime.now().millisecondsSinceEpoch);
      
      if (kDebugMode) {
        debugPrint('Update dismissed for version: $version');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error recording dismissal: $e');
    }
  }

  /// Compare version strings
  /// 
  /// Returns true if currentVersion < latestVersion
  /// Uses semantic versioning: MAJOR.MINOR.PATCH
  bool _shouldUpdate(String current, String latest) {
    try {
      final currentParts = _parseVersion(current);
      final latestParts = _parseVersion(latest);

      // Compare major.minor.patch
      for (int i = 0; i < 3; i++) {
        if (currentParts[i] < latestParts[i]) {
          return true; // Update needed
        } else if (currentParts[i] > latestParts[i]) {
          return false; // Current is newer
        }
      }

      return false; // Versions are equal
    } catch (e) {
      if (kDebugMode) debugPrint('Error comparing versions: $e');
      return false; // If can't parse, don't prompt update
    }
  }

  /// Parse version string to [major, minor, patch]
  /// 
  /// Handles formats like:
  /// - "1.0.1" → [1, 0, 1]
  /// - "1.0.1+2" → [1, 0, 1] (ignores build number)
  /// - "v1.0.1" → [1, 0, 1] (strips 'v' prefix)
  /// - "1.0" → [1, 0, 0] (pads missing segments)
  List<int> _parseVersion(String version) {
    // Clean version string
    String cleaned = version
        .replaceAll(RegExp(r'^v'), '') // Remove 'v' prefix
        .split('+')[0] // Remove build number
        .trim();

    // Split and parse
    final parts = cleaned.split('.');
    final result = <int>[];

    for (int i = 0; i < 3; i++) {
      if (i < parts.length) {
        result.add(int.tryParse(parts[i]) ?? 0);
      } else {
        result.add(0); // Pad with zeros if missing
      }
    }

    return result;
  }

  /// Open the appropriate app store
  /// 
  /// Returns true if successfully opened, false otherwise
  Future<bool> openStore() async {
    try {
      final url = storeUrl;
      final uri = Uri.parse(url);

      if (kDebugMode) debugPrint('Opening store: $url');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        // Fallback to web URL for Android
        if (Platform.isAndroid) {
          final webUrl = Uri.parse(
            'https://play.google.com/store/apps/details?id=com.innovlabs.taskmanager',
          );
          if (await canLaunchUrl(webUrl)) {
            await launchUrl(webUrl);
            return true;
          }
        }

        if (kDebugMode) debugPrint('Cannot open store URL');
        return false;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error opening store: $e');
      return false;
    }
  }

  /// Force check for updates (bypasses cooldown)
  /// 
  /// For debugging/testing only
  Future<UpdateInfo?> forceCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastCheck); // Reset cooldown
      return await checkForUpdates();
    } catch (e) {
      if (kDebugMode) debugPrint('Error in force check: $e');
      return null;
    }
  }

  /// Reset dismissal (for debugging/testing)
  Future<void> resetDismissal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDismissedVersion);
      await prefs.remove(_keyDismissedAt);
      if (kDebugMode) debugPrint('Dismissal reset');
    } catch (e) {
      if (kDebugMode) debugPrint('Error resetting dismissal: $e');
    }
  }
}

/// Update information returned by checkForUpdates()
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final bool isForced;
  final String title;
  final String message;
  final String storeUrl;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.isForced,
    required this.title,
    required this.message,
    required this.storeUrl,
  });

  @override
  String toString() {
    return 'UpdateInfo(current: $currentVersion, latest: $latestVersion, forced: $isForced)';
  }
}
