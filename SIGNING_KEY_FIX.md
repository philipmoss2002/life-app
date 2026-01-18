# Android Signing Key Fix

## Problem

Google Play rejected your app bundle with this error:
```
Your Android App Bundle is signed with the wrong key.

Expected fingerprint:
SHA1: F2:84:96:76:FD:CE:42:49:92:22:11:81:9E:E0:BA:0A:46:AE:E0:7D

Uploaded bundle fingerprint:
SHA1: 50:77:4A:2F:50:FA:5F:81:1F:D8:DE:CF:EA:73:4C:DF:34:65:93:18
```

## Root Cause

You have the **correct keystore** (`android/upload-keystore.jks`) with the right fingerprint, but you built the AAB with a **different keystore** (possibly a debug keystore or old keystore).

## Solution

### Step 1: Verify Correct Keystore

Your correct keystore is at: `android/upload-keystore.jks`

**Verify fingerprint:**
```bash
cd household_docs_app
keytool -list -v -keystore android\upload-keystore.jks -alias upload -storepass Lagertop1
```

**Expected output:**
```
SHA1: F2:84:96:76:FD:CE:42:49:92:22:11:81:9E:E0:BA:0A:46:AE:E0:7D
```

✅ **Confirmed:** This is the correct keystore!

---

### Step 2: Clean Previous Builds

Remove any old build artifacts:

```bash
cd household_docs_app
flutter clean
cd android
./gradlew clean
cd ..
```

---

### Step 3: Verify Signing Configuration

Check `android/app/build.gradle`:

```gradle
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
        signingConfig signingConfigs.release  // ← Make sure this is set!
    }
}
```

---

### Step 4: Verify key.properties

Check `android/key.properties`:

```properties
storePassword=Lagertop1
keyPassword=Lagertop1
keyAlias=upload
storeFile=upload-keystore.jks
```

**Important:** `storeFile` should be relative to the `android` directory.

---

### Step 5: Build New AAB with Correct Keystore

```bash
cd household_docs_app

# Clean everything
flutter clean

# Build release AAB
flutter build appbundle --release
```

**Output location:**
```
build/app/outputs/bundle/release/app-release.aab
```

---

### Step 6: Verify AAB Signature

Before uploading, verify the AAB is signed with the correct key:

```bash
# Extract signing certificate from AAB
cd build/app/outputs/bundle/release

# On Windows (using 7-Zip or similar)
# Extract app-release.aab
# Navigate to META-INF folder
# Check CERT.RSA file

# Or use bundletool
bundletool validate --bundle=app-release.aab
```

**Better method - Check with jarsigner:**

```bash
jarsigner -verify -verbose -certs app-release.aab
```

Look for the SHA1 fingerprint in the output. It should be:
```
F2:84:96:76:FD:CE:42:49:92:22:11:81:9E:E0:BA:0A:46:AE:E0:7D
```

---

### Step 7: Upload to Google Play

1. Go to Google Play Console
2. Navigate to your app
3. Go to Release → Production
4. Upload the new `app-release.aab`
5. Complete the release

---

## Common Issues and Solutions

### Issue 1: Still Using Wrong Keystore

**Symptom:** AAB still signed with wrong key after rebuild

**Possible causes:**
1. Multiple keystores in project
2. Wrong path in `key.properties`
3. Gradle cache not cleared

**Solution:**

```bash
# Find all keystores
cd household_docs_app
dir *.jks /s

# Remove any debug or old keystores
# Keep only: android\upload-keystore.jks

# Clean everything
flutter clean
cd android
./gradlew clean
cd ..

# Rebuild
flutter build appbundle --release
```

---

### Issue 2: key.properties Not Found

**Symptom:** Build fails with "key.properties not found"

**Solution:**

Ensure `android/key.properties` exists with:
```properties
storePassword=Lagertop1
keyPassword=Lagertop1
keyAlias=upload
storeFile=upload-keystore.jks
```

---

### Issue 3: Keystore Path Wrong

**Symptom:** Build succeeds but uses wrong keystore

**Solution:**

The `storeFile` path in `key.properties` is relative to the `android` directory.

**Correct:**
```properties
storeFile=upload-keystore.jks
```

**Incorrect:**
```properties
storeFile=../upload-keystore.jks
storeFile=android/upload-keystore.jks
```

---

### Issue 4: Using Debug Keystore

**Symptom:** AAB signed with debug key

**Solution:**

Make sure you're building with `--release` flag:
```bash
flutter build appbundle --release
```

NOT:
```bash
flutter build appbundle --debug
flutter build appbundle
```

---

## Verification Checklist

Before uploading to Google Play:

- [ ] Cleaned all build artifacts (`flutter clean`)
- [ ] Verified `android/key.properties` exists and is correct
- [ ] Verified `android/upload-keystore.jks` exists
- [ ] Verified keystore fingerprint matches expected: `F2:84:96:76:FD:CE:42:49:92:22:11:81:9E:E0:BA:0A:46:AE:E0:7D`
- [ ] Built with `flutter build appbundle --release`
- [ ] Verified AAB location: `build/app/outputs/bundle/release/app-release.aab`
- [ ] Verified AAB signature (optional but recommended)
- [ ] Incremented version number in `pubspec.yaml`

---

## Quick Fix Script

Create a file `build_release.bat`:

```batch
@echo off
echo Cleaning project...
call flutter clean

echo Cleaning Android...
cd android
call gradlew clean
cd ..

echo Building release AAB...
call flutter build appbundle --release

echo Done!
echo AAB location: build\app\outputs\bundle\release\app-release.aab
pause
```

Run it:
```bash
.\build_release.bat
```

---

## Understanding the Error

### What Happened

1. You previously uploaded an app signed with keystore A (fingerprint: `F2:84:96:76...`)
2. Google Play registered this as your app's signing key
3. You built a new version with keystore B (fingerprint: `50:77:4A:2F...`)
4. Google Play rejected it because the keys don't match

### Why It Matters

- Google Play uses the signing key to verify app authenticity
- All updates must be signed with the same key
- If you lose the key, you can't update the app (must create new app)

### Your Situation

✅ **Good news:** You have the correct keystore!
- Location: `android/upload-keystore.jks`
- Fingerprint: `F2:84:96:76:FD:CE:42:49:92:22:11:81:9E:E0:BA:0A:46:AE:E0:7D`
- This matches what Google Play expects

❌ **Problem:** You accidentally built with a different keystore
- Possibly the debug keystore
- Or an old/temporary keystore

✅ **Solution:** Rebuild with the correct keystore (steps above)

---

## Prevention

### 1. Backup Your Keystore

**Critical:** If you lose `upload-keystore.jks`, you can't update your app!

**Backup locations:**
- Secure cloud storage (encrypted)
- External hard drive
- Password manager (some support file attachments)

**Backup now:**
```bash
# Copy to safe location
copy android\upload-keystore.jks C:\Backups\household-docs-keystore.jks

# Also backup key.properties
copy android\key.properties C:\Backups\household-docs-key.properties
```

### 2. Document Keystore Info

Create a secure note with:
- Keystore location
- Alias: `upload`
- Store password: `Lagertop1`
- Key password: `Lagertop1`
- SHA1 fingerprint: `F2:84:96:76:FD:CE:42:49:92:22:11:81:9E:E0:BA:0A:46:AE:E0:7D`

### 3. Use Build Script

Always use the same build script to ensure consistency:

```bash
flutter clean
flutter build appbundle --release
```

### 4. Verify Before Upload

Always check the AAB signature before uploading:

```bash
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab
```

---

## Summary

### Problem
- AAB signed with wrong keystore
- Google Play expects: `F2:84:96:76:FD:CE:42:49:92:22:11:81:9E:E0:BA:0A:46:AE:E0:7D`
- You uploaded: `50:77:4A:2F:50:FA:5F:81:1F:D8:DE:CF:EA:73:4C:DF:34:65:93:18`

### Solution
1. Clean project: `flutter clean`
2. Verify keystore: `android/upload-keystore.jks` (correct one!)
3. Rebuild: `flutter build appbundle --release`
4. Upload new AAB to Google Play

### Prevention
- Backup keystore securely
- Use consistent build process
- Verify signature before upload

---

**Last Updated:** January 17, 2026
