# Testing on Physical Devices

## Method 1: USB Connection (Recommended for Development)

### Android Device

1. **Enable Developer Options on your Android device:**
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
   - You'll see "You are now a developer!"

2. **Enable USB Debugging:**
   - Go to Settings → Developer Options
   - Enable "USB Debugging"
   - Enable "Install via USB" (if available)

3. **Connect your device:**
   - Connect your Android device to your computer via USB
   - On your device, allow USB debugging when prompted
   - Trust this computer

4. **Verify connection:**
   ```bash
   flutter devices
   ```
   You should see your device listed

5. **Run the app:**
   ```bash
   cd household_docs_app
   flutter run
   ```
   Or specify the device:
   ```bash
   flutter run -d <device-id>
   ```

### iOS Device (Mac only)

1. **Requirements:**
   - Mac computer with Xcode installed
   - Apple Developer account (free or paid)
   - iOS device with cable

2. **Setup:**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select your device from the device dropdown
   - Sign the app with your Apple ID (Xcode → Signing & Capabilities)

3. **Run:**
   ```bash
   flutter run
   ```

## Method 2: Build APK/IPA for Installation

### Android APK (Debug Build)

1. **Build the APK:**
   ```bash
   cd household_docs_app
   flutter build apk --debug
   ```
   The APK will be at: `build/app/outputs/flutter-apk/app-debug.apk`

2. **Transfer to device:**
   - Email the APK to yourself
   - Use Google Drive, Dropbox, or USB transfer
   - Use ADB: `adb install build/app/outputs/flutter-apk/app-debug.apk`

3. **Install on device:**
   - Open the APK file on your Android device
   - Allow installation from unknown sources if prompted
   - Tap Install

### Android APK (Release Build)

For a smaller, optimized APK:
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (For Play Store)

```bash
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

## Method 3: Wireless Debugging (Android 11+)

1. **Enable Wireless Debugging:**
   - Settings → Developer Options → Wireless Debugging
   - Enable it

2. **Pair device:**
   - Tap "Pair device with pairing code"
   - On your computer:
   ```bash
   adb pair <ip-address>:<port>
   ```
   - Enter the pairing code shown on device

3. **Connect:**
   ```bash
   adb connect <ip-address>:<port>
   ```

4. **Run app:**
   ```bash
   flutter run
   ```

## Method 4: Firebase App Distribution (Team Testing)

1. **Setup Firebase:**
   - Create a Firebase project
   - Add your app to Firebase
   - Install Firebase CLI

2. **Build and upload:**
   ```bash
   flutter build apk --release
   firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
     --app <your-app-id> \
     --groups testers
   ```

3. **Testers receive:**
   - Email invitation
   - Download link
   - Install directly from Firebase

## Quick Commands Reference

### Check connected devices:
```bash
flutter devices
```

### Run on specific device:
```bash
flutter run -d <device-id>
```

### Build debug APK:
```bash
flutter build apk --debug
```

### Build release APK:
```bash
flutter build apk --release
```

### Install APK via ADB:
```bash
adb install path/to/app.apk
```

### Uninstall app:
```bash
adb uninstall com.example.household_docs_app
```

## Troubleshooting

### Device not detected:
- Check USB cable (use data cable, not charge-only)
- Restart ADB: `adb kill-server` then `adb start-server`
- Try different USB port
- Reinstall device drivers (Windows)

### "App not installed" error:
- Uninstall any existing version first
- Enable "Install unknown apps" for your file manager
- Check storage space on device

### Signature conflicts:
- Uninstall the existing app completely
- Or use the same signing key for both builds

## Current App Details

- **Package Name:** com.example.household_docs_app
- **App Name:** Life App
- **Minimum SDK:** Android 5.0 (API 21)
- **Target SDK:** Latest

## Next Steps for Production

For releasing to the Play Store or App Store, you'll need to:
1. Create proper signing keys
2. Update app package name
3. Add privacy policy
4. Create store listings
5. Follow platform-specific guidelines
