# User Acceptance Test Plan

## Overview

This document outlines comprehensive user acceptance testing (UAT) scenarios for the persistent file access system using AWS Cognito User Pool sub identifiers. These scenarios validate that the system meets user expectations across new user onboarding, existing user migration, and multi-device usage patterns.

## Test Environment Requirements

### Prerequisites
- Flutter app installed on test devices (iOS and Android)
- AWS Cognito User Pool configured with test accounts
- S3 bucket configured with private access level
- Test documents of various types (PDF, images, text files)
- Multiple test devices for cross-device scenarios

### Test User Profiles
1. **New User** - Never used the app before
2. **Existing User (Pre-Migration)** - Has files stored with legacy username-based paths
3. **Migrated User** - Has completed migration to User Pool sub-based paths
4. **Multi-Device User** - Uses app on multiple devices simultaneously

---

## Scenario 1: New User Onboarding with User Pool Sub-Based Paths

**Requirement Coverage**: 1.1, 2.1, 5.1, 5.2

### Test Case 1.1: First-Time User Registration and File Upload

**Objective**: Verify that new users can register and immediately upload files using User Pool sub-based paths.

**Steps**:
1. Launch the app on a fresh device (no previous installation)
2. Complete user registration with email and password
3. Verify email and complete authentication
4. Navigate to document upload screen
5. Upload a test document (e.g., "test_invoice.pdf")
6. Verify document appears in document list
7. Check S3 bucket to confirm file path structure

**Expected Results**:
- User successfully registers and authenticates
- Document uploads without errors
- Document appears in app with correct metadata
- S3 path follows format: `private/{userPoolSub}/documents/{syncId}/test_invoice.pdf`
- No legacy username-based paths are created
- File is immediately accessible after upload

**Success Criteria**:
- ✅ Upload completes within 10 seconds for 1MB file
- ✅ File path uses User Pool sub (UUID format)
- ✅ Document appears in UI immediately after upload
- ✅ No error messages displayed to user

---

### Test Case 1.2: New User Multi-File Upload

**Objective**: Verify new users can upload multiple files in quick succession.

**Steps**:
1. Authenticate as a new user (from Test Case 1.1)
2. Upload 5 different documents in rapid succession
3. Monitor upload progress for each file
4. Verify all files appear in document list
5. Check S3 bucket for all uploaded files

**Expected Results**:
- All 5 files upload successfully
- Each file has unique syncId in path
- All files use same User Pool sub in path
- Upload progress indicators work correctly
- No duplicate files created

**Success Criteria**:
- ✅ All 5 files upload without errors
- ✅ Each file has unique path: `private/{userPoolSub}/documents/{uniqueSyncId}/{fileName}`
- ✅ Upload queue handles concurrent uploads gracefully
- ✅ UI updates correctly for each completed upload

---

### Test Case 1.3: New User File Download and Viewing

**Objective**: Verify new users can download and view their uploaded files.

**Steps**:
1. Authenticate as new user with uploaded files
2. Select a document from the list
3. Tap to view/download the document
4. Verify document opens correctly
5. Close and reopen the document
6. Check local cache behavior

**Expected Results**:
- Document downloads successfully
- File opens in appropriate viewer
- Subsequent opens use cached version (faster)
- Download progress indicator displays correctly
- No authentication errors occur

**Success Criteria**:
- ✅ First download completes within 5 seconds for 1MB file
- ✅ Cached access is near-instantaneous (<1 second)
- ✅ Document content is correct and uncorrupted
- ✅ User Pool sub authentication is transparent to user

---

### Test Case 1.4: New User File Deletion

**Objective**: Verify new users can delete their uploaded files.

**Steps**:
1. Authenticate as new user with uploaded files
2. Select a document to delete
3. Confirm deletion
4. Verify document removed from list
5. Check S3 bucket to confirm file deletion
6. Attempt to access deleted file

**Expected Results**:
- Document deletes successfully
- File removed from UI immediately
- S3 file is deleted (not just hidden)
- Attempting to access deleted file shows appropriate error
- No orphaned files remain in S3

**Success Criteria**:
- ✅ Deletion completes within 3 seconds
- ✅ File removed from S3 at path: `private/{userPoolSub}/documents/{syncId}/{fileName}`
- ✅ UI updates immediately after deletion
- ✅ No error messages displayed

---

## Scenario 2: Existing User Migration and File Access Preservation

**Requirement Coverage**: 8.1, 8.2, 8.3, 8.4

### Test Case 2.1: Automatic Migration Detection on First Login

**Objective**: Verify that existing users with legacy files are automatically detected and migrated.

**Steps**:
1. Set up test account with legacy files in S3 (username-based paths)
2. Update app to new version with User Pool sub implementation
3. Launch app and authenticate with existing credentials
4. Observe migration process (should be automatic)
5. Verify all files remain accessible
6. Check S3 bucket for new file paths

**Expected Results**:
- App detects legacy files automatically
- Migration starts without user intervention
- Progress indicator shows migration status
- All files remain accessible during migration
- New User Pool sub-based paths created in S3
- Legacy files preserved until migration verified

**Success Criteria**:
- ✅ Migration detection occurs within 5 seconds of login
- ✅ User sees clear migration progress indicator
- ✅ All files accessible throughout migration
- ✅ Migration completes within 30 seconds for 10 files
- ✅ No data loss occurs

---

### Test Case 2.2: File Access During Migration

**Objective**: Verify that users can access files during the migration process.

**Steps**:
1. Authenticate as existing user with many files (20+)
2. Start migration process
3. While migration is in progress, attempt to:
   - View a document
   - Upload a new document
   - Delete a document
4. Monitor for errors or access issues
5. Verify operations complete successfully

**Expected Results**:
- File viewing works during migration (fallback to legacy paths)
- New uploads use User Pool sub paths immediately
- Deletions work correctly (both legacy and new paths)
- No user-facing errors occur
- Migration continues in background

**Success Criteria**:
- ✅ File access latency <5 seconds during migration
- ✅ New uploads use User Pool sub paths
- ✅ Fallback mechanism works transparently
- ✅ No error messages displayed to user

---

### Test Case 2.3: Post-Migration File Access Validation

**Objective**: Verify that all files are accessible after migration completes.

**Steps**:
1. Complete migration for existing user (from Test Case 2.1)
2. View migration completion status
3. Access each migrated file
4. Verify file content is correct
5. Check S3 bucket for file paths
6. Verify legacy paths are cleaned up (if applicable)

**Expected Results**:
- Migration status shows "Complete"
- All files accessible via new User Pool sub paths
- File content matches original files
- S3 contains files at new paths: `private/{userPoolSub}/documents/{syncId}/{fileName}`
- Legacy paths may remain for rollback purposes
- No broken file references in app

**Success Criteria**:
- ✅ 100% of files accessible after migration
- ✅ File content integrity verified (checksums match)
- ✅ All files use User Pool sub paths
- ✅ Migration status persisted correctly

---

### Test Case 2.4: Migration Rollback Scenario

**Objective**: Verify that migration can be rolled back if issues occur.

**Steps**:
1. Set up test account with legacy files
2. Start migration process
3. Simulate migration failure (e.g., network interruption)
4. Verify rollback mechanism activates
5. Check that files remain accessible via legacy paths
6. Retry migration after issue resolved

**Expected Results**:
- Migration failure detected automatically
- Rollback process initiates
- Files remain accessible via legacy paths
- User notified of migration issue
- Retry option available
- No data loss occurs

**Success Criteria**:
- ✅ Rollback completes within 10 seconds
- ✅ All files accessible via legacy paths after rollback
- ✅ User sees clear error message and retry option
- ✅ Subsequent migration attempt succeeds

---

### Test Case 2.5: Existing User New File Upload Post-Migration

**Objective**: Verify that migrated users can upload new files using User Pool sub paths.

**Steps**:
1. Authenticate as migrated user
2. Upload a new document
3. Verify document appears in list alongside migrated files
4. Check S3 bucket for new file path
5. Verify new file uses User Pool sub path

**Expected Results**:
- New file uploads successfully
- File appears in document list
- S3 path uses User Pool sub: `private/{userPoolSub}/documents/{syncId}/{fileName}`
- New file indistinguishable from migrated files in UI
- No legacy path created for new file

**Success Criteria**:
- ✅ Upload completes within 10 seconds
- ✅ New file uses User Pool sub path
- ✅ File accessible immediately after upload
- ✅ No errors or warnings displayed

---

## Scenario 3: Multi-Device Usage Patterns and Synchronization

**Requirement Coverage**: 2.1, 2.4, 5.3

### Test Case 3.1: File Upload on Device A, Access on Device B

**Objective**: Verify that files uploaded on one device are accessible on another device using the same account.

**Steps**:
1. Authenticate on Device A (e.g., iPhone)
2. Upload a document on Device A
3. Authenticate on Device B (e.g., Android tablet) with same credentials
4. Verify document appears in list on Device B
5. Download and view document on Device B
6. Verify file content matches

**Expected Results**:
- Document uploaded on Device A
- Document appears on Device B after sync
- File content identical on both devices
- Both devices use same User Pool sub in S3 paths
- Sync occurs automatically (within 30 seconds)

**Success Criteria**:
- ✅ File appears on Device B within 30 seconds
- ✅ File content matches exactly (checksum verification)
- ✅ Both devices use path: `private/{userPoolSub}/documents/{syncId}/{fileName}`
- ✅ No duplicate files created

---

### Test Case 3.2: Concurrent File Operations on Multiple Devices

**Objective**: Verify that concurrent file operations on multiple devices are handled correctly.

**Steps**:
1. Authenticate on Device A and Device B with same account
2. Simultaneously:
   - Upload File 1 on Device A
   - Upload File 2 on Device B
3. Wait for sync to complete
4. Verify both files appear on both devices
5. Check S3 bucket for both files
6. Verify no conflicts or duplicates

**Expected Results**:
- Both files upload successfully
- Both files appear on both devices after sync
- Each file has unique syncId
- No conflicts or overwrites occur
- S3 contains both files with correct paths

**Success Criteria**:
- ✅ Both uploads complete successfully
- ✅ Both files visible on both devices within 60 seconds
- ✅ Each file has unique path with different syncId
- ✅ No error messages or conflicts

---

### Test Case 3.3: File Deletion on Device A, Sync to Device B

**Objective**: Verify that file deletions sync correctly across devices.

**Steps**:
1. Authenticate on Device A and Device B with same account
2. Ensure both devices show same file list
3. Delete a file on Device A
4. Wait for sync to complete
5. Verify file removed from Device B
6. Check S3 bucket to confirm deletion

**Expected Results**:
- File deletes on Device A
- File removed from Device B after sync
- S3 file deleted
- No orphaned references remain
- Sync occurs within 30 seconds

**Success Criteria**:
- ✅ Deletion syncs to Device B within 30 seconds
- ✅ File removed from S3
- ✅ No broken references on either device
- ✅ UI updates correctly on both devices

---

### Test Case 3.4: App Reinstall and File Access Restoration

**Objective**: Verify that files remain accessible after app reinstall on same device.

**Steps**:
1. Authenticate and upload files on Device A
2. Uninstall app from Device A
3. Reinstall app on Device A
4. Authenticate with same credentials
5. Verify all files appear in document list
6. Download and view files
7. Check that User Pool sub remains consistent

**Expected Results**:
- All files appear after reinstall
- User Pool sub remains same (tied to Cognito account)
- Files download successfully
- No migration required (already using User Pool sub paths)
- Local cache rebuilt automatically

**Success Criteria**:
- ✅ All files appear within 10 seconds of login
- ✅ User Pool sub unchanged
- ✅ Files accessible immediately
- ✅ No data loss or corruption

---

### Test Case 3.5: Offline File Access and Sync on Reconnection

**Objective**: Verify that file operations work offline and sync when connection restored.

**Steps**:
1. Authenticate and ensure files are cached locally
2. Enable airplane mode (offline)
3. View cached files (should work)
4. Attempt to upload new file (should queue)
5. Attempt to delete file (should queue)
6. Disable airplane mode (online)
7. Verify queued operations execute
8. Check S3 bucket for changes

**Expected Results**:
- Cached files viewable offline
- New operations queued for later
- User notified of offline status
- Operations execute automatically when online
- S3 updated correctly after reconnection
- No data loss or conflicts

**Success Criteria**:
- ✅ Cached files accessible offline
- ✅ Queued operations execute within 30 seconds of reconnection
- ✅ S3 reflects all changes correctly
- ✅ User sees clear offline/online status indicators

---

## Test Execution Plan

### Phase 1: New User Scenarios (Day 1)
- Execute Test Cases 1.1 - 1.4
- Validate User Pool sub path generation
- Verify basic file operations

### Phase 2: Migration Scenarios (Day 2-3)
- Execute Test Cases 2.1 - 2.5
- Validate migration detection and execution
- Test rollback mechanisms
- Verify backward compatibility

### Phase 3: Multi-Device Scenarios (Day 4-5)
- Execute Test Cases 3.1 - 3.5
- Validate cross-device synchronization
- Test concurrent operations
- Verify offline/online behavior

### Phase 4: Regression Testing (Day 6)
- Re-run all test cases
- Verify no regressions introduced
- Document any issues found

### Phase 5: User Feedback and Refinement (Day 7)
- Gather user feedback on experience
- Identify usability issues
- Plan refinements if needed

---

## Success Criteria Summary

### Overall Acceptance Criteria
- ✅ All 15 test cases pass without critical failures
- ✅ No data loss occurs in any scenario
- ✅ User Pool sub paths used consistently for all new operations
- ✅ Migration completes successfully for 100% of existing users
- ✅ Cross-device synchronization works reliably
- ✅ Performance meets targets (upload <10s, download <5s for 1MB files)
- ✅ User experience is seamless and transparent

### Key Performance Indicators (KPIs)
- **File Upload Success Rate**: >99%
- **File Download Success Rate**: >99%
- **Migration Success Rate**: 100%
- **Cross-Device Sync Time**: <30 seconds
- **User Satisfaction**: >4.5/5 (if surveyed)

---

## Issue Tracking

### Critical Issues (Blockers)
- Issues that prevent core functionality
- Must be resolved before release

### Major Issues (High Priority)
- Issues that significantly impact user experience
- Should be resolved before release

### Minor Issues (Medium Priority)
- Issues that cause inconvenience but have workarounds
- Can be addressed in subsequent releases

### Enhancement Requests (Low Priority)
- Suggestions for improved functionality
- Considered for future releases

---

## Test Data Requirements

### Sample Documents
- PDF files (various sizes: 100KB, 1MB, 5MB)
- Image files (JPEG, PNG)
- Text files
- Mixed file types for batch operations

### Test Accounts
- 5 new user accounts (never used app)
- 5 existing user accounts (with legacy files)
- 3 migrated user accounts (post-migration)
- 2 multi-device user accounts

### Test Devices
- iOS devices (iPhone, iPad)
- Android devices (phone, tablet)
- Various OS versions
- Different network conditions (WiFi, 4G, 3G)

---

## Reporting and Documentation

### Test Execution Report
- Test case ID and description
- Execution date and tester
- Pass/Fail status
- Screenshots/videos of issues
- Steps to reproduce failures
- Severity and priority ratings

### Final UAT Report
- Summary of all test results
- List of issues found and resolved
- Outstanding issues and workarounds
- Recommendations for release
- Sign-off from stakeholders

---

## Conclusion

This user acceptance test plan provides comprehensive coverage of the persistent file access system using User Pool sub identifiers. By executing these scenarios, we validate that the system meets user expectations for new user onboarding, existing user migration, and multi-device usage patterns. Successful completion of all test cases ensures the system is ready for production deployment.
