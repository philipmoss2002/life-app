# Deployment Guide

Complete guide for deploying the Household Documents App to production.

---

## Prerequisites

### Development Environment

- Flutter SDK 3.0.6 or higher
- Dart SDK 3.0.0 or higher
- Android Studio (for Android builds)
- Xcode (for iOS builds, macOS only)
- Git

### AWS Resources

- AWS Account with appropriate permissions
- AWS Amplify CLI installed and configured
- Cognito User Pool configured
- Cognito Identity Pool configured
- S3 Bucket with appropriate IAM policies

### App Store Accounts

- Google Play Developer Account (for Android)
- Apple Developer Account (for iOS)

---

## AWS Configuration

### 1. Cognito User Pool Setup

**Purpose:** User authentication

**Configuration:**
```
Pool Name: household-docs-users-prod
Sign-in Options: Email
Password Policy:
  - Minimum length: 8 characters
  - Require uppercase: Yes
  - Require lowercase: Yes
  - Require numbers: Yes
  - Require symbols: Yes
Email Verification: Required
MFA: Optional (recommended for production)
```

**Required Attributes:**
- Email (required)

**App Client:**
- Name: household-docs-app-client
- Auth flows: USER_PASSWORD_AUTH
- Token expiration: 30 days (refresh token)

---

### 2. Cognito Identity Pool Setup

**Purpose:** AWS credential management for S3 access

**Configuration:**
```
Identity Pool Name: household_docs_identity_pool_prod
Authentication Providers:
  - Cognito User Pool (from step 1)
Unauthenticated Access: Disabled
```

**IAM Roles:**

**Authenticated Role Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::household-docs-files-prod/private/${cognito-identity.amazonaws.com:sub}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::household-docs-files-prod"
      ],
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "private/${cognito-identity.amazonaws.com:sub}/*"
          ]
        }
      }
    }
  ]
}
```

---

### 3. S3 Bucket Setup

**Purpose:** File storage

**Configuration:**
```
Bucket Name: household-docs-files-prod
Region: us-east-1 (or your preferred region)
Versioning: Enabled (recommended)
Encryption: AES-256 (SSE-S3)
Public Access: Block all public access
CORS: Configured for Amplify
```

**CORS Configuration:**
```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

**Lifecycle Policy (Optional):**
```json
{
  "Rules": [
    {
      "Id": "DeleteOldVersions",
      "Status": "Enabled",
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 30
      }
    }
  ]
}
```

---

### 4. Amplify Configuration

**Generate Configuration:**

1. Install Amplify CLI:
```bash
npm install -g @aws-amplify/cli
```

2. Configure Amplify:
```bash
amplify configure
```

3. Initialize Amplify in project:
```bash
cd household_docs_app
amplify init
```

4. Add authentication:
```bash
amplify add auth
```

5. Add storage:
```bash
amplify add storage
```

6. Push configuration:
```bash
amplify push
```

7. Generate Flutter configuration:
```bash
amplify codegen models
```

**Configuration File:**

The `amplifyconfiguration.dart` file should be generated with:
- User Pool ID
- User Pool Client ID
- Identity Pool ID
- S3 Bucket name
- AWS Region

**Example:**
```dart
const amplifyconfig = '''{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify/cli",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "CredentialsProvider": {
          "CognitoIdentity": {
            "Default": {
              "PoolId": "us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
              "Region": "us-east-1"
            }
          }
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "us-east-1_xxxxxxxxx",
            "AppClientId": "xxxxxxxxxxxxxxxxxxxxxxxxxx",
            "Region": "us-east-1"
          }
        },
        "Auth": {
          "Default": {
            "authenticationFlowType": "USER_PASSWORD_AUTH"
          }
        }
      }
    }
  },
  "storage": {
    "plugins": {
      "awsS3StoragePlugin": {
        "bucket": "household-docs-files-prod",
        "region": "us-east-1",
        "defaultAccessLevel": "private"
      }
    }
  }
}''';
```

---

## Build Configuration

### 1. Update App Version

**File:** `pubspec.yaml`

```yaml
version: 2.0.0+1  # Format: major.minor.patch+buildNumber
```

**Versioning Strategy:**
- Major: Breaking changes
- Minor: New features
- Patch: Bug fixes
- Build Number: Increment for each release

---

### 2. Update App Name and Package

**Android:**

**File:** `android/app/build.gradle`
```gradle
android {
    defaultConfig {
        applicationId "com.yourcompany.household_docs"
        versionCode 1
        versionName "2.0.0"
    }
}
```

**File:** `android/app/src/main/AndroidManifest.xml`
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourcompany.household_docs">
    <application
        android:label="Household Docs"
        android:icon="@mipmap/ic_launcher">
    </application>
</manifest>
```

**iOS:**

**File:** `ios/Runner/Info.plist`
```xml
<key>CFBundleDisplayName</key>
<string>Household Docs</string>
<key>CFBundleIdentifier</key>
<string>com.yourcompany.householdDocs</string>
<key>CFBundleShortVersionString</key>
<string>2.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

---

### 3. Configure App Icons

**Generate Icons:**

1. Create icon image (1024x1024 PNG)
2. Use flutter_launcher_icons package:

**File:** `pubspec.yaml`
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
```

3. Generate icons:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

---

### 4. Configure Signing

#### Android Signing

**Generate Keystore:**
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**File:** `android/key.properties`
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=../upload-keystore.jks
```

**File:** `android/app/build.gradle`
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
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

**Security:**
- Add `key.properties` to `.gitignore`
- Store keystore securely (backup!)
- Never commit keystore or passwords

#### iOS Signing

**Configure in Xcode:**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Go to Signing & Capabilities
4. Select your team
5. Configure bundle identifier
6. Enable automatic signing (or manual with provisioning profiles)

---

## Build Process

### Android Build

#### Debug Build
```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

#### Release Build (APK)
```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

#### Release Build (App Bundle - Recommended for Play Store)
```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

**App Bundle Benefits:**
- Smaller download size
- Dynamic delivery
- Required for new apps on Play Store

---

### iOS Build

#### Debug Build
```bash
flutter build ios --debug
```

#### Release Build
```bash
flutter build ios --release
```

**Archive in Xcode:**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Any iOS Device" as target
3. Product → Archive
4. Distribute App → App Store Connect
5. Upload to App Store Connect

---

## Testing Before Release

### Pre-Release Checklist

- [ ] All automated tests passing
- [ ] Manual E2E testing completed
- [ ] AWS configuration verified
- [ ] IAM policies tested
- [ ] Authentication flow tested
- [ ] File upload/download tested
- [ ] Sync functionality tested
- [ ] Offline mode tested
- [ ] Error handling tested
- [ ] Performance tested
- [ ] Security audit completed
- [ ] Privacy policy updated
- [ ] Terms of service updated

### Test Environments

**Development:**
- Use separate AWS resources
- Enable verbose logging
- Test with debug builds

**Staging:**
- Use production-like AWS resources
- Test with release builds
- Perform full E2E testing

**Production:**
- Use production AWS resources
- Minimal logging
- Monitor closely after release

---

## App Store Submission

### Google Play Store

#### 1. Prepare Store Listing

**Required Assets:**
- App icon (512x512 PNG)
- Feature graphic (1024x500 PNG)
- Screenshots (at least 2, up to 8)
  - Phone: 1080x1920 or 1080x2340
  - Tablet: 1536x2048 (optional)
- Short description (80 characters max)
- Full description (4000 characters max)
- Privacy policy URL
- Category selection

**Example Short Description:**
```
Securely manage household documents with cloud sync and offline access.
```

**Example Full Description:**
```
Household Docs helps you organize and manage important household documents like insurance policies, mortgages, and more.

Features:
• Secure cloud storage with AWS
• Automatic sync across devices
• Offline access to your documents
• Attach multiple files per document
• Organize with labels and descriptions
• View logs for troubleshooting

Your documents are encrypted and stored securely in your private AWS account. Only you have access to your data.

Perfect for:
• Insurance policies
• Mortgage documents
• Warranty information
• Important receipts
• Legal documents
• And more!

Download now and never lose track of important documents again.
```

#### 2. Configure App Details

**Content Rating:**
- Complete questionnaire
- Likely rating: Everyone

**Target Audience:**
- Age range: 18+

**Privacy Policy:**
- Required for apps that access personal data
- Host on your website or GitHub Pages

**Data Safety:**
- Declare data collection practices
- Specify data types collected
- Explain data usage
- Describe security practices

#### 3. Upload Build

1. Go to Google Play Console
2. Create new app or select existing
3. Go to Release → Production
4. Create new release
5. Upload AAB file
6. Add release notes
7. Review and rollout

**Release Notes Example:**
```
Version 2.0.0

New in this version:
• Complete rewrite with improved architecture
• Cloud sync with AWS
• Offline support
• Better error handling
• Improved performance
• Enhanced security

Bug fixes and improvements.
```

#### 4. Review Process

- Google review typically takes 1-3 days
- Monitor for rejection reasons
- Respond to review feedback promptly

---

### Apple App Store

#### 1. Prepare Store Listing

**Required Assets:**
- App icon (1024x1024 PNG)
- Screenshots (at least 1 per device size)
  - iPhone 6.7": 1290x2796
  - iPhone 6.5": 1242x2688
  - iPhone 5.5": 1242x2208
  - iPad Pro 12.9": 2048x2732
- App preview videos (optional)
- Description (4000 characters max)
- Keywords (100 characters max)
- Privacy policy URL
- Category selection

#### 2. Configure App Details in App Store Connect

**App Information:**
- Name: Household Docs
- Subtitle: Document Management
- Category: Productivity
- Content Rights: Yes (if applicable)

**Pricing:**
- Free or Paid
- Availability: All countries (or select specific)

**Privacy:**
- Privacy policy URL (required)
- Data collection practices

#### 3. Upload Build via Xcode

1. Archive app in Xcode
2. Distribute to App Store Connect
3. Wait for processing (10-30 minutes)
4. Select build in App Store Connect
5. Complete app information
6. Submit for review

#### 4. Review Process

- Apple review typically takes 1-2 days
- More strict than Google Play
- Common rejection reasons:
  - Missing privacy policy
  - Incomplete functionality
  - Crashes or bugs
  - Guideline violations

---

## Post-Deployment

### 1. Monitoring

**Metrics to Track:**
- Crash rate
- User retention
- Active users
- Sync success rate
- Error rates
- Performance metrics

**Tools:**
- Firebase Crashlytics (recommended)
- AWS CloudWatch (for backend)
- App Store analytics
- Google Play Console analytics

### 2. User Feedback

**Channels:**
- App store reviews
- In-app feedback (future feature)
- Support email
- Social media

**Response Strategy:**
- Respond to reviews promptly
- Address critical issues quickly
- Collect feature requests
- Prioritize bug fixes

### 3. Updates

**Update Frequency:**
- Bug fixes: As needed (hotfix)
- Minor updates: Monthly
- Major updates: Quarterly

**Update Process:**
1. Increment version number
2. Update changelog
3. Build and test
4. Submit to stores
5. Monitor rollout

### 4. Rollback Plan

**If Critical Issue Found:**

1. **Immediate:**
   - Halt rollout in Play Console (if gradual)
   - Document issue
   - Notify users via store listing

2. **Short-term:**
   - Fix issue in code
   - Test thoroughly
   - Submit hotfix update

3. **Long-term:**
   - Improve testing process
   - Add monitoring for similar issues
   - Update deployment checklist

---

## Security Considerations

### 1. Credential Management

- Never commit AWS credentials
- Use IAM roles with least privilege
- Rotate credentials regularly
- Use separate credentials for dev/prod

### 2. API Keys

- Store API keys securely
- Use environment variables
- Never commit to version control
- Rotate keys periodically

### 3. Code Obfuscation

**Enable for Release Builds:**

```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
flutter build ios --release --obfuscate --split-debug-info=build/debug-info
```

**Benefits:**
- Makes reverse engineering harder
- Protects business logic
- Reduces APK size

### 4. HTTPS Only

- All network requests use HTTPS
- Certificate pinning (future enhancement)
- Validate SSL certificates

---

## Performance Optimization

### 1. Build Optimization

**Release Build Flags:**
```bash
flutter build apk --release --target-platform android-arm64
flutter build appbundle --release
```

**Benefits:**
- Smaller APK size
- Better performance
- Optimized code

### 2. Asset Optimization

- Compress images
- Use appropriate image formats
- Remove unused assets
- Optimize icon sizes

### 3. Code Optimization

- Remove debug code
- Minimize dependencies
- Use const constructors
- Lazy load resources

---

## Troubleshooting

### Common Build Issues

**Issue:** Gradle build fails
**Solution:** 
- Clean build: `flutter clean`
- Update Gradle: Check `android/gradle/wrapper/gradle-wrapper.properties`
- Check Java version

**Issue:** iOS build fails
**Solution:**
- Clean build: `flutter clean`
- Update pods: `cd ios && pod install`
- Check Xcode version

**Issue:** Signing errors
**Solution:**
- Verify keystore/certificate
- Check signing configuration
- Ensure provisioning profiles are valid

### Common Deployment Issues

**Issue:** App rejected for privacy policy
**Solution:**
- Add privacy policy URL
- Ensure policy covers all data collection
- Update app listing

**Issue:** App crashes on startup
**Solution:**
- Test release build before submission
- Check Amplify configuration
- Review crash logs

**Issue:** Sync not working in production
**Solution:**
- Verify AWS configuration
- Check IAM policies
- Test with production credentials

---

## Maintenance

### Regular Tasks

**Weekly:**
- Monitor crash reports
- Review user feedback
- Check error logs

**Monthly:**
- Review AWS costs
- Update dependencies
- Security audit

**Quarterly:**
- Major version update
- Feature additions
- Performance review

### Dependency Updates

```bash
# Check for outdated packages
flutter pub outdated

# Update dependencies
flutter pub upgrade

# Test after updates
flutter test
```

---

## Backup and Recovery

### 1. Code Backup

- Use Git for version control
- Push to remote repository regularly
- Tag releases: `git tag v2.0.0`
- Maintain multiple branches (dev, staging, prod)

### 2. AWS Backup

- Enable S3 versioning
- Configure S3 lifecycle policies
- Backup Cognito configuration
- Document IAM policies

### 3. Keystore Backup

- Store keystore in secure location
- Backup to encrypted storage
- Document keystore passwords
- Never lose keystore (can't update app without it!)

---

## Support

### User Support

**Support Channels:**
- Email: support@yourcompany.com
- FAQ page
- In-app logs viewer

**Support Process:**
1. User reports issue
2. Request logs from app
3. Reproduce issue
4. Fix and deploy update
5. Notify user

### Developer Support

**Resources:**
- This documentation
- AWS documentation
- Flutter documentation
- Stack Overflow

---

## Conclusion

This deployment guide covers the complete process from AWS setup to app store submission. Follow each step carefully and test thoroughly before releasing to production.

**Key Takeaways:**
- Test extensively before release
- Use separate environments (dev/staging/prod)
- Monitor closely after deployment
- Respond quickly to issues
- Keep documentation updated

**Next Steps:**
1. Complete AWS setup
2. Configure signing
3. Build release version
4. Test thoroughly
5. Submit to app stores
6. Monitor and iterate

---

**Last Updated:** January 17, 2026
