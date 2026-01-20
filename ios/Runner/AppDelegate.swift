import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("🚀 [AppDelegate] Starting didFinishLaunchingWithOptions...")
    
    // Note: Firebase is configured by Flutter's firebase_core plugin in main.dart
    // Do NOT call FirebaseApp.configure() here - it causes duplicate initialization crashes
    
    print("🔔 [AppDelegate] Setting up UNUserNotificationCenter...")
    // Set up UNUserNotificationCenter delegate for foreground notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      print("✅ [AppDelegate] UNUserNotificationCenter delegate set")
    }
    
    print("📱 [AppDelegate] Registering for remote notifications...")
    // Register for remote notifications
    application.registerForRemoteNotifications()
    print("✅ [AppDelegate] Remote notifications registered")
    
    print("🔌 [AppDelegate] Registering Flutter plugins...")
    GeneratedPluginRegistrant.register(with: self)
    print("✅ [AppDelegate] Flutter plugins registered")
    
    print("🎯 [AppDelegate] Calling super.application...")
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    print("✅ [AppDelegate] super.application returned: \(result)")
    
    return result
  }
  
  // Handle foreground notification presentation - show alert even when app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Show notification banner, play sound, and update badge even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .sound, .badge]])
    } else {
      completionHandler([[.alert, .sound, .badge]])
    }
  }
  
  // Handle notification tap - just opens the app (no deep linking per user requirement)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    // Let Flutter plugin handle the notification tap
    // This will simply open the app to the last visible screen
    completionHandler()
  }
}
