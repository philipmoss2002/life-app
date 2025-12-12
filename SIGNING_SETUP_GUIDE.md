# Android App Signing Setup Guide

## Current Status

✅ **Keystore Created:** `upload-keystore.jks`
✅ **Build Configuration:** Updated `android/app/build.gradle`
⚠️ **Passwords:** Need to be set in `android/key.properties`

## Quick Setup

### Step 1: Set Your Passwords

Run the setup script:
```bash
./setup_signing.bat
```

This will prompt you for:
- **Keystore password** (the one you entered when creating the keystore)
- **Key password** (can be the same as keystore password)

### Step 2: Build Signed AAB

After setting passwords:
```bash
flutter build appbundle --release
```

## Manual Setup (Alternative)

If you prefer to set up manually:

### 1. Edit `android/key.properties`

Replace the placeholder values:
```properties
storePassword=YOUR_ACTUAL_KEYSTORE_PASSWORD
keyPassword=YOUR_ACTUAL_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

### 2. Build Signed AAB
```bash
flutter build appbundle --release
```

## File Locations

- **Keystore:** `upload-keystore.jks` (keep this safe!)
- **Key Properties:** `android/key.properties` (contains passwords)
- **Signed AAB:** `build/app/outputs/bundle/release/app-release.aab`

## Security Notes

### ⚠️ Important Security Information

1. **Keep Keystore Safe:**
   - Back up `upload-keystore.jks` to multiple secure locations
   - You need this file for ALL future app updates
   - If lost, you cannot update your app on Google Play

2. **Remember Passwords:**
   - Store passwords securely (password manager recommended)
   - You'll need them for every release build

3. **Don't Commit Secrets:**
   - `android/key.properties` contains passwords
   - Already added to `.gitignore` to prevent accidental commits
   - Never share keystore or passwords publicly

## Troubleshooting

### "Keystore was tampered with" Error
- Check that passwords are correct
- Ensure keystore file path is correct

### "Key not found" Error
- Verify `keyAlias=upload` matches the alias used when creating keystore

### Build Fails
- Run `flutter clean` first
- Ensure all passwords are set correctly
- Check that keystore file exists

## Verification

To verify signing is working:

1. Build the AAB:
   ```bash
   flutter build appbundle --release
   ```

2. Check the output for:
   ```
   ✓ Built build/app/outputs/bundle/release/app-release.aab
   ```

3. The AAB should be larger than debug builds (includes signing)

## Next Steps

1. **Set passwords** using `./setup_signing.bat`
2. **Build signed AAB** with `flutter build appbundle --release`
3. **Upload to Google Play Console**
4. **Back up keystore** to secure locations

## Backup Checklist

Before releasing to production:

- [ ] Back up `upload-keystore.jks` to cloud storage
- [ ] Back up `upload-keystore.jks` to external drive
- [ ] Store passwords in password manager
- [ ] Test build process on different machine
- [ ] Document keystore details for team

---

**Remember:** Once you upload a signed AAB to Google Play, you must use the same keystore for all future updates!