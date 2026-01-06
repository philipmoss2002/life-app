Test# Premium Subscription & Cloud Sync Testing Guide

## Overview

This guide explains how to test the premium subscription and cloud sync features in the Life App. These features require specific setup and testing approaches since they involve external services (AWS Cognito, S3, DynamoDB, and platform payment systems).

## Table of Contents

1. [Testing Approaches](#testing-approaches)
2. [Unit Tests (Already Implemented)](#unit-tests-already-implemented)
3. [Manual Testing - Authentication](#manual-testing---authentication)
4. [Manual Testing - Subscriptions](#manual-testing---subscriptions)
5. [Manual Testing - Cloud Sync](#manual-testing---cloud-sync)
6. [Testing Without AWS Setup](#testing-without-aws-setup)
7. [Testing With AWS Setup](#testing-with-aws-setup)
8. [Common Issues & Troubleshooting](#common-issues--troubleshooting)

---

## Testing Approaches

### 1. Automated Unit Tests ✅
- Already implemented and passing
- Test service logic with mocked dependencies
- Run with: `flutter test`

### 2. Manual Testing on Device 📱
- Test real authentication flows
- Test actual payment processing
- Test cloud synchronization
- Requires AWS setup for full testing

### 3. Sandbox Testing 🧪
- Use test payment accounts
- Use development AWS environment
- No real charges

---

## Unit Tests (Already Implemented)

All services have comprehensive unit tests that run automatically:

```bash
cd household_docs_app
flutter test
```

### What's Tested:

**Authentication Service** (`test/services/authentication_service_test.dart`):
- ✅ Sign up creates user account
- ✅ Sign in authenticates user
- ✅ Sign out clears session
- ✅ Get current user returns user info
- ✅ Confirm sign up verifies user
- ✅ Reset password initiates reset

**Subscription Service** (`test/services/subscription_service_test.dart`):
- ✅ Get subscription status
- ✅ Purchase subscription
- ✅ Cancel subscription
- ✅ Validate subscription

**Cloud Sync Service** (`test/services/cloud_sync_service_test.dart`):
- ✅ Start sync initiates synchronization
- ✅ Stop sync stops synchronization
- ✅ Get sync status returns status
- ✅ Handle conflict resolves conflicts

These tests use mocks and don't require AWS or payment setup.

---

## Manual Testing - Authentication

### Prerequisites
- AWS Cognito User Pool configured (see `AWS_SETUP_GUIDE.md`)
- Amplify configuration updated in `lib/config/amplify_config.dart`
- Amplify initialized in `main.dart` (uncomment initialization code)

### Test Scenarios

#### 1. Sign Up Flow

**Steps:**
1. Launch the app
2. Navigate to Sign Up screen
3. Enter email: `test@example.com`
4. Enter password: `TestPass123!`
5. Tap "Sign Up"
6. Check email for verification code
7. Enter verification code
8. Verify account is created

**Expected Results:**
- ✅ Sign up succeeds
- ✅ Verification email received
- ✅ Account verified successfully
- ✅ User can sign in

**Test Code Location:** `lib/services/authentication_service.dart`

#### 2. Sign In Flow

**Steps:**
1. Launch the app
2. Navigate to Sign In screen
3. Enter email: `test@example.com`
4. Enter password: `TestPass123!`
5. Tap "Sign In"

**Expected Results:**
- ✅ Sign in succeeds
- ✅ User redirected to home screen
- ✅ Auth token stored
- ✅ User session active

#### 3. Sign Out Flow

**Steps:**
1. While signed in, navigate to Settings
2. Tap "Sign Out"
3. Confirm sign out

**Expected Results:**
- ✅ User signed out
- ✅ Auth token cleared
- ✅ Redirected to sign in screen
- ✅ Cloud sync stopped

#### 4. Password Reset Flow

**Steps:**
1. On sign in screen, tap "Forgot Password"
2. Enter email: `test@example.com`
3. Tap "Send Reset Code"
4. Check email for reset code
5. Enter reset code and new password
6. Tap "Reset Password"
7. Sign in with new password

**Expected Results:**
- ✅ Reset code email received
- ✅ Password reset succeeds
- ✅ Can sign in with new password

### Testing Without AWS

If AWS is not set up, you can still test the UI flows:

1. Comment out Amplify calls in `authentication_service.dart`
2. Return mock success responses
3. Test UI navigation and validation
4. Test error handling with mock errors

---

## Manual Testing - Subscriptions

### Prerequisites
- Google Play Console or App Store Connect account
- In-app products configured
- Test accounts set up

### Android Testing (Google Play)

#### Setup Test Account

1. **Create Test Account:**
   - Go to Google Play Console
   - Settings → License Testing
   - Add test Gmail accounts
   - These accounts can make test purchases without charges

2. **Configure Test Products:**
   - Monetize → Products → In-app products
   - Create product: `premium_monthly`
   - Set test price (e.g., $0.99)
   - Activate product

#### Test Scenarios

##### 1. View Subscription Plans

**Steps:**
1. Launch app (not signed in to premium)
2. Navigate to Settings → Premium
3. View available plans

**Expected Results:**
- ✅ Monthly plan displayed
- ✅ Price shown correctly
- ✅ Description visible
- ✅ "Subscribe" button enabled

##### 2. Purchase Subscription

**Steps:**
1. On Premium screen, tap "Subscribe"
2. Google Play payment sheet appears
3. Select payment method (test account)
4. Confirm purchase
5. Wait for purchase to complete

**Expected Results:**
- ✅ Payment sheet appears
- ✅ Purchase processes successfully
- ✅ Subscription status updates to "Active"
- ✅ Premium features unlocked
- ✅ Cloud sync becomes available

**Test Code Location:** `lib/services/subscription_service.dart`

##### 3. Restore Purchases

**Steps:**
1. Uninstall and reinstall app
2. Sign in with same account
3. Navigate to Settings → Premium
4. Tap "Restore Purchases"

**Expected Results:**
- ✅ Previous subscription restored
- ✅ Premium features available
- ✅ No new charge

##### 4. Check Subscription Status

**Steps:**
1. While subscribed, navigate to Settings → Premium
2. View subscription details

**Expected Results:**
- ✅ Status shows "Active"
- ✅ Expiration date displayed
- ✅ "Manage Subscription" button visible

##### 5. Cancel Subscription

**Steps:**
1. Tap "Manage Subscription"
2. Redirected to Google Play
3. Cancel subscription
4. Return to app
5. Check status after expiration

**Expected Results:**
- ✅ Redirected to Google Play
- ✅ Can cancel subscription
- ✅ Access continues until expiration
- ✅ Status updates to "Expired" after date
- ✅ Cloud sync disabled after expiration

### iOS Testing (App Store)

#### Setup Test Account

1. **Create Sandbox Tester:**
   - App Store Connect → Users and Access
   - Sandbox Testers → Add tester
   - Use unique email (doesn't need to be real)

2. **Configure Test Products:**
   - App Store Connect → Your App → In-App Purchases
   - Create subscription: `premium_monthly`
   - Set test price
   - Submit for review (or use in sandbox)

#### Test Scenarios

Same as Android, but:
- Sign in with sandbox tester account on device
- Settings → App Store → Sandbox Account
- Purchases are free in sandbox mode

### Testing Without Payment Setup

You can test subscription logic without real payments:

1. **Mock Subscription Status:**
   ```dart
   // In subscription_service.dart
   Future<SubscriptionStatus> getSubscriptionStatus() async {
     // For testing, return active
     return SubscriptionStatus.active;
   }
   ```

2. **Test UI States:**
   - Free user view
   - Premium user view
   - Expired subscription view
   - Grace period view

3. **Test Feature Gating:**
   - Verify cloud sync requires premium
   - Verify free users see upgrade prompts

---

## Manual Testing - Cloud Sync

### Prerequisites
- AWS resources configured (Cognito, S3, DynamoDB)
- User authenticated
- Premium subscription active
- Network connectivity

### Test Scenarios

#### 1. Initial Sync Setup

**Steps:**
1. Sign in to app
2. Ensure premium subscription active
3. Navigate to Settings → Cloud Sync
4. Enable cloud sync
5. Tap "Sync Now"

**Expected Results:**
- ✅ Sync initializes successfully
- ✅ Local documents uploaded to cloud
- ✅ Sync status shows "Synced"
- ✅ Last sync time displayed

**Test Code Location:** `lib/services/cloud_sync_service.dart`

#### 2. Upload Document

**Steps:**
1. Create a new document
2. Add title, category, date
3. Attach a file (photo/PDF)
4. Save document
5. Wait for automatic sync (30 seconds) or tap "Sync Now"

**Expected Results:**
- ✅ Document appears in local database
- ✅ Sync status shows "Syncing"
- ✅ Document uploaded to DynamoDB
- ✅ File uploaded to S3
- ✅ Sync status changes to "Synced"
- ✅ Sync icon shows success

#### 3. Download Document (Multi-Device)

**Steps:**
1. On Device A: Create and sync document
2. On Device B: Sign in with same account
3. On Device B: Tap "Sync Now"
4. View documents list

**Expected Results:**
- ✅ Document appears on Device B
- ✅ All metadata matches
- ✅ File downloads successfully
- ✅ Can open file on Device B

#### 4. Update Document

**Steps:**
1. Edit an existing synced document
2. Change title or date
3. Save changes
4. Wait for sync or tap "Sync Now"

**Expected Results:**
- ✅ Changes saved locally
- ✅ Sync status shows "Syncing"
- ✅ Changes uploaded to cloud
- ✅ Version number incremented
- ✅ Sync status shows "Synced"

#### 5. Delete Document

**Steps:**
1. Delete a synced document
2. Confirm deletion
3. Wait for sync or tap "Sync Now"

**Expected Results:**
- ✅ Document removed locally
- ✅ Sync processes deletion
- ✅ Document removed from DynamoDB
- ✅ Files removed from S3
- ✅ Deletion syncs to other devices

#### 6. Conflict Resolution

**Steps:**
1. On Device A: Edit document, go offline
2. On Device B: Edit same document, sync
3. On Device A: Go online, sync

**Expected Results:**
- ✅ Conflict detected
- ✅ User prompted to resolve
- ✅ Can choose: Keep Local, Keep Remote, or Merge
- ✅ Resolution applied correctly
- ✅ Sync completes successfully

#### 7. Offline Mode

**Steps:**
1. Create/edit documents while offline
2. Verify documents saved locally
3. Go online
4. Sync automatically triggers

**Expected Results:**
- ✅ Documents saved locally while offline
- ✅ Sync queue builds up
- ✅ When online, queue processes
- ✅ All changes uploaded
- ✅ No data loss

#### 8. Wi-Fi Only Sync

**Steps:**
1. Enable "Wi-Fi Only" in Settings
2. On mobile data: Create document
3. Document queued but not synced
4. Connect to Wi-Fi
5. Sync automatically triggers

**Expected Results:**
- ✅ Sync paused on mobile data
- ✅ Pending changes indicator shown
- ✅ Sync resumes on Wi-Fi
- ✅ All queued changes uploaded

#### 9. Sync Status Monitoring

**Steps:**
1. Navigate to Settings → Cloud Sync
2. View sync status

**Expected Results:**
- ✅ Last sync time displayed
- ✅ Pending changes count shown
- ✅ Sync errors displayed (if any)
- ✅ "Sync Now" button available
- ✅ Real-time status updates

#### 10. Large File Upload

**Steps:**
1. Create document with large PDF (10+ MB)
2. Save and sync
3. Monitor progress

**Expected Results:**
- ✅ Upload progress shown
- ✅ Upload completes successfully
- ✅ File accessible on other devices
- ✅ No timeout errors

### Testing Sync Without AWS

You can test sync logic without AWS:

1. **Mock Cloud Operations:**
   ```dart
   // In document_sync_manager.dart
   Future<void> uploadDocument(Document doc) async {
     // Simulate upload delay
     await Future.delayed(Duration(seconds: 2));
     // Return success
   }
   ```

2. **Test Sync Queue:**
   - Create documents offline
   - Verify queue builds up
   - Verify queue processes when "online"

3. **Test UI States:**
   - Syncing indicator
   - Synced checkmark
   - Error icon
   - Pending changes badge

---

## Testing Without AWS Setup

If you don't have AWS configured yet, you can still test:

### 1. UI and Navigation
- Test all screens and navigation flows
- Test form validation
- Test error messages
- Test loading states

### 2. Local Functionality
- Create, edit, delete documents locally
- Test database operations
- Test file attachments locally
- Test notifications

### 3. Mock Services

Create a test mode that mocks cloud services:

```dart
// In main.dart
const bool TEST_MODE = true;

if (TEST_MODE) {
  // Use mock services
  Get.put<AuthenticationService>(MockAuthenticationService());
  Get.put<SubscriptionService>(MockSubscriptionService());
  Get.put<CloudSyncService>(MockCloudSyncService());
} else {
  // Use real services
  Get.put<AuthenticationService>(AuthenticationService());
  Get.put<SubscriptionService>(SubscriptionService());
  Get.put<CloudSyncService>(CloudSyncService());
}
```

### 4. Simulate Scenarios

```dart
class MockCloudSyncService extends CloudSyncService {
  @override
  Future<void> syncNow() async {
    // Simulate sync delay
    await Future.delayed(Duration(seconds: 2));
    
    // Simulate success
    print('Mock sync completed');
  }
  
  @override
  Future<SyncStatus> getSyncStatus() async {
    return SyncStatus(
      isSyncing: false,
      pendingChanges: 0,
      lastSyncTime: DateTime.now(),
    );
  }
}
```

---

## Testing With AWS Setup

### Full Integration Testing

Once AWS is configured, test the complete flow:

#### End-to-End Test Scenario

**Goal:** Verify complete user journey from sign up to multi-device sync

**Steps:**

1. **Device A - Initial Setup:**
   - Launch app (fresh install)
   - Sign up new account
   - Verify email
   - Sign in
   - Purchase premium subscription (test account)
   - Enable cloud sync
   - Create 3 documents with files
   - Wait for sync to complete

2. **Device B - Sync Down:**
   - Launch app (fresh install)
   - Sign in with same account
   - Verify premium status restored
   - Enable cloud sync
   - Tap "Sync Now"
   - Verify all 3 documents appear
   - Open files to verify downloads

3. **Device B - Make Changes:**
   - Edit document #1
   - Delete document #2
   - Create document #4
   - Wait for sync

4. **Device A - Verify Changes:**
   - Tap "Sync Now"
   - Verify document #1 updated
   - Verify document #2 deleted
   - Verify document #4 appears

5. **Conflict Test:**
   - Device A: Go offline (airplane mode)
   - Device A: Edit document #3
   - Device B: Edit document #3 differently
   - Device B: Sync
   - Device A: Go online and sync
   - Device A: Resolve conflict
   - Device B: Sync and verify resolution

**Expected Results:**
- ✅ All operations succeed
- ✅ Data consistent across devices
- ✅ No data loss
- ✅ Conflicts handled gracefully
- ✅ Files accessible on both devices

### Performance Testing

Test sync performance with various scenarios:

1. **Small Dataset:**
   - 10 documents, 1 MB total
   - Should sync in < 5 seconds

2. **Medium Dataset:**
   - 100 documents, 50 MB total
   - Should sync in < 30 seconds

3. **Large Dataset:**
   - 500 documents, 200 MB total
   - Should sync in < 2 minutes

4. **Large Files:**
   - Single 50 MB PDF
   - Should upload with progress indicator
   - Should not timeout

### Stress Testing

1. **Rapid Changes:**
   - Create 20 documents quickly
   - Verify all sync correctly

2. **Network Interruption:**
   - Start sync
   - Disable network mid-sync
   - Re-enable network
   - Verify sync resumes and completes

3. **Concurrent Edits:**
   - Edit same document on 3 devices simultaneously
   - Verify conflicts detected
   - Verify all devices can resolve

---

## Common Issues & Troubleshooting

### Authentication Issues

**Problem:** Sign up fails with "User already exists"
- **Solution:** User already registered, use sign in instead or use different email

**Problem:** Email verification code not received
- **Solution:** Check spam folder, verify Cognito email settings, resend code

**Problem:** "Not authorized" errors
- **Solution:** Sign out and sign in again to refresh token

### Subscription Issues

**Problem:** Purchase doesn't complete
- **Solution:** Verify test account configured, check payment method, try restore purchases

**Problem:** Subscription status not updating
- **Solution:** Restart app, call `restorePurchases()`, verify backend validation

**Problem:** "Product not found" error
- **Solution:** Verify product ID matches in code and store console, verify product is active

### Sync Issues

**Problem:** Documents not syncing
- **Solution:** Check network connectivity, verify premium subscription active, check sync settings

**Problem:** "Sync failed" errors
- **Solution:** Check AWS credentials, verify IAM permissions, check CloudWatch logs

**Problem:** Files not downloading
- **Solution:** Verify S3 bucket permissions, check file paths, verify storage space on device

**Problem:** Sync stuck in "Syncing" state
- **Solution:** Stop and restart sync, clear sync queue, check for conflicts

**Problem:** Conflicts not resolving
- **Solution:** Manually resolve conflict, check version numbers, verify conflict resolution logic

### Network Issues

**Problem:** Sync only works on Wi-Fi
- **Solution:** Check "Wi-Fi Only" setting, verify mobile data enabled for app

**Problem:** Slow sync performance
- **Solution:** Check network speed, reduce file sizes, use batch sync for multiple documents

**Problem:** Timeout errors
- **Solution:** Increase timeout values, check AWS region latency, verify network stability

### AWS Configuration Issues

**Problem:** "Amplify not configured" error
- **Solution:** Verify `amplify_config.dart` has correct values, uncomment initialization in `main.dart`

**Problem:** "Access denied" errors
- **Solution:** Check IAM policies, verify Cognito identity pool permissions, check S3 bucket policy

**Problem:** "Resource not found" errors
- **Solution:** Verify AWS resource IDs correct, check region matches, verify resources exist

---

## Testing Checklist

Use this checklist to ensure comprehensive testing:

### Authentication ✅
- [ ] Sign up with valid email
- [ ] Sign up with invalid email (error handling)
- [ ] Email verification
- [ ] Sign in with correct credentials
- [ ] Sign in with wrong password (error handling)
- [ ] Sign out
- [ ] Password reset flow
- [ ] Token refresh
- [ ] Session persistence across app restarts

### Subscriptions ✅
- [ ] View available plans
- [ ] Purchase subscription (test account)
- [ ] Subscription status updates
- [ ] Premium features unlock
- [ ] Restore purchases
- [ ] Cancel subscription
- [ ] Subscription expiration handling
- [ ] Grace period handling

### Cloud Sync ✅
- [ ] Initial sync setup
- [ ] Upload new document
- [ ] Download document on second device
- [ ] Update document and sync
- [ ] Delete document and sync
- [ ] Conflict detection
- [ ] Conflict resolution
- [ ] Offline mode (queue operations)
- [ ] Wi-Fi only mode
- [ ] Sync status monitoring
- [ ] Large file upload
- [ ] Batch sync multiple documents
- [ ] Sync error handling
- [ ] Sync retry logic

### Integration ✅
- [ ] End-to-end user journey
- [ ] Multi-device synchronization
- [ ] Subscription + sync integration
- [ ] Auth + sync integration
- [ ] Network interruption recovery
- [ ] App restart persistence

---

## Next Steps

1. **Run Unit Tests:**
   ```bash
   flutter test
   ```

2. **Set Up AWS (if not done):**
   - Follow `AWS_SETUP_GUIDE.md`
   - Update `amplify_config.dart`

3. **Set Up Payment Testing:**
   - Configure test accounts in Play Console / App Store Connect
   - Create test products

4. **Manual Testing:**
   - Follow scenarios in this guide
   - Test on physical devices
   - Test with multiple devices

5. **Monitor & Debug:**
   - Check console logs
   - Monitor AWS CloudWatch
   - Track analytics events

---

## Resources

- **AWS Setup:** `AWS_SETUP_GUIDE.md`
- **Device Testing:** `DEVICE_TESTING.md`
- **General Testing:** `TESTING.md`
- **Design Doc:** `.kiro/specs/cloud-sync-premium/design.md`
- **Requirements:** `.kiro/specs/cloud-sync-premium/requirements.md`

## Support

If you encounter issues:
1. Check console logs for error messages
2. Review AWS CloudWatch logs
3. Verify all configuration values
4. Test with mock services first
5. Gradually enable real services

---

**Last Updated:** December 2024
