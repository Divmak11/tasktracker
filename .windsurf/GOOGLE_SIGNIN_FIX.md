# Google Sign-In Configuration Fix

## Issue
```
E/GoogleApiManager: java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'
W/GoogleApiManager: Not showing notification since connectionResult is not user-facing: ConnectionResult{statusCode=DEVELOPER_ERROR}
```

## Root Cause
This error occurs when Firebase Console doesn't have the correct SHA-1 and SHA-256 fingerprints for your app. Google Play Services uses these to verify your app's identity.

## Solution

### Step 1: Get Your App's SHA Fingerprints

#### For Debug Build (During Development)
```bash
# On macOS/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# On Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

#### For Release Build (Production)
```bash
# Replace with your actual keystore path and alias
keytool -list -v -keystore /path/to/your/release-keystore.jks -alias your-alias-name
```

#### Alternative: Using Gradle Task
```bash
cd android
./gradlew signingReport
```

### Step 2: Add SHA Fingerprints to Firebase Console

1. **Go Firebase Console**: https://console.firebase.google.com/
2. **Select your project**: `todo-taskmanager-25ab4`
3. **Navigate to Project Settings**:
   - Click the gear icon (⚙️) next to "Project Overview"
   - Select "Project settings"
4. **Select Your Android App**:
   - Scroll down to "Your apps" section
   - Click on your Android app (com.innovlabs.taskmanager)
5. **Add SHA Fingerprints**:
   - Scroll to "SHA certificate fingerprints" section
   - Click "Add fingerprint" button
   - Paste the **SHA-1** hash you got from the keytool command
   - Click "Add fingerprint" again
   - Paste the **SHA-256** hash
   - Click "Save" (if available)

### Step 3: Download Updated google-services.json

1. In Firebase Console (same page)
2. Scroll to the bottom
3. Click "Download google-services.json"
4. Replace the existing file in your project:
   ```
   android/app/google-services.json
   ```

### Step 4: Rebuild and Test

```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Rebuild app
flutter run
```

## Verification

After rebuilding, the Google Sign-In should work without errors. Check the logs:
- ✅ No more "Unknown calling package name" errors
- ✅ No more "DEVELOPER_ERROR" messages
- ✅ Google Sign-In account picker appears correctly

## Additional Notes

### Multiple Build Variants
If you have debug and release builds, add BOTH sets of SHA fingerprints:
- Debug SHA-1 and SHA-256
- Release SHA-1 and SHA-256

### Team Development
If multiple developers are working on the project, each developer's debug keystore will have different SHA fingerprints. You need to add all of them to Firebase.

### CI/CD Pipeline
If using CI/CD (like GitHub Actions, CircleCI), add the CI's keystore SHA fingerprints as well.

## Quick Reference

### Extract SHA-1 from signingReport Output
```bash
# Run signing report
cd android && ./gradlew signingReport > signing_report.txt

# Look for lines like:
# SHA1: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD
# SHA-256: AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB
```

### Current Package Name
- **Android**: `com.innovlabs.taskmanager`
- **Firebase Project**: `todo-taskmanager-25ab4`

### Status
- ⚠️ **Action Required**: Add SHA fingerprints to Firebase Console
- 🔧 **Priority**: High (blocks Google Sign-In functionality)
- ⏱️ **Time to Fix**: 5-10 minutes
