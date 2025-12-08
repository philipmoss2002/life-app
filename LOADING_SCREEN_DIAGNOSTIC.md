# Loading Screen Diagnostic Guide

## Problem
App is stuck on loading screen after reinstalling.

## Quick Diagnostic Steps

### 1. Check What's Printed
Run the app and watch the console. You should see these messages in order:

```
Starting app...
Database initialized successfully
Notifications initialized successfully
Amplify initialization timed out - continuing in local-only mode
(or)
Amplify initialized successfully
```

**If you see nothing**: The app isn't even starting - check for compile errors

**If you see "Database initialized" but nothing after**: Notifications are hanging

**If you see "Notifications initialized" but nothing after**: Amplify is hanging (despite timeout)

### 2. Test with Minimal Version

Create a test to see if the app can start without any services:

```bash
# Backup current main
mv lib/main.dart lib/main_full.dart

# Use minimal version
mv lib/main_minimal.dart lib/main.dart

# Run
flutter run
```

If this works, the problem is in one of the services. Restore the full version:
```bash
mv lib/main.dart lib/main_minimal.dart
mv lib/main_full.dart lib/main.dart
```

### 3. Disable Services One by One

Edit `lib/main.dart` and comment out services to find the culprit:

**Test 1: Disable Amplify**
```dart
// _initializeAmplifyInBackground();  // Comment this out
```

**Test 2: Disable Notifications**
```dart
// try {
//   await NotificationService.instance.initialize();
//   debugPrint('Notifications initialized successfully');
// } catch (e) {
//   debugPrint('Failed to initialize notifications: $e');
// }
```

**Test 3: Disable Database**
```dart
// try {
//   await DatabaseService.instance.database;
//   debugPrint('Database initialized successfully');
// } catch (e) {
//   debugPrint('Failed to initialize database: $e');
// }
```

### 4. Check for Specific Errors

Run with verbose logging:
```bash
flutter run --verbose 2>&1 | tee app_log.txt
```

Look for:
- `SQLException` - Database problem
- `PermissionException` - Permissions problem
- `NetworkException` - Amplify/network problem
- `TimeoutException` - Something is taking too long

## Common Solutions

### Solution 1: Clear Everything
```bash
flutter clean
flutter pub get
flutter run
```

### Solution 2: Reset Device/Emulator
Sometimes the device itself has issues:
- Restart the emulator
- Or restart your physical device
- Then try again

### Solution 3: Check Permissions
On Android, check `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

### Solution 4: Disable AuthProvider
The AuthProvider might be trying to check auth status on startup. Edit `lib/main.dart`:

```dart
// Comment out the provider temporarily
return MaterialApp(  // Remove ChangeNotifierProvider wrapper
  title: 'Household Docs',
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    useMaterial3: true,
  ),
  home: const HomeScreen(),
);
```

## What to Report

If none of these work, please share:

1. **Console output** - Everything printed when you run the app
2. **Last message** - What's the last thing printed before it hangs?
3. **Platform** - Android or iOS? Emulator or physical device?
4. **Flutter version** - Run `flutter --version`
5. **Minimal test result** - Does the minimal version work?

This information will help identify exactly where it's hanging.

## Emergency Workaround

If you need the app working NOW and can't wait for a fix:

1. Use the minimal version (no database, no notifications, no Amplify)
2. This will let you see the UI and test basic functionality
3. Features that won't work:
   - Saving documents (no database)
   - Notifications (no notification service)
   - Cloud sync (no Amplify)
   - Authentication (no Amplify)

But you can at least see the UI and test the layout/navigation.
