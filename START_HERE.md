# 🚀 START HERE - Upload Key Reset Process

## Current Situation

✅ **Verified:** Your current keystore exists at `android/upload-keystore.jks`  
✅ **Verified:** Keytool is available on your system  
❌ **Problem:** SHA-1 fingerprint doesn't match Google Play Console  
❌ **Impact:** Subscription restoration not working (returns `SubscriptionStatus.none`)

---

## What You Need to Do

You have **3 documents** to guide you through this process:

### 1. 📋 **UPLOAD_KEY_RESET_CHECKLIST.md** ← Start here!
   - Step-by-step checklist to track your progress
   - Fill in dates and details as you go
   - Ensures you don't miss any steps

### 2. 📖 **UPLOAD_KEY_RESET_GUIDE.md**
   - Detailed explanation of each step
   - Troubleshooting tips
   - Background information
   - Security best practices

### 3. 💻 **android/KEYSTORE_COMMANDS.txt**
   - Quick command reference
   - Copy-paste ready commands
   - No explanations, just commands

---

## Quick Start (5 Minutes to Begin)

### Option A: Search for Original Keystore First (Recommended)

Before creating a new keystore, spend 15-30 minutes searching for the original:

**Search these locations:**
- [ ] Old computers or laptops
- [ ] Cloud storage (Google Drive, Dropbox, OneDrive)
- [ ] External hard drives or USB drives
- [ ] Email attachments (search for ".jks")
- [ ] Old project backups
- [ ] Team shared drives

**If you find it:** Problem solved! Just replace the current keystore and update the password in `key.properties`.

### Option B: Create New Keystore (If Original Lost)

If you can't find the original, follow these steps:

**Right now (5 minutes):**

1. Open **Command Prompt** (search for "cmd" in Windows, NOT PowerShell)

2. Copy and paste this command:
   ```cmd
   cd C:\Users\phili\Documents\Kiro\LifeApp\household_docs_app\android
   ```

3. Copy and paste this command:
   ```cmd
   "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore upload-keystore-new.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

4. Follow the prompts (write down your password!)

5. Then run:
   ```cmd
   "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -export -rfc -keystore upload-keystore-new.jks -alias upload -file upload_certificate.pem
   ```

**That's it for now!** You've created the new keystore and certificate.

**Next (10 minutes):**

6. Go to [Google Play Console](https://play.google.com/console)
7. Select your app
8. Setup → App signing
9. Request upload key reset
10. Upload `upload_certificate.pem`

**Then wait:** Google will review (2-7 days)

**After approval:** Follow the checklist to complete the process

---

## Timeline

| Phase | Time Required | When |
|-------|---------------|------|
| Generate keystore | 5 minutes | Today |
| Submit to Google | 10 minutes | Today |
| **Wait for approval** | **2-7 days** | **Waiting** |
| Update project | 15 minutes | After approval |
| Build & upload | 30 minutes | After approval |
| Test | 15 minutes | After publishing |

**Total active time:** ~75 minutes  
**Total calendar time:** 2-7 days (mostly waiting)

---

## What Happens After?

Once the new upload key is registered and you publish a new version:

✅ Subscription restoration will work  
✅ Existing users keep their purchases  
✅ No data loss  
✅ App continues working normally  

---

## Need Help?

**If you get stuck:**
1. Check the Troubleshooting section in `UPLOAD_KEY_RESET_GUIDE.md`
2. Verify you're using CMD (not PowerShell)
3. Check that keytool path is correct

**Common issues:**
- "keytool not found" → Check Android Studio installation path
- PowerShell syntax errors → Use CMD instead
- Google rejects request → Provide more detailed explanation

---

## Important Reminders

⚠️ **Write down your password!** You'll need it for all future app updates  
⚠️ **Use Command Prompt (CMD)**, not PowerShell  
⚠️ **Backup the new keystore** in multiple secure locations  
⚠️ **Never commit keystores to git**  

---

## Ready to Start?

1. ✅ Open `UPLOAD_KEY_RESET_CHECKLIST.md`
2. ✅ Decide: Search for original OR create new keystore
3. ✅ Follow the checklist step by step
4. ✅ Refer to `UPLOAD_KEY_RESET_GUIDE.md` for details
5. ✅ Use `android/KEYSTORE_COMMANDS.txt` for quick commands

**Good luck! You've got this! 🎉**
