# Upload Key Reset Guide

## Problem Summary
The SHA-1 fingerprint of the current keystore doesn't match Google Play Console's registered upload key certificate. This prevents subscription restoration from working because Google Play doesn't recognize the app signature.

## Solution: Register New Upload Key with Google Play

Follow these steps carefully to resolve the issue.

---

## Step 1: Generate New Keystore

Open **Command Prompt (CMD)** - NOT PowerShell - and navigate to your project's android folder:

```cmd
cd household_docs_app\android
```

Then generate a new keystore:

```cmd
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore upload-keystore-new.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**When prompted, enter:**
- Keystore password: Choose a strong password (WRITE IT DOWN!)
- Re-enter password: Same password
- First and last name: Your name or company name
- Organizational unit: Your team/department (or press Enter)
- Organization: Your company name (or press Enter)
- City/Locality: Your city
- State/Province: Your state
- Country code: Your 2-letter country code (e.g., US, GB, CA)
- Is this correct? Type: `yes`
- Key password: Press Enter to use same password as keystore

**IMPORTANT:** Save the password securely! You'll need it for all future app updates.

---

## Step 2: Export Certificate from New Keystore

Still in the `android` folder, run:

```cmd
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -export -rfc -keystore upload-keystore-new.jks -alias upload -file upload_certificate.pem
```

Enter the password you just created when prompted.

This creates `upload_certificate.pem` - you'll upload this to Google Play Console.

---

## Step 3: Verify the New Certificate (Optional but Recommended)

Check the SHA-1 fingerprint of your new keystore:

```cmd
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore upload-keystore-new.jks -alias upload
```

Look for the SHA-1 line - this is what Google Play will register.

---

## Step 4: Backup Current Keystore

Before replacing anything, backup your current keystore:

```cmd
copy upload-keystore.jks upload-keystore-OLD-BACKUP.jks
```

---

## Step 5: Register New Upload Key in Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Select your app: **Household Documents**
3. Navigate to: **Setup → App signing**
4. Scroll down to the **"Upload key certificate"** section
5. Click **"Request upload key reset"** or **"Update upload key"**
6. Follow the on-screen instructions:
   - Upload the `upload_certificate.pem` file you created in Step 2
   - Provide a reason (e.g., "Lost original upload key, registering new key")
7. Submit the request

**Wait Time:** Google typically reviews and approves within 2-7 days. You'll receive an email when approved.

---

## Step 6: Update Project Configuration (After Google Approval)

Once Google approves your new upload key, update your project:

### 6a. Update key.properties

Edit `household_docs_app/android/key.properties`:

```properties
storePassword=YOUR_NEW_PASSWORD_HERE
keyPassword=YOUR_NEW_PASSWORD_HERE
keyAlias=upload
storeFile=upload-keystore-new.jks
```

Replace `YOUR_NEW_PASSWORD_HERE` with the password you created in Step 1.

### 6b. Replace the Keystore File

```cmd
cd household_docs_app\android
del upload-keystore.jks
ren upload-keystore-new.jks upload-keystore.jks
```

Or manually:
- Delete `upload-keystore.jks`
- Rename `upload-keystore-new.jks` to `upload-keystore.jks`

---

## Step 7: Build and Test

Build a new release bundle:

```cmd
cd household_docs_app
flutter clean
flutter pub get
flutter build appbundle --release
```

The new AAB will be at: `build\app\outputs\bundle\release\app-release.aab`

---

## Step 8: Upload to Google Play Console

1. Go to Google Play Console
2. Navigate to: **Release → Production** (or Testing track)
3. Click **"Create new release"**
4. Upload the new `app-release.aab`
5. Increment version number in `pubspec.yaml` before building if needed
6. Complete release notes and submit for review

---

## Step 9: Test Subscription Restoration

After the new version is published:

1. Install the new version on your test device
2. Open the app
3. The subscription should now be restored automatically
4. Check logs to confirm: `Purchases restored successfully. Status: SubscriptionStatus.active`

---

## Important Notes

### About App Signing vs Upload Key

- **App Signing Key**: The key Google uses to sign your app for distribution (managed by Google Play App Signing)
- **Upload Key**: The key you use to sign uploads to Google Play Console

Since you're using Google Play App Signing, only the upload key changes. This means:

✅ **Existing users keep their purchases**  
✅ **Subscriptions remain valid**  
✅ **No data loss**  
✅ **Same app identity**  
✅ **Users don't need to reinstall**

### Security Best Practices

1. **Store keystore securely**: Keep `upload-keystore.jks` in a secure location
2. **Backup keystore**: Store copies in multiple secure locations (encrypted cloud storage, external drives)
3. **Never commit to git**: Keystores should NEVER be in version control
4. **Document password**: Store password in a password manager
5. **Restrict access**: Only authorized team members should have access

### Troubleshooting

**If keytool is not found:**
- Verify Android Studio installation path
- Try: `"C:\Program Files\Android\Android Studio\jre\bin\keytool.exe"` (older versions)
- Or find keytool location: `dir /s /b "C:\Program Files\Android\Android Studio\keytool.exe"`

**If Google rejects the upload key reset:**
- Provide more detailed explanation in the request
- Contact Google Play support directly
- Consider creating a new app listing (last resort)

**If subscription still doesn't work after update:**
- Check logs for specific error messages
- Verify product ID matches: `premium_monthly`
- Ensure Google Play Billing is properly configured
- Test with a different Google account

---

## Timeline

- **Step 1-4**: 10-15 minutes (immediate)
- **Step 5**: Submit request (5 minutes)
- **Waiting**: 2-7 days for Google approval
- **Step 6-8**: 30 minutes (after approval)
- **Step 9**: Testing (15 minutes)

**Total time**: 2-7 days (mostly waiting for Google)

---

## Alternative: Find Original Keystore

Before going through the reset process, search for the original keystore in:

- Old computers or laptops
- Cloud storage (Google Drive, Dropbox, OneDrive)
- External hard drives or USB drives
- Email attachments
- Backup folders
- Old project directories

If found, simply replace the current keystore and update `key.properties` with the correct password.

---

## Questions or Issues?

If you encounter any problems during this process, check the Troubleshooting section above or consult the [Google Play Console Help](https://support.google.com/googleplay/android-developer/answer/9842756).
