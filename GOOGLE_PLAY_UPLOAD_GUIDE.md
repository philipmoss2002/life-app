# Google Play Console Upload Guide

## AAB File Location

Your Android App Bundle (AAB) file is located at:
```
build/app/outputs/bundle/release/app-release.aab
```

**File Size:** 54.1MB
**Generated:** Just now with `flutter build appbundle --release`

## Upload Steps

### 1. Access Google Play Console
- Go to [play.google.com/console](https://play.google.com/console)
- Sign in with your Google Developer account

### 2. Select or Create App
- Choose your existing "Life App" or create new app
- If creating new: Set up app details, content rating, etc.

### 3. Upload AAB File

#### For Testing (Recommended First):
1. Go to **Testing** → **Internal testing**
2. Click **Create new release**
3. Upload `app-release.aab`
4. Add release notes
5. Save and review
6. Start rollout to testers

#### For Production:
1. Go to **Production**
2. Click **Create new release**
3. Upload `app-release.aab`
4. Add release notes
5. Complete all required sections
6. Submit for review

### 4. Required Information

Before uploading, ensure you have:

- [ ] **App Details:** Title, description, screenshots
- [ ] **Content Rating:** Complete questionnaire
- [ ] **Target Audience:** Age groups
- [ ] **Privacy Policy:** Required for apps with sensitive permissions
- [ ] **App Category:** Productivity/Business
- [ ] **Store Listing:** Screenshots, feature graphic

## App Signing

### Current Status
The AAB was built without custom signing. Google Play will handle app signing.

### For Production (Recommended)
Set up proper app signing:

1. **Generate Upload Key:**
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. **Create key.properties:**
```
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=upload-keystore.jks
```

3. **Update android/app/build.gradle:**
```gradle
android {
    ...
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

4. **Build Signed AAB:**
```bash
flutter build appbundle --release
```

## App Information

### Current App Details
- **Package Name:** com.example.household_docs_app
- **App Name:** Life App
- **Version:** Check pubspec.yaml
- **Min SDK:** Android 5.0 (API 21)
- **Target SDK:** Latest

### Recommended Changes for Production
1. **Update Package Name:**
   - Change from `com.example.household_docs_app`
   - To something like `com.yourcompany.lifeapp`

2. **Update App Name:**
   - Consider "Life Documents" or "Document Manager"

3. **Add App Icon:**
   - 512x512 PNG for Play Store
   - Various sizes for app (already configured)

## Store Listing Requirements

### Screenshots (Required)
- **Phone:** At least 2 screenshots (1080x1920 or 1080x2340)
- **Tablet:** At least 1 screenshot (1200x1920 or 1600x2560)

### Graphics
- **Feature Graphic:** 1024x500 PNG/JPG
- **App Icon:** 512x512 PNG (32-bit with alpha)

### Description
```
Life App - Your Personal Document Manager

Organize and manage your important documents with ease. Perfect for household documents, insurance papers, warranties, and more.

Features:
• Document organization by category
• Photo capture and PDF storage
• Renewal date reminders
• Secure local storage
• Clean, intuitive interface

Categories include:
• Insurance documents
• Mortgage/Rent papers
• Holiday bookings
• Warranties
• Medical records
• And more...

Keep your important documents organized and never miss a renewal date again!
```

## Testing Before Production

### Internal Testing
1. Upload AAB to Internal Testing
2. Add test users (your email addresses)
3. Test core functionality:
   - Document creation
   - Photo capture
   - Category filtering
   - Date reminders
   - App navigation

### Closed Testing (Optional)
- Invite friends/family to test
- Get feedback on usability
- Fix any reported issues

## Common Issues

### Upload Errors
- **"Upload failed":** Check file size (max 150MB)
- **"Invalid AAB":** Rebuild with `flutter clean` first
- **"Signature issues":** Ensure proper signing setup

### Review Rejections
- **Privacy Policy:** Required for camera/storage permissions
- **Content Rating:** Must be completed accurately
- **Target Audience:** Must match app content

## Quick Commands

### Build AAB
```bash
cd household_docs_app
flutter clean
flutter pub get
flutter build appbundle --release
```

### Check AAB Details
```bash
# Install bundletool
# Download from: https://github.com/google/bundletool/releases

# Extract APKs from AAB
java -jar bundletool.jar build-apks --bundle=app-release.aab --output=app.apks

# Install on device
java -jar bundletool.jar install-apks --apks=app.apks
```

## File Locations

- **AAB File:** `build/app/outputs/bundle/release/app-release.aab`
- **APK Files:** `build/app/outputs/flutter-apk/` (if built)
- **Signing Key:** Store securely, backup multiple locations

## Next Steps

1. **Immediate:** Upload current AAB to Internal Testing
2. **Short-term:** Set up proper app signing
3. **Before Production:** Complete all store listing requirements
4. **Production:** Submit for review (can take 1-7 days)

## Support Resources

- [Google Play Console Help](https://support.google.com/googleplay/android-developer/)
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/android)
- [Android App Bundle Guide](https://developer.android.com/guide/app-bundle)

---

**Current AAB Status:** ✅ Ready for upload
**File Size:** 54.1MB
**Location:** `build/app/outputs/bundle/release/app-release.aab`