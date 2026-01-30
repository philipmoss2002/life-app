# End-to-End Testing Guide

## Overview

This guide provides comprehensive instructions for performing manual end-to-end (E2E) testing of the authentication and sync rewrite. E2E testing validates complete user workflows from start to finish.

---

## Prerequisites

### Required Setup
- ✅ Flutter development environment configured
- ✅ Android emulator or iOS simulator running
- ✅ AWS Amplify configured with valid credentials
- ✅ Cognito User Pool set up
- ✅ S3 bucket configured with proper permissions
- ✅ Network connectivity available

### Test Environment
- **Device:** Android emulator / iOS simulator / Physical device
- **Network:** WiFi or mobile data
- **AWS:** Development/staging environment
- **Test Data:** Sample documents and files prepared

---

## Test Scenarios

## Scenario 1: New User Sign Up and First Document

### Objective
Verify that a new user can sign up, authenticate, and create their first document.

### Steps
1. **Launch App**
   - [ ] App opens to sign in screen
   - [ ] UI renders correctly
   - [ ] No errors in console

2. **Navigate to Sign Up**
   - [ ] Tap "Sign Up" link
   - [ ] Sign up screen displays
   - [ ] Form fields are empty

3. **Enter Invalid Email**
   - [ ] Enter invalid email (e.g., "notanemail")
   - [ ] Enter password
   - [ ] Tap "Sign Up"
   - [ ] Validation error displays
   - [ ] Form does not submit

4. **Enter Weak Password**
   - [ ] Enter valid email
   - [ ] Enter weak password (e.g., "123")
   - [ ] Tap "Sign Up"
   - [ ] Password validation error displays
   - [ ] Form does not submit

5. **Successful Sign Up**
   - [ ] Enter valid email (e.g., "test@example.com")
   - [ ] Enter strong password
   - [ ] Tap "Sign Up"
   - [ ] Loading indicator displays
   - [ ] Sign up succeeds
   - [ ] Navigate to document list screen

6. **Verify Empty State**
   - [ ] Document list screen displays
   - [ ] Empty state message shows
   - [ ] Floating action button visible
   - [ ] App bar displays correctly

7. **Create First Document**
   - [ ] Tap floating action button
   - [ ] Document detail screen opens in edit mode
   - [ ] Form fields are empty
   - [ ] Title field is focused

8. **Enter Document Details**
   - [ ] Enter title: "My First Document"
   - [ ] Enter description: "Test description"
   - [ ] Add label: "Important"
   - [ ] Verify label chip displays

9. **Attach File**
   - [ ] Tap "Attach" button
   - [ ] File picker opens
   - [ ] Select a test file (PDF, image, etc.)
   - [ ] File appears in attachments list
   - [ ] File size displays correctly

10. **Save Document**
    - [ ] Tap "Create" button
    - [ ] Loading indicator displays
    - [ ] Success message shows
    - [ ] Navigate back to document list

11. **Verify Document in List**
    - [ ] Document appears in list
    - [ ] Title displays correctly
    - [ ] Labels display correctly
    - [ ] Sync status shows "Pending Upload"

12. **Wait for Sync**
    - [ ] Sync indicator changes to "Uploading"
    - [ ] After upload, status changes to "Synced"
    - [ ] No errors occur

**Expected Result:** ✅ New user successfully signs up and creates first document with file attachment that syncs to cloud.

---

## Scenario 2: Document Sync Across App Reinstall

### Objective
Verify that documents persist and sync correctly after app reinstall.

### Steps
1. **Create Multiple Documents**
   - [ ] Create 3-5 documents with different content
   - [ ] Add files to some documents
   - [ ] Add labels to documents
   - [ ] Wait for all to sync (status = "Synced")

2. **Note Document Details**
   - [ ] Record titles of all documents
   - [ ] Record number of files attached
   - [ ] Record labels on each document

3. **Sign Out**
   - [ ] Navigate to Settings
   - [ ] Tap "Sign Out"
   - [ ] Confirm sign out
   - [ ] Return to sign in screen

4. **Close and Reopen App**
   - [ ] Close app completely
   - [ ] Reopen app
   - [ ] Sign in screen displays

5. **Sign In**
   - [ ] Enter same credentials
   - [ ] Tap "Sign In"
   - [ ] Loading indicator displays
   - [ ] Authentication succeeds

6. **Verify Documents Restored**
   - [ ] Document list displays
   - [ ] All documents appear
   - [ ] Titles match recorded data
   - [ ] Labels display correctly
   - [ ] Sync status shows "Synced"

7. **Open Document Details**
   - [ ] Tap on a document
   - [ ] Document details display
   - [ ] All metadata correct
   - [ ] Files list displays
   - [ ] File count matches

8. **Verify File Download**
   - [ ] Files show download status if not local
   - [ ] Tap on a file
   - [ ] File downloads (if needed)
   - [ ] File opens correctly

**Expected Result:** ✅ All documents and files persist across app reinstall and sync correctly.

---

## Scenario 3: File Upload and Download

### Objective
Verify file upload and download functionality with various file types.

### Steps
1. **Create Document with Multiple Files**
   - [ ] Create new document
   - [ ] Attach PDF file
   - [ ] Attach image file (JPG/PNG)
   - [ ] Attach text file
   - [ ] All files appear in list

2. **Verify File Icons**
   - [ ] PDF shows PDF icon
   - [ ] Image shows image icon
   - [ ] Text shows text icon
   - [ ] File sizes display correctly

3. **Save and Sync**
   - [ ] Save document
   - [ ] Sync status shows "Uploading"
   - [ ] All files upload
   - [ ] Status changes to "Synced"

4. **Verify S3 Upload**
   - [ ] Check AWS S3 console (optional)
   - [ ] Files exist in correct path
   - [ ] Path format: `private/{identityPoolId}/documents/{syncId}/{fileName}`

5. **Delete Local Files**
   - [ ] Clear app data (or simulate)
   - [ ] Files no longer local

6. **Download Files**
   - [ ] Open document
   - [ ] Files show download icon
   - [ ] Tap on file
   - [ ] Download starts
   - [ ] Progress indicator shows
   - [ ] Download completes
   - [ ] File opens correctly

7. **Test Large File**
   - [ ] Attach file >10MB
   - [ ] Upload progress shows
   - [ ] Upload completes successfully
   - [ ] File syncs correctly

**Expected Result:** ✅ Files of various types upload and download correctly with proper progress indication.

---

## Scenario 4: Offline Mode and Sync on Reconnection

### Objective
Verify that app works offline and syncs when connection is restored.

### Steps
1. **Enable Airplane Mode**
   - [ ] Turn on airplane mode
   - [ ] App shows offline indicator (if implemented)

2. **Create Document Offline**
   - [ ] Create new document
   - [ ] Enter title and description
   - [ ] Add labels
   - [ ] Attach file
   - [ ] Save document

3. **Verify Offline State**
   - [ ] Document appears in list
   - [ ] Sync status shows "Pending Upload"
   - [ ] No sync errors occur
   - [ ] Document is editable

4. **Create Multiple Documents Offline**
   - [ ] Create 2-3 more documents
   - [ ] All show "Pending Upload" status
   - [ ] All data persists locally

5. **Edit Existing Document Offline**
   - [ ] Open a synced document
   - [ ] Edit title
   - [ ] Add new label
   - [ ] Save changes
   - [ ] Status changes to "Pending Upload"

6. **Disable Airplane Mode**
   - [ ] Turn off airplane mode
   - [ ] Network connection restores
   - [ ] App detects connectivity

7. **Verify Auto-Sync**
   - [ ] Sync automatically triggers
   - [ ] Documents start uploading
   - [ ] Status changes to "Uploading"
   - [ ] All documents sync successfully
   - [ ] Status changes to "Synced"

8. **Verify Data Integrity**
   - [ ] All offline changes preserved
   - [ ] No data loss
   - [ ] Files uploaded correctly
   - [ ] Metadata correct

**Expected Result:** ✅ App works offline, queues changes, and syncs automatically when connection is restored.

---

## Scenario 5: Error Scenarios

### Objective
Verify that app handles errors gracefully.

### Steps

### 5.1: Network Failure During Upload
1. **Start Upload**
   - [ ] Create document with large file
   - [ ] Start upload
   - [ ] Enable airplane mode mid-upload

2. **Verify Error Handling**
   - [ ] Upload fails gracefully
   - [ ] Error message displays
   - [ ] Document status shows "Error"
   - [ ] No app crash

3. **Retry Upload**
   - [ ] Disable airplane mode
   - [ ] Trigger sync manually (pull-to-refresh)
   - [ ] Upload retries
   - [ ] Upload succeeds

### 5.2: Invalid Credentials
1. **Sign Out**
   - [ ] Sign out of app

2. **Sign In with Wrong Password**
   - [ ] Enter correct email
   - [ ] Enter wrong password
   - [ ] Tap "Sign In"
   - [ ] Error message displays
   - [ ] No app crash
   - [ ] Can retry

### 5.3: Document Deletion
1. **Delete Document**
   - [ ] Open document
   - [ ] Tap delete button
   - [ ] Confirmation dialog shows
   - [ ] Confirm deletion

2. **Verify Deletion**
   - [ ] Document removed from list
   - [ ] Success message shows
   - [ ] Files deleted from S3 (check console)

3. **Verify Cascade Delete**
   - [ ] All file attachments deleted
   - [ ] No orphaned data

**Expected Result:** ✅ App handles all error scenarios gracefully without crashes.

---

## Scenario 6: Settings and Logs

### Objective
Verify settings screen and logs functionality.

### Steps
1. **Open Settings**
   - [ ] Navigate to settings
   - [ ] Settings screen displays
   - [ ] User email shows
   - [ ] App version shows

2. **Verify No Test Features**
   - [ ] No debug buttons visible
   - [ ] No test features visible
   - [ ] Clean production UI

3. **View Logs**
   - [ ] Tap "View Logs" button
   - [ ] Logs viewer opens
   - [ ] Logs display with timestamps
   - [ ] Log levels show (info, warning, error)

4. **Filter Logs**
   - [ ] Tap "Error" filter
   - [ ] Only error logs show
   - [ ] Tap "All" filter
   - [ ] All logs show again

5. **Copy Logs**
   - [ ] Tap "Copy Logs" button
   - [ ] Success message shows
   - [ ] Paste in notes app
   - [ ] Logs copied correctly

6. **Clear Logs**
   - [ ] Tap "Clear Logs" button
   - [ ] Confirmation dialog shows
   - [ ] Confirm clear
   - [ ] Logs cleared
   - [ ] Empty state shows

7. **Sign Out**
   - [ ] Return to settings
   - [ ] Tap "Sign Out"
   - [ ] Confirmation dialog shows
   - [ ] Confirm sign out
   - [ ] Return to sign in screen
   - [ ] No errors occur

**Expected Result:** ✅ Settings and logs functionality works correctly.

---

## Test Checklist Summary

### Authentication ✅
- [ ] Sign up with valid credentials
- [ ] Sign up validation works
- [ ] Sign in with valid credentials
- [ ] Sign in error handling
- [ ] Sign out works correctly
- [ ] Identity Pool ID persists

### Document Management ✅
- [ ] Create document
- [ ] Edit document
- [ ] Delete document
- [ ] View document details
- [ ] Add labels
- [ ] Remove labels

### File Management ✅
- [ ] Attach files
- [ ] Upload files
- [ ] Download files
- [ ] Delete files
- [ ] Multiple file types
- [ ] Large files

### Sync Functionality ✅
- [ ] Auto-sync on create
- [ ] Auto-sync on edit
- [ ] Manual sync (pull-to-refresh)
- [ ] Sync status indicators
- [ ] Offline queuing
- [ ] Online sync

### Error Handling ✅
- [ ] Network errors
- [ ] Authentication errors
- [ ] Validation errors
- [ ] Graceful degradation
- [ ] Error messages
- [ ] Retry logic

### UI/UX ✅
- [ ] All screens render correctly
- [ ] Navigation works
- [ ] Loading indicators show
- [ ] Success messages display
- [ ] Error messages display
- [ ] Responsive UI

### Data Persistence ✅
- [ ] Data persists locally
- [ ] Data syncs to cloud
- [ ] Data restores after reinstall
- [ ] No data loss
- [ ] Consistent state

---

## Performance Testing

### Load Testing
- [ ] Create 50+ documents
- [ ] App remains responsive
- [ ] List scrolls smoothly
- [ ] Search works quickly

### File Size Testing
- [ ] Upload 1MB file
- [ ] Upload 10MB file
- [ ] Upload 50MB file
- [ ] Progress indicators work
- [ ] No timeouts

### Network Conditions
- [ ] Test on WiFi
- [ ] Test on mobile data
- [ ] Test on slow connection
- [ ] Test with intermittent connection

---

## Security Testing

### Authentication
- [ ] Credentials stored securely
- [ ] Session management works
- [ ] Token refresh works
- [ ] Sign out clears credentials

### Data Security
- [ ] Files use private access level
- [ ] S3 paths include Identity Pool ID
- [ ] Cannot access other users' files
- [ ] Proper IAM permissions

### Input Validation
- [ ] Email validation works
- [ ] Password validation works
- [ ] No SQL injection possible
- [ ] No XSS possible

---

## Regression Testing

After any code changes, verify:
- [ ] All existing features still work
- [ ] No new bugs introduced
- [ ] Performance not degraded
- [ ] UI not broken

---

## Bug Reporting Template

When bugs are found, report using this template:

```
**Title:** Brief description of the bug

**Severity:** Critical / High / Medium / Low

**Steps to Reproduce:**
1. Step 1
2. Step 2
3. Step 3

**Expected Result:**
What should happen

**Actual Result:**
What actually happens

**Environment:**
- Device: [Android/iOS]
- OS Version: [e.g., Android 12]
- App Version: [e.g., 1.0.0]
- Network: [WiFi/Mobile Data]

**Screenshots/Logs:**
[Attach if available]

**Additional Notes:**
Any other relevant information
```

---

## Sign-Off Checklist

Before marking E2E testing complete:

- [ ] All test scenarios executed
- [ ] All critical bugs fixed
- [ ] All test cases passed
- [ ] Performance acceptable
- [ ] Security verified
- [ ] Documentation updated
- [ ] Stakeholders notified

---

## Conclusion

This E2E testing guide ensures comprehensive validation of all user workflows. Complete all scenarios before proceeding to production deployment.

**Testing Duration:** Estimated 2-4 hours for complete E2E testing

**Recommended Frequency:**
- Before each release
- After major changes
- Weekly in development
- Daily in CI/CD (automated portions)

---

**Document Version:** 1.0  
**Last Updated:** January 17, 2026  
**Status:** Ready for Testing
