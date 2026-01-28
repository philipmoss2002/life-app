# Upload Key Reset Checklist

Use this checklist to track your progress through the upload key reset process.

## Pre-Reset (Optional but Recommended)

- [ ] Search for original keystore in backups
- [ ] Check old computers/laptops
- [ ] Check cloud storage (Google Drive, Dropbox, OneDrive)
- [ ] Check email attachments
- [ ] Check external drives

**If original keystore found:** Stop here, use original keystore instead!

---

## Phase 1: Generate New Keystore (Day 1)

- [ ] Open Command Prompt (CMD)
- [ ] Navigate to `household_docs_app\android`
- [ ] Run keytool command to generate new keystore
- [ ] Enter password (WRITE IT DOWN!)
- [ ] Enter organizational details
- [ ] Confirm with "yes"
- [ ] Verify `upload-keystore-new.jks` file created
- [ ] **Password saved in secure location:** _______________

---

## Phase 2: Export Certificate (Day 1)

- [ ] Run keytool export command
- [ ] Enter password
- [ ] Verify `upload_certificate.pem` file created
- [ ] (Optional) Run keytool list command to verify SHA-1

**SHA-1 Fingerprint of new keystore:**
```
_________________________________________________________________
```

---

## Phase 3: Backup Current Keystore (Day 1)

- [ ] Copy `upload-keystore.jks` to `upload-keystore-OLD-BACKUP.jks`
- [ ] Verify backup file exists
- [ ] Move backup to secure location (optional)

---

## Phase 4: Submit to Google Play Console (Day 1)

- [ ] Go to Google Play Console
- [ ] Navigate to app: Household Documents
- [ ] Go to Setup → App signing
- [ ] Click "Request upload key reset"
- [ ] Upload `upload_certificate.pem`
- [ ] Provide reason for reset
- [ ] Submit request
- [ ] **Submission date:** _______________

---

## Phase 5: Wait for Google Approval (2-7 Days)

- [ ] Check email daily for approval notification
- [ ] **Approval received date:** _______________

---

## Phase 6: Update Project Configuration (After Approval)

- [ ] Edit `android/key.properties`
- [ ] Update `storePassword` with new password
- [ ] Update `keyPassword` with new password
- [ ] Verify `keyAlias=upload`
- [ ] Update `storeFile=upload-keystore-new.jks`
- [ ] Save file

**key.properties updated:** _______________

---

## Phase 7: Replace Keystore File (After Approval)

- [ ] Navigate to `household_docs_app\android`
- [ ] Delete `upload-keystore.jks`
- [ ] Rename `upload-keystore-new.jks` to `upload-keystore.jks`
- [ ] Verify file renamed correctly

---

## Phase 8: Build New Release (After Approval)

- [ ] Navigate to `household_docs_app`
- [ ] Run `flutter clean`
- [ ] Run `flutter pub get`
- [ ] Update version in `pubspec.yaml` (if needed)
  - Current version: _______________
  - New version: _______________
- [ ] Run `flutter build appbundle --release`
- [ ] Verify AAB created at `build\app\outputs\bundle\release\app-release.aab`
- [ ] Check AAB file size (should be reasonable)

**Build completed:** _______________

---

## Phase 9: Upload to Google Play Console (After Approval)

- [ ] Go to Google Play Console
- [ ] Navigate to Release → Production (or Testing)
- [ ] Create new release
- [ ] Upload `app-release.aab`
- [ ] Add release notes
- [ ] Submit for review
- [ ] **Upload date:** _______________

---

## Phase 10: Test Subscription Restoration (After Publishing)

- [ ] Wait for release to be published
- [ ] Install new version on test device
- [ ] Open app
- [ ] Check if subscription is restored automatically
- [ ] Verify logs show: `Status: SubscriptionStatus.active`
- [ ] Test document sync with active subscription
- [ ] **Testing completed:** _______________

---

## Final Verification

- [ ] Subscription restoration working
- [ ] Document sync working
- [ ] No errors in logs
- [ ] User experience smooth
- [ ] **Issue resolved:** _______________

---

## Post-Reset Security

- [ ] Store new keystore in secure location
- [ ] Backup keystore to encrypted cloud storage
- [ ] Backup keystore to external drive
- [ ] Store password in password manager
- [ ] Document keystore location for team
- [ ] Update team documentation

---

## Notes

Use this space to track any issues, questions, or important information:

```
_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________
```

---

## Quick Reference

**New Keystore Password:** (Store securely, not here!)

**Google Play Console Link:** https://play.google.com/console

**Support Resources:**
- Upload Key Reset Guide: `UPLOAD_KEY_RESET_GUIDE.md`
- Command Reference: `android/KEYSTORE_COMMANDS.txt`
- Google Play Help: https://support.google.com/googleplay/android-developer/answer/9842756

---

**Started:** _______________  
**Completed:** _______________  
**Total Time:** _______________
