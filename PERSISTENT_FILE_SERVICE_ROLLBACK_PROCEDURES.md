# Persistent File Service Rollback Procedures

## Overview

This document provides detailed rollback procedures for the persistent file access system. It covers various rollback scenarios, step-by-step procedures, and recovery strategies to ensure system stability and data integrity.

## Table of Contents

1. [Rollback Decision Matrix](#rollback-decision-matrix)
2. [Rollback Scenarios](#rollback-scenarios)
3. [Emergency Rollback](#emergency-rollback)
4. [Partial Rollback](#partial-rollback)
5. [Individual User Rollback](#individual-user-rollback)
6. [Data Recovery](#data-recovery)
7. [Post-Rollback Validation](#post-rollback-validation)

---

## Rollback Decision Matrix

### When to Rollback

| Severity | Criteria | Action | Timeline |
|----------|----------|--------|----------|
| **Critical** | Migration failure rate >20% | Immediate rollback | <15 min |
| **Critical** | Data loss reported | Immediate rollback | <15 min |
| **Critical** | Authentication broken | Immediate rollback | <15 min |
| **High** | Migration failure rate 10-20% | Disable migration, investigate | <1 hour |
| **High** | File access errors >10% | Enable fallback, investigate | <1 hour |
| **Medium** | Performance degradation >50% | Optimize, consider rollback | <4 hours |
| **Low** | Minor issues affecting <5% users | Fix forward, no rollback | <24 hours |

### Rollback Authority

| Severity | Who Can Authorize | Notification Required |
|----------|-------------------|----------------------|
| **Critical** | On-call engineer | Team lead (immediate) |
| **High** | Team lead | Engineering manager (within 1 hour) |
| **Medium** | Engineering manager | CTO (within 4 hours) |
| **Low** | Product manager | Team (within 24 hours) |

---

## Rollback Scenarios

### Scenario 1: High Migration Failure Rate

**Trigger**: Migration failure rate >10%

**Impact**: Existing users cannot migrate to new file paths

**Rollback Strategy**: Disable automatic migration

#### Step-by-Step Procedure

**Step 1: Disable Automatic Migration** (5 minutes)

```dart
// In lib/providers/auth_provider.dart
// Comment out the migration call

Future<void> checkAuthStatus() async {
  try {
    final isAuth = await _authService.isAuthenticated();
    if (isAuth) {
      _currentUser = await _authService.getCurrentUser();
      _authState = AuthState.authenticated;

      await _migrateDocumentsToCurrentUser();

      // DISABLED: Automatic migration
      // await _checkAndPerformFileMigration();

      await _initializeCloudSyncIfEligible();
    } else {
      _currentUser = null;
      _authState = AuthState.unauthenticated;
    }
  } catch (e) {
    debugPrint('Error checking auth status: $e');
    _currentUser = null;
    _authState = AuthState.unauthenticated;
  }
  notifyListeners();
}

Future<bool> signIn(String email, String password) async {
  try {
    _currentUser = await _authService.signIn(email, password);

    // ... existing code ...

    await _migrateDocumentsToCurrentUser();

    // DISABLED: Automatic migration
    // await _checkAndPerformFileMigration();

    await _initializeCloudSyncIfEligible();

    _authState = AuthState.authenticated;
    notifyListeners();
    return true;
  } catch (e) {
    // ... error handling ...
  }
}
```

**Step 2: Build Hotfix** (10 minutes)

```bash
# Increment patch version
# Update pubspec.yaml: version: 1.0.1+2 -> 1.0.2+3

# Build release
flutter build apk --release
# or
flutter build appbundle --release
```

**Step 3: Deploy Hotfix** (30 minutes)

```bash
# Upload to Play Store / App Store
# Mark as emergency release
# Request expedited review
```

**Step 4: Verify Deployment** (15 minutes)

- Monitor app version adoption
- Verify migration no longer triggering
- Check error rates decreasing
- Confirm users can still access files via fallback

**Step 5: Investigate Root Cause** (1-4 hours)

- Review migration failure logs
- Identify common failure patterns
- Determine fix strategy
- Plan re-enablement

**Recovery**: Once fixed, re-enable migration and deploy update

---

### Scenario 2: File Access Issues

**Trigger**: Users unable to access files (>5% error rate)

**Impact**: Users cannot view/download their documents

**Rollback Strategy**: Enable fallback mechanism, investigate S3/Cognito issues

#### Step-by-Step Procedure

**Step 1: Verify Fallback Mechanism** (5 minutes)

The PersistentFileService has built-in fallback to legacy paths. Verify it's working:

```dart
// Check if fallback methods are being used
// These should automatically activate on User Pool sub path failures:
// - downloadFileWithFallback()
// - fileExistsWithFallback()
```

**Step 2: Check AWS Services** (10 minutes)

```bash
# Check S3 bucket status
aws s3 ls s3://householddocsapp9f4f55b3c6c94dc9a01229ca901e486/

# Check Cognito User Pool status
aws cognito-idp describe-user-pool --user-pool-id YOUR_USER_POOL_ID

# Check for AWS service outages
# Visit: https://status.aws.amazon.com/
```

**Step 3: Verify S3 Bucket Permissions** (15 minutes)

```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket householddocsapp9f4f55b3c6c94dc9a01229ca901e486

# Check IAM policies
aws iam get-policy --policy-arn YOUR_POLICY_ARN
```

**Step 4: Review CloudWatch Logs** (20 minutes)

```bash
# Check for S3 access denied errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/amplify-* \
  --filter-pattern "Access Denied" \
  --start-time $(date -d '1 hour ago' +%s)000

# Check for Cognito errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/amplify-* \
  --filter-pattern "Cognito" \
  --start-time $(date -d '1 hour ago' +%s)000
```

**Step 5: Implement Fix** (varies)

Depending on root cause:
- **S3 permissions**: Update bucket policy
- **Cognito issues**: Verify User Pool configuration
- **Network issues**: Wait for resolution
- **Code bug**: Deploy hotfix

**Recovery**: Verify file access restored, monitor error rates

---

### Scenario 3: Authentication Issues

**Trigger**: Users cannot authenticate (>5% failure rate)

**Impact**: Users cannot login to app

**Rollback Strategy**: Rollback to previous app version

#### Step-by-Step Procedure

**Step 1: Verify Issue Scope** (5 minutes)

- Check authentication error rate
- Identify affected users (all vs. subset)
- Verify Cognito User Pool status
- Check for AWS outages

**Step 2: Immediate Mitigation** (10 minutes)

If Cognito is down:
- Display user-friendly error message
- Implement retry logic
- Enable offline mode if applicable

**Step 3: Rollback App Version** (30-60 minutes)

**Android (Google Play)**:
```
1. Go to Google Play Console
2. Select app: Household Docs
3. Navigate to: Release > Production
4. Find current release
5. Click "Rollback" button
6. Confirm rollback
7. Monitor rollback progress
```

**iOS (App Store)**:
```
1. Go to App Store Connect
2. Select app: Household Docs
3. Navigate to: App Store tab
4. Select previous version
5. Click "Submit for Review"
6. Request expedited review
7. Monitor review status
```

**Step 4: Verify Rollback** (15 minutes)

- Monitor app version distribution
- Check authentication success rate
- Verify users can login
- Confirm no new errors

**Step 5: Investigate Root Cause** (1-4 hours)

- Review authentication code changes
- Check Amplify configuration
- Verify Cognito User Pool settings
- Identify fix strategy

**Recovery**: Fix authentication issue, test thoroughly, redeploy

---

### Scenario 4: Performance Degradation

**Trigger**: File operations taking >30s (>50% slower than baseline)

**Impact**: Poor user experience, timeouts

**Rollback Strategy**: Optimize performance, scale infrastructure

#### Step-by-Step Procedure

**Step 1: Identify Bottleneck** (15 minutes)

```bash
# Check S3 performance metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/S3 \
  --metric-name FirstByteLatency \
  --dimensions Name=BucketName,Value=householddocsapp9f4f55b3c6c94dc9a01229ca901e486 \
  --start-time $(date -d '1 hour ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Average

# Check Cognito performance
aws cloudwatch get-metric-statistics \
  --namespace AWS/Cognito \
  --metric-name UserAuthentication \
  --start-time $(date -d '1 hour ago' --iso-8601) \
  --end-time $(date --iso-8601) \
  --period 300 \
  --statistics Average
```

**Step 2: Implement Quick Optimizations** (30 minutes)

Possible optimizations:
- Increase retry timeouts
- Reduce concurrent operations
- Enable more aggressive caching
- Optimize file sizes

**Step 3: Scale Infrastructure** (if needed)

```bash
# Increase S3 request rate limits (if applicable)
# Contact AWS support for S3 performance optimization

# Scale Cognito User Pool (if needed)
# Cognito automatically scales, but verify no throttling
```

**Step 4: Monitor Improvements** (30 minutes)

- Track operation duration metrics
- Verify performance improving
- Check user feedback
- Confirm no new errors

**Recovery**: Performance returns to baseline, user experience acceptable

---

## Emergency Rollback

### Critical Situation Response

**Trigger**: Critical production issue requiring immediate action

**Timeline**: 0-60 minutes

### Emergency Rollback Procedure

#### Phase 1: Immediate Response (0-15 minutes)

**Actions**:
1. **Declare Incident**: Notify team via emergency channel
2. **Assess Impact**: Determine severity and scope
3. **Make Decision**: Rollback vs. fix forward
4. **Execute Rollback**: Follow fastest rollback path

**Communication**:
```
INCIDENT ALERT: Persistent File Service Critical Issue
Severity: CRITICAL
Impact: [describe impact]
Action: Initiating emergency rollback
ETA: 15 minutes
Incident Commander: [name]
```

#### Phase 2: Rollback Execution (15-45 minutes)

**Option A: Disable Migration** (fastest - 15 minutes)
1. Comment out migration calls in AuthProvider
2. Build hotfix APK/AAB
3. Upload to Play Store with emergency flag
4. Request expedited review

**Option B: Rollback App Version** (medium - 30 minutes)
1. Rollback to previous version in Play Store
2. Rollback to previous version in App Store
3. Monitor version adoption
4. Verify issue resolved

**Option C: Rollback Backend** (if Amplify changes made - 45 minutes)
1. Revert Amplify configuration
2. Push reverted config to AWS
3. Verify backend rollback
4. Test app functionality

#### Phase 3: Verification (45-60 minutes)

**Verify**:
- Issue resolved
- Error rates normal
- Users can access app
- No data loss
- Monitoring stable

**Communication**:
```
INCIDENT UPDATE: Rollback Complete
Status: Resolved
Resolution: [describe resolution]
Impact Duration: [duration]
Next Steps: Root cause analysis
```

### Emergency Contacts

| Role | Name | Contact | Backup |
|------|------|---------|--------|
| Incident Commander | [Name] | [Phone] | [Backup Name] |
| Engineering Lead | [Name] | [Phone] | [Backup Name] |
| DevOps Lead | [Name] | [Phone] | [Backup Name] |
| Product Manager | [Name] | [Phone] | [Backup Name] |

---

## Partial Rollback

### Gradual Rollback Strategy

**Use Case**: Issues affecting subset of users or specific features

### Feature Flag Rollback

**If feature flags are implemented**:

```dart
// Disable migration for specific user segments
class FeatureFlags {
  static bool isMigrationEnabled(String userId) {
    // Disable for affected users
    if (affectedUserIds.contains(userId)) {
      return false;
    }
    return true;
  }
}

// In AuthProvider
if (FeatureFlags.isMigrationEnabled(_currentUser!.id)) {
  await _checkAndPerformFileMigration();
}
```

### Percentage Rollback

**Gradually disable for increasing percentage of users**:

```dart
// Disable migration for X% of users
class RolloutControl {
  static bool shouldEnableMigration(String userId) {
    // Hash user ID to get consistent percentage
    final hash = userId.hashCode.abs();
    final percentage = hash % 100;
    
    // Enable for only 50% of users (rollback 50%)
    return percentage < 50;
  }
}
```

### User Segment Rollback

**Disable for specific user segments**:

```dart
// Disable migration for users with many files
class MigrationControl {
  static Future<bool> shouldEnableMigration(String userId) async {
    final fileCount = await getFileCount(userId);
    
    // Disable for users with >100 files
    if (fileCount > 100) {
      return false;
    }
    
    return true;
  }
}
```

---

## Individual User Rollback

### User-Specific Rollback

**Use Case**: Specific user experiencing issues

### Rollback Procedure

**Step 1: Identify User**

```dart
// Get user information
final userId = 'user-pool-sub-here';
final userEmail = 'user@example.com';
```

**Step 2: Rollback User's Migration**

```dart
// Rollback migration for specific user
final persistentFileService = PersistentFileService();

try {
  // Rollback all files for user
  await persistentFileService.rollbackMigration();
  
  print('✅ User migration rolled back successfully');
} catch (e) {
  print('❌ Rollback failed: $e');
}
```

**Step 3: Verify Rollback**

```dart
// Verify files accessible via legacy paths
final legacyFiles = await persistentFileService.findLegacyFiles();
print('Legacy files found: ${legacyFiles.length}');

// Verify migration status
final status = await persistentFileService.getMigrationStatus();
print('Migration status: ${status['migrationComplete']}');
```

**Step 4: Test File Access**

1. Have user login
2. Verify files appear in app
3. Test file download
4. Test file upload
5. Confirm all operations work

### Rollback Specific Files

**If only specific files have issues**:

```dart
// Rollback specific sync ID
final syncId = 'document-sync-id';

try {
  await persistentFileService.rollbackMigrationForSyncId(syncId);
  print('✅ File rolled back successfully');
} catch (e) {
  print('❌ Rollback failed: $e');
}
```

---

## Data Recovery

### Data Loss Prevention

**The persistent file service is designed to prevent data loss**:

1. **No Deletion**: Migration copies files, doesn't delete originals
2. **Fallback**: Automatic fallback to legacy paths if new paths fail
3. **Verification**: Migration verifies success before marking complete
4. **Rollback**: Can rollback to legacy paths at any time

### Recovery Procedures

#### Scenario: Files Not Accessible After Migration

**Step 1: Check Both Paths**

```dart
// Check User Pool sub path
final newPath = 'private/{userPoolSub}/documents/{syncId}/{fileName}';
final newExists = await checkFileExists(newPath);

// Check legacy path
final legacyPath = 'protected/{username}/documents/{syncId}/{fileName}';
final legacyExists = await checkFileExists(legacyPath);

print('New path exists: $newExists');
print('Legacy path exists: $legacyExists');
```

**Step 2: Use Fallback**

```dart
// Download using fallback mechanism
final file = await persistentFileService.downloadFileWithFallback(
  s3Key,
  syncId,
);
```

**Step 3: Re-migrate if Needed**

```dart
// Force re-migration
await persistentFileService.migrateExistingUser(forceReMigration: true);
```

#### Scenario: Corrupted Files

**Step 1: Verify File Integrity**

```dart
// Check file checksums
final originalChecksum = await getFileChecksum(legacyPath);
final migratedChecksum = await getFileChecksum(newPath);

if (originalChecksum != migratedChecksum) {
  print('⚠️ File corruption detected');
}
```

**Step 2: Restore from Legacy**

```dart
// Copy from legacy path to new path
await copyFile(legacyPath, newPath);

// Verify restoration
final restoredChecksum = await getFileChecksum(newPath);
assert(restoredChecksum == originalChecksum);
```

### S3 Versioning

**If S3 versioning is enabled**:

```bash
# List file versions
aws s3api list-object-versions \
  --bucket householddocsapp9f4f55b3c6c94dc9a01229ca901e486 \
  --prefix private/{userPoolSub}/documents/

# Restore specific version
aws s3api copy-object \
  --bucket householddocsapp9f4f55b3c6c94dc9a01229ca901e486 \
  --copy-source householddocsapp9f4f55b3c6c94dc9a01229ca901e486/private/{userPoolSub}/documents/{syncId}/{fileName}?versionId={versionId} \
  --key private/{userPoolSub}/documents/{syncId}/{fileName}
```

---

## Post-Rollback Validation

### Validation Checklist

After any rollback, validate:

- [ ] Users can authenticate
- [ ] Files are accessible
- [ ] File operations work (upload, download, delete)
- [ ] Error rates returned to normal
- [ ] Performance within targets
- [ ] No data loss reported
- [ ] Monitoring shows healthy metrics
- [ ] User feedback positive

### Validation Tests

**Test 1: Authentication**
```
1. Login with test account
2. Verify successful authentication
3. Check User Pool sub retrieved
4. Confirm no errors
```

**Test 2: File Access**
```
1. View file list
2. Download existing file
3. Upload new file
4. Delete test file
5. Verify all operations successful
```

**Test 3: Cross-Device**
```
1. Login on Device A
2. Upload file
3. Login on Device B
4. Verify file appears
5. Download file
6. Confirm content matches
```

### Metrics to Monitor

| Metric | Target | Acceptable Range |
|--------|--------|------------------|
| Authentication Success Rate | >99% | >95% |
| File Access Success Rate | >99% | >95% |
| Error Rate | <1% | <5% |
| Performance (Upload 1MB) | <10s | <20s |
| Performance (Download 1MB) | <5s | <10s |

### Post-Rollback Report

**Template**:
```
# Rollback Report

## Incident Summary
- Date/Time: [timestamp]
- Duration: [duration]
- Severity: [Critical/High/Medium/Low]
- Impact: [description]

## Rollback Details
- Trigger: [what triggered rollback]
- Decision: [who authorized]
- Method: [rollback method used]
- Duration: [rollback duration]

## Root Cause
- Cause: [root cause analysis]
- Contributing Factors: [list factors]

## Resolution
- Actions Taken: [list actions]
- Verification: [how verified]
- Status: [resolved/monitoring]

## Lessons Learned
- What Went Well: [list]
- What Could Improve: [list]
- Action Items: [list with owners]

## Prevention
- Monitoring Improvements: [list]
- Testing Improvements: [list]
- Process Improvements: [list]
```

---

## Conclusion

This rollback procedures document provides comprehensive guidance for handling various rollback scenarios. Key points:

1. **Clear Decision Matrix**: Know when to rollback based on severity
2. **Multiple Rollback Options**: App version, feature disable, partial rollback
3. **Data Safety**: No data loss due to migration design
4. **Quick Response**: Emergency procedures for critical issues
5. **Validation**: Thorough post-rollback validation

**Remember**:
- Rollback is always an option
- Data safety is paramount
- Communication is critical
- Learn from incidents
- Improve processes

For questions or assistance during rollback, contact the development team or on-call engineer.

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Author**: Development Team  
**Review Date**: Post-deployment + 30 days
