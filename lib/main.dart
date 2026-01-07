import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/env_config.dart';
import 'core/router/app_router.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/theme_provider.dart';
import 'data/providers/data_cache_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables first (needed for EnvConfig)
  await dotenv.load(fileName: ".env");

  // Set up global error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Only print detailed error info in development mode
    if (!EnvConfig.isProduction) {
      debugPrint('🔴 Flutter Error: ${details.exception}');
      debugPrint('Stack trace: ${details.stack}');
    }
    // In production, you could send this to a crash reporting service like Crashlytics
  };

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Firebase Analytics
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  
  // Enable Analytics collection (it's enabled by default, but this ensures it)
  await analytics.setAnalyticsCollectionEnabled(true);
  
  // Log app start event
  await analytics.logAppOpen();
  
  // Log a test event to verify configuration
  await analytics.logEvent(
    name: 'analytics_config_verified',
    parameters: {'timestamp': DateTime.now().toIso8601String()},
  );
  
  debugPrint('✅ Firebase Analytics initialized and test event logged');
  if (!EnvConfig.isProduction) {
    debugPrint('📊 Analytics Instance ID: ${analytics.app.name}');
  }

  // Note: Firebase Auth persistence is automatically enabled on mobile platforms
  // setPersistence() is only supported on web and will throw UnimplementedError on mobile
  // Mobile apps have persistent auth by default - no configuration needed

  // Enable Firestore persistence for offline support and faster reads
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Request notification permissions (iOS requires explicit permission)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Create Android notification channel with sound (required for Android 8.0+)
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'todo_planner_channel', // Must match backend channelId
    'Task Notifications',
    description: 'Notifications for task assignments and updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  debugPrint('✅ Android notification channel created with sound enabled');

  // Initialize Theme
  final themeProvider = ThemeProvider();
  try {
    await themeProvider.initialize();
    debugPrint('✅ Theme provider initialized');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize theme provider: $e');
    // App will continue with default theme
  }

  runApp(MyApp(themeProvider: themeProvider));
}

class MyApp extends StatefulWidget {
  final ThemeProvider themeProvider;

  const MyApp({super.key, required this.themeProvider});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthProvider _authProvider;
  late final DataCacheProvider _dataCacheProvider;
  late final GoRouter _router;
  late final FirebaseAnalytics _analytics;
  late final FirebaseAnalyticsObserver _analyticsObserver;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _dataCacheProvider = DataCacheProvider();
    _analytics = FirebaseAnalytics.instance;
    _analyticsObserver = FirebaseAnalyticsObserver(analytics: _analytics);
    _router = AppRouter.createRouter(_authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: widget.themeProvider),
        ChangeNotifierProvider.value(value: _dataCacheProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp.router(
            title: AppStrings.appName,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.effectiveThemeMode,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
            // Note: GoRouter handles analytics via routerConfig observers internally
            // The observer is configured in AppRouter.createRouter()
          );
        },
      ),
    );
  }
}
