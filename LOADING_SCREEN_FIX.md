# Loading Screen Hang Fix

## Problem
After reinstalling the app, it gets stuck on the loading screen and never shows the home screen.

## Root Cause
The app was trying to initialize AWS Amplify during startup, but the Amplify configuration file (`amplifyconfiguration.json`) is missing. This caused the initialization to hang indefinitely, blocking the entire app from starting.

## Solution
Added a 10-second timeout to the Amplify initialization in `main.dart`. If Amplify doesn't initialize within 10 seconds, the app will:
1. Log a timeout message
2. Continue in local-only mode (without cloud sync)
3. Show the home screen normally

### Changes Made
**File**: `lib/main.dart`

1. Added `dart:async` import for `TimeoutException`
2. Wrapped Amplify initialization with a `.timeout()` call
3. Set timeout to 10 seconds
4. Added better error logging

Before:
```dart
try {
  await AmplifyService().initialize();
  debugPrint('Amplify initialized successfully');
} catch (e) {
  debugPrint('Failed to initialize Amplify: $e');
  // App can still work in local-only mode
}
```

After:
```dart
try {
  await AmplifyService().initialize().timeout(
    const Duration(seconds: 10),
    onTimeout: () {
      debugPrint('Amplify initialization timed out - continuing in local-only mode');
      throw TimeoutException('Amplify initialization timed out');
    },
  );
  debugPrint('Amplify initialized successfully');
} catch (e) {
  debugPrint('Failed to initialize Amplify: $e');
  debugPrint('App will run in local-only mode');
  // App can still work in local-only mode
}
```

## Impact
- The app will no longer hang on the loading screen
- If Amplify configuration is missing or fails, the app continues in local-only mode
- Users can still use all local features (documents, files, labels)
- Cloud sync features will be disabled until Amplify is properly configured

## Testing
1. Rebuild and install the app: `flutter run`
2. The app should now start within 10 seconds
3. Check the console for one of these messages:
   - "Amplify initialized successfully" - Cloud sync is working
   - "Amplify initialization timed out" - Running in local-only mode
   - "Failed to initialize Amplify" - Running in local-only mode

## If Still Hanging

If the app still hangs after the fix, try these steps:

### Step 1: Check Console Output
Look for these messages in the console:
- "Database initialized successfully"
- "Notifications initialized successfully"
- "Amplify initialization timed out" or "Failed to initialize Amplify"

If you don't see "Database initialized successfully", the database is the problem.

### Step 2: Test with Minimal Version
Temporarily use the minimal version to test if the app can start at all:

1. Rename `lib/main.dart` to `lib/main_full.dart`
2. Rename `lib/main_minimal.dart` to `lib/main.dart`
3. Run the app: `flutter run`

If the app starts with the minimal version, the problem is in one of the services (database, notifications, or Amplify).

### Step 3: Check for Errors
Run the app and check for errors:
```bash
flutter run --verbose
```

Look for:
- Database errors (SQLite issues)
- Permission errors (notifications)
- Network errors (Amplify)

### Step 4: Clear All Data
If nothing works, clear all app data:

**On Android:**
```bash
flutter clean
cd android
./gradlew clean
cd ..
flutter run
```

**On iOS:**
```bash
flutter clean
cd ios
rm -rf Pods
rm Podfile.lock
pod install
cd ..
flutter run
```

## Common Issues

### Database Initialization Hanging
If the database is hanging:
- The database file might be corrupted
- SQLite might not have permissions
- Solution: Clear app data or uninstall completely

### Notification Initialization Hanging
If notifications are hanging:
- Permission dialogs might be blocking
- Notification service might be misconfigured
- Solution: Comment out notification initialization temporarily

### Amplify Hanging Despite Timeout
If Amplify is still hanging:
- The timeout might not be working
- Amplify might be blocking before the timeout starts
- Solution: Move Amplify initialization to background (already done in latest fix)

## Latest Fix (v2)

The latest version of `main.dart` now:
1. Starts the app immediately
2. Initializes Amplify in the background
3. Adds error handling for database and notifications
4. Logs all initialization steps

This ensures the app UI appears even if services fail to initialize.

## Files Modified
- `lib/main.dart` - Made Amplify initialization non-blocking, added error handling
- `lib/main_minimal.dart` - Created minimal version for testing
