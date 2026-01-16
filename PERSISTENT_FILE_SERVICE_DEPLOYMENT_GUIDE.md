# Persistent File Service Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying the persistent file access system using AWS Cognito User Pool sub identifiers and S3 private access level. It covers configuration updates, deployment procedures, monitoring setup, and rollback procedures.

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [S3 Bucket Configuration](#s3-bucket-configuration)
3. [Amplify Configuration](#amplify-configuration)
4. [Deployment Procedures](#deployment-procedures)
5. [Monitoring and Alerting](#monitoring-and-alerting)
6. [Rollback Procedures](#rollback-procedures)
7. [Post-Deployment Validation](#post-deployment-validation)
8. [Troubleshooting](#troubleshooting)

---

## Pre-Deployment Checklist

### Code Validation

- [ ] All unit tests passing (200+ tests)
- [ ] All property-based tests passing (30+ tests)
- [ ] Integration test plan reviewed
- [ ] Performance test plan reviewed
- [ ] UAT plan reviewed
- [ ] No compilation errors or warnings
- [ ] Code review completed

### Documentation Review

- [ ] Requirements document reviewed
- [ ] Design document reviewed
- [ ] Implementation plan reviewed
- [ ] Migration integration guide reviewed
- [ ] Authentication integration guide reviewed
- [ ] Logging integration guide reviewed
- [ ] Monitoring integration guide reviewed

### Infrastructure Validation

- [ ] AWS Cognito User Pool configured
- [ ] S3 bucket exists and accessible
- [ ] IAM policies reviewed
- [ ] Network connectivity verified
- [ ] SSL/TLS certificates valid

### Testing Validation

- [ ] New user flow tested
- [ ] Existing user migration tested
- [ ] Cross-device access tested
- [ ] Offline/online scenarios tested
- [ ] Error handling tested
- [ ] Rollback procedures tested

---

## S3 Bucket Configuration

### Current Configuration

The S3 bucket is currently configured with:
- **Resource Name**: `s347b21250`
- **Bucket Name**: `householddocsapp9f4f55b3c6c94dc9a01229ca901e486`
- **Storage Access**: `auth` (authenticated users only)
- **Auth Access**: `CREATE_AND_UPDATE`, `READ`, `DELETE`

### Private Access Level Verification

The persistent file service uses S3 **private access level**, which means:
- Files are stored at path: `private/{userPoolSub}/documents/{syncId}/{fileName}`
- Only the authenticated user (identified by User Pool sub) can access their files
- AWS Amplify automatically enforces access control based on Cognito identity

### Required S3 Bucket Policies

The current Amplify configuration automatically creates appropriate IAM policies for private access. **No manual S3 bucket policy changes are required** because:

1. **Amplify Manages Policies**: Amplify CLI automatically configures S3 bucket policies when storage is added
2. **Private Access Built-in**: The `private/` prefix is automatically protected by Amplify
3. **User Pool Integration**: Cognito User Pool sub is automatically used for access control

### Verification Steps

To verify S3 bucket configuration:

```bash
# Navigate to project directory
cd household_docs_app

# Check Amplify storage configuration
amplify status

# Expected output should show:
# Storage: s347b21250 (No Change)
```

### Optional: Manual Policy Verification

If you want to manually verify the S3 bucket policy:

1. Open AWS Console
2. Navigate to S3 service
3. Find bucket: `householddocsapp9f4f55b3c6c94dc9a01229ca901e486`
4. Go to "Permissions" tab
5. Review "Bucket Policy"
6. Verify policy allows authenticated users to access `private/${cognito-identity.amazonaws.com:sub}/*`

**Expected Policy Structure**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:role/amplify-*"
      },
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::BUCKET_NAME/private/${cognito-identity.amazonaws.com:sub}/*"
    }
  ]
}
```

### CORS Configuration

Verify CORS is configured for web access (if applicable):

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": ["ETag"]
  }
]
```

---

## Amplify Configuration

### Current Amplify Setup

The app uses Amplify for:
- **Authentication**: AWS Cognito User Pool
- **Storage**: S3 bucket with private access
- **API**: GraphQL API (AppSync)

### Configuration Files

**Location**: `household_docs_app/amplify/backend/storage/s347b21250/cli-inputs.json`

**Current Configuration**:
```json
{
  "resourceName": "s347b21250",
  "policyUUID": "47b21250",
  "bucketName": "householddocsapp9f4f55b3c6c94dc9a01229ca901e486",
  "storageAccess": "auth",
  "guestAccess": [],
  "authAccess": [
    "CREATE_AND_UPDATE",
    "READ",
    "DELETE"
  ],
  "groupAccess": {}
}
```

### Verification

**No configuration changes are required** for the persistent file service because:

1. **Storage Access**: Already set to `auth` (authenticated users only)
2. **Auth Access**: Already includes `CREATE_AND_UPDATE`, `READ`, `DELETE`
3. **Private Access**: Amplify automatically supports `private/` prefix
4. **User Pool Sub**: Amplify automatically uses Cognito User Pool sub for access control

### Amplify Status Check

```bash
# Check current Amplify status
cd household_docs_app
amplify status

# Expected output:
# Current Environment: dev (or your environment name)
# 
# | Category | Resource name | Operation | Provider plugin   |
# | -------- | ------------- | --------- | ----------------- |
# | Auth     | ...           | No Change | awscloudformation |
# | Storage  | s347b21250    | No Change | awscloudformation |
# | Api      | ...           | No Change | awscloudformation |
```

### If Changes Are Needed

If you need to update Amplify configuration:

```bash
# Update storage configuration (if needed)
amplify update storage

# Push changes to cloud
amplify push

# Verify deployment
amplify status
```

**Note**: For this deployment, **no Amplify changes are required**. The existing configuration already supports private access level with User Pool sub identifiers.

---

## Deployment Procedures

### Deployment Strategy

**Recommended Approach**: Phased rollout with monitoring

1. **Phase 1**: Internal testing (1-2 days)
2. **Phase 2**: Beta users (3-5 days)
3. **Phase 3**: Gradual rollout (1-2 weeks)
4. **Phase 4**: Full deployment

### Phase 1: Internal Testing

**Objective**: Validate deployment with internal team

**Steps**:
1. Deploy to internal test environment
2. Test with internal user accounts
3. Verify migration works correctly
4. Monitor logs for errors
5. Validate file access across devices

**Success Criteria**:
- All internal users can authenticate
- Migration completes successfully
- Files accessible on all devices
- No critical errors in logs

### Phase 2: Beta Users

**Objective**: Validate with real users in controlled environment

**Steps**:
1. Deploy to beta environment
2. Invite 10-20 beta users
3. Monitor migration success rates
4. Collect user feedback
5. Address any issues found

**Success Criteria**:
- 95%+ migration success rate
- No data loss reported
- Positive user feedback
- Performance within targets

### Phase 3: Gradual Rollout

**Objective**: Deploy to production with gradual user adoption

**Steps**:
1. Deploy to production
2. Enable for 10% of users (Day 1)
3. Monitor metrics closely
4. Increase to 25% (Day 3)
5. Increase to 50% (Day 5)
6. Increase to 100% (Day 7)

**Success Criteria**:
- Migration success rate >99%
- No increase in error rates
- Performance within targets
- No user complaints

### Phase 4: Full Deployment

**Objective**: Complete rollout to all users

**Steps**:
1. Enable for all users
2. Monitor for 48 hours
3. Verify all metrics stable
4. Document lessons learned
5. Plan for legacy cleanup

**Success Criteria**:
- All users migrated successfully
- System stable
- Performance optimal
- Documentation complete

### Deployment Commands

#### Flutter App Deployment

**Android**:
```bash
# Build release APK
cd household_docs_app
flutter build apk --release

# Or build App Bundle for Play Store
flutter build appbundle --release

# APK location: build/app/outputs/flutter-apk/app-release.apk
# AAB location: build/app/outputs/bundle/release/app-release.aab
```

**iOS**:
```bash
# Build release IPA
cd household_docs_app
flutter build ios --release

# Open Xcode for signing and upload
open ios/Runner.xcworkspace
```

#### Backend Deployment

**If Amplify changes are needed**:
```bash
# Push Amplify changes
cd household_docs_app
amplify push

# Verify deployment
amplify status
```

**Note**: For this deployment, no backend changes are required.

### Deployment Checklist

- [ ] Code merged to main branch
- [ ] Version number updated in `pubspec.yaml`
- [ ] Release notes prepared
- [ ] App built successfully
- [ ] App signed with release keys
- [ ] Backend configuration verified
- [ ] Monitoring configured
- [ ] Alerting configured
- [ ] Rollback plan ready
- [ ] Team notified of deployment

---

## Monitoring and Alerting

### Key Metrics to Monitor

#### Migration Metrics

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Migration Success Rate | >99% | <95% |
| Migration Duration (10 files) | <10s | >30s |
| Migration Failures | <1% | >5% |
| Fallback Usage Rate | <5% | >10% |

#### File Operation Metrics

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Upload Success Rate | >99% | <95% |
| Download Success Rate | >99% | <95% |
| Delete Success Rate | >99% | <95% |
| Upload Duration (1MB) | <10s | >30s |
| Download Duration (1MB) | <5s | >15s |

#### Authentication Metrics

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Login Success Rate | >99% | <95% |
| User Pool Sub Retrieval | <100ms | >500ms |
| Authentication Errors | <1% | >5% |

### Monitoring Setup

#### 1. CloudWatch Logs

**Log Groups to Monitor**:
- `/aws/lambda/amplify-*` - Amplify function logs
- `/aws/appsync/*` - GraphQL API logs
- Application logs from mobile devices

**Key Log Patterns**:
```
# Migration success
"✅ File migration completed successfully"

# Migration failure
"⚠️ File migration completed with errors"

# File operation errors
"❌ PersistentFileService upload failed"
"❌ PersistentFileService download failed"
"❌ PersistentFileService delete failed"
```

#### 2. CloudWatch Metrics

**Custom Metrics to Create**:
```
Namespace: HouseholdDocs/PersistentFileService

Metrics:
- MigrationAttempts (Count)
- MigrationSuccesses (Count)
- MigrationFailures (Count)
- MigrationDuration (Milliseconds)
- FileUploadAttempts (Count)
- FileUploadSuccesses (Count)
- FileUploadFailures (Count)
- FileDownloadAttempts (Count)
- FileDownloadSuccesses (Count)
- FileDownloadFailures (Count)
```

#### 3. CloudWatch Alarms

**Critical Alarms**:

**Migration Failure Rate Alarm**:
```json
{
  "AlarmName": "PersistentFileService-HighMigrationFailureRate",
  "MetricName": "MigrationFailures",
  "Namespace": "HouseholdDocs/PersistentFileService",
  "Statistic": "Sum",
  "Period": 300,
  "EvaluationPeriods": 2,
  "Threshold": 5,
  "ComparisonOperator": "GreaterThanThreshold",
  "AlarmActions": ["arn:aws:sns:REGION:ACCOUNT:alerts"]
}
```

**File Operation Failure Alarm**:
```json
{
  "AlarmName": "PersistentFileService-HighFileOperationFailureRate",
  "MetricName": "FileUploadFailures",
  "Namespace": "HouseholdDocs/PersistentFileService",
  "Statistic": "Sum",
  "Period": 300,
  "EvaluationPeriods": 2,
  "Threshold": 10,
  "ComparisonOperator": "GreaterThanThreshold",
  "AlarmActions": ["arn:aws:sns:REGION:ACCOUNT:alerts"]
}
```

#### 4. Application Monitoring

**Using MonitoringService** (implemented in task 8.2):

```dart
// Initialize monitoring
final monitoringService = MonitoringService();
await monitoringService.initialize();

// Start monitoring
await monitoringService.startMonitoring();

// Configure alert callbacks
monitoringService.setAlertCallback((alert) {
  // Send to logging service
  // Send to analytics
  // Notify team if critical
});
```

**Dashboard Integration**:
```dart
// Display monitoring dashboard in app
MonitoringDashboardWidget(
  showAlerts: true,
  refreshInterval: Duration(seconds: 30),
)
```

### Alert Notification Channels

1. **Email**: Critical alerts to team email
2. **SMS**: Critical production issues
3. **Slack**: All alerts to monitoring channel
4. **PagerDuty**: Critical issues requiring immediate response

### Monitoring Dashboard

**Recommended Tools**:
- **CloudWatch Dashboard**: AWS-native monitoring
- **Grafana**: Advanced visualization
- **DataDog**: Comprehensive APM
- **New Relic**: Application performance monitoring

**Key Dashboard Panels**:
1. Migration success rate (last 24 hours)
2. File operation success rates
3. Average migration duration
4. Error rate trends
5. Active users count
6. Storage usage trends

---

## Rollback Procedures

### Rollback Scenarios

#### Scenario 1: High Migration Failure Rate

**Trigger**: Migration failure rate >10%

**Procedure**:
1. Disable automatic migration in AuthProvider
2. Deploy hotfix to production
3. Investigate root cause
4. Fix issues
5. Re-enable migration
6. Monitor closely

**Code Change**:
```dart
// In auth_provider.dart, comment out migration call
// await _checkAndPerformFileMigration();
```

#### Scenario 2: File Access Issues

**Trigger**: Users unable to access files

**Procedure**:
1. Verify S3 bucket permissions
2. Check Cognito User Pool configuration
3. Verify network connectivity
4. Check for AWS service outages
5. Enable fallback mechanism if needed

**Fallback Mechanism**:
The PersistentFileService has built-in fallback to legacy paths:
```dart
// Fallback automatically used if User Pool sub path fails
await persistentFileService.downloadFileWithFallback(s3Key, syncId);
```

#### Scenario 3: Authentication Issues

**Trigger**: Users unable to authenticate

**Procedure**:
1. Check Cognito User Pool status
2. Verify Amplify configuration
3. Check IAM policies
4. Review authentication logs
5. Rollback to previous app version if needed

#### Scenario 4: Performance Degradation

**Trigger**: File operations taking >30s

**Procedure**:
1. Check S3 service status
2. Verify network connectivity
3. Review CloudWatch metrics
4. Optimize retry logic if needed
5. Scale infrastructure if needed

### Rollback Commands

#### App Rollback

**Android**:
```bash
# Rollback to previous version in Play Store
# 1. Go to Google Play Console
# 2. Select app
# 3. Go to "Release" > "Production"
# 4. Click "Rollback" on current release
```

**iOS**:
```bash
# Rollback to previous version in App Store Connect
# 1. Go to App Store Connect
# 2. Select app
# 3. Go to "App Store" tab
# 4. Select previous version
# 5. Submit for review
```

#### Backend Rollback

**If Amplify changes were made**:
```bash
# Revert Amplify changes
cd household_docs_app
git checkout HEAD~1 amplify/

# Push reverted configuration
amplify push

# Verify rollback
amplify status
```

### Individual User Rollback

If specific users experience issues:

```dart
// Rollback migration for specific user
final persistentFileService = PersistentFileService();
await persistentFileService.rollbackMigration();

// Or rollback specific sync ID
await persistentFileService.rollbackMigrationForSyncId(syncId);
```

### Emergency Rollback Plan

**If critical issues occur**:

1. **Immediate Actions** (0-15 minutes):
   - Disable automatic migration
   - Deploy hotfix
   - Notify team
   - Start incident response

2. **Investigation** (15-60 minutes):
   - Review logs
   - Identify root cause
   - Assess impact
   - Determine fix

3. **Resolution** (1-4 hours):
   - Implement fix
   - Test thoroughly
   - Deploy fix
   - Verify resolution

4. **Post-Incident** (1-2 days):
   - Write incident report
   - Update documentation
   - Improve monitoring
   - Prevent recurrence

---

## Post-Deployment Validation

### Validation Checklist

#### Day 1: Initial Validation

- [ ] Monitor migration success rate (target: >99%)
- [ ] Check for authentication errors
- [ ] Verify file operations working
- [ ] Review error logs
- [ ] Check performance metrics
- [ ] Validate monitoring alerts
- [ ] Test rollback procedures

#### Week 1: Short-term Validation

- [ ] Migration success rate stable
- [ ] No increase in error rates
- [ ] Performance within targets
- [ ] User feedback positive
- [ ] No critical issues reported
- [ ] Monitoring data complete
- [ ] Documentation updated

#### Month 1: Long-term Validation

- [ ] All users migrated successfully
- [ ] Legacy path usage minimal (<1%)
- [ ] System performance optimal
- [ ] No recurring issues
- [ ] Monitoring refined
- [ ] Lessons learned documented
- [ ] Plan legacy cleanup

### Validation Tests

#### Test 1: New User Flow

1. Create new user account
2. Login
3. Upload file
4. Verify file uses User Pool sub path
5. Download file
6. Delete file
7. Verify all operations successful

**Expected Results**:
- File path: `private/{userPoolSub}/documents/{syncId}/{fileName}`
- All operations complete within performance targets
- No errors in logs

#### Test 2: Existing User Migration

1. Login with existing user (has legacy files)
2. Observe migration logs
3. Verify all files accessible
4. Check S3 for new paths
5. Upload new file
6. Verify new file uses User Pool sub path

**Expected Results**:
- Migration completes successfully
- All files accessible
- New files use User Pool sub paths
- Migration logged correctly

#### Test 3: Cross-Device Access

1. Login on Device A
2. Upload file
3. Login on Device B (same account)
4. Verify file appears
5. Download file
6. Verify content matches

**Expected Results**:
- File syncs within 30 seconds
- Content identical on both devices
- Both devices use same User Pool sub

#### Test 4: Offline/Online Behavior

1. Login and cache files
2. Enable airplane mode
3. View cached files (should work)
4. Attempt upload (should queue)
5. Disable airplane mode
6. Verify queued operations execute

**Expected Results**:
- Cached files accessible offline
- Operations queue correctly
- Operations execute on reconnection
- No data loss

### Performance Validation

| Operation | Target | Actual | Status |
|-----------|--------|--------|--------|
| Migration (10 files) | <10s | ___ | ___ |
| Upload (1MB) | <10s | ___ | ___ |
| Download (1MB) | <5s | ___ | ___ |
| Delete | <3s | ___ | ___ |
| User Pool sub retrieval | <100ms | ___ | ___ |

### Success Criteria

**Deployment is successful if**:
- ✅ Migration success rate >99%
- ✅ File operation success rate >99%
- ✅ Performance within targets
- ✅ No critical errors
- ✅ User feedback positive
- ✅ Monitoring working correctly
- ✅ Rollback procedures tested

---

## Troubleshooting

### Issue 1: Migration Not Triggering

**Symptoms**: Users have legacy files but migration doesn't run

**Possible Causes**:
- User not authenticated
- Migration already completed
- No legacy files detected
- Code not deployed correctly

**Solution**:
1. Verify user authentication status
2. Check migration status: `getMigrationStatus()`
3. Verify legacy files exist
4. Check app version deployed
5. Force re-migration if needed: `migrateExistingUser(forceReMigration: true)`

### Issue 2: Migration Fails

**Symptoms**: Migration starts but fails with errors

**Possible Causes**:
- Network connectivity issues
- S3 permissions issues
- Invalid file paths
- Cognito authentication issues

**Solution**:
1. Check network connectivity
2. Verify S3 bucket permissions
3. Check Cognito User Pool status
4. Review error logs for specific errors
5. Verify IAM policies
6. Files remain accessible via fallback

### Issue 3: File Access Denied

**Symptoms**: Users cannot access their files

**Possible Causes**:
- S3 bucket policy incorrect
- Cognito User Pool sub mismatch
- IAM policy issues
- Network issues

**Solution**:
1. Verify S3 bucket policy allows private access
2. Check User Pool sub matches file path
3. Verify IAM policies
4. Check AWS service status
5. Review CloudWatch logs

### Issue 4: Slow Performance

**Symptoms**: File operations taking longer than expected

**Possible Causes**:
- Network latency
- S3 throttling
- Large file sizes
- Concurrent operations

**Solution**:
1. Check network connectivity
2. Review S3 request rates
3. Optimize file sizes
4. Implement request throttling
5. Scale infrastructure if needed

### Issue 5: Authentication Errors

**Symptoms**: Users cannot authenticate

**Possible Causes**:
- Cognito User Pool issues
- Amplify configuration issues
- Network issues
- Invalid credentials

**Solution**:
1. Check Cognito User Pool status
2. Verify Amplify configuration
3. Check network connectivity
4. Review authentication logs
5. Verify user credentials

### Common Error Messages

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "User must be authenticated" | User not logged in | Ensure user authenticates before file operations |
| "User Pool sub cannot be retrieved" | Cognito issue | Check Cognito User Pool configuration |
| "S3 key does not belong to current user" | Path ownership mismatch | Verify User Pool sub matches file path |
| "Network error" | Connectivity issue | Check network, retry operation |
| "Migration failed" | Various | Check logs for specific error, retry migration |

### Support Contacts

**For deployment issues**:
- Development Team: dev-team@example.com
- DevOps Team: devops@example.com
- AWS Support: support.aws.amazon.com

**For user issues**:
- Support Team: support@example.com
- Help Desk: helpdesk@example.com

---

## Conclusion

This deployment guide provides comprehensive instructions for deploying the persistent file access system. Key points:

1. **No S3 configuration changes required** - Amplify handles private access automatically
2. **No Amplify backend changes required** - Existing configuration supports User Pool sub
3. **Phased rollout recommended** - Gradual deployment with monitoring
4. **Comprehensive monitoring** - Track migration and file operation metrics
5. **Rollback procedures ready** - Multiple rollback options available
6. **Validation tests defined** - Clear success criteria

The system is designed to be deployed with minimal infrastructure changes, relying on existing Amplify configuration and AWS services. The focus is on application-level deployment with comprehensive monitoring and rollback capabilities.

**Deployment Status**: ✅ Ready for deployment

**Next Steps**:
1. Review this guide with team
2. Complete pre-deployment checklist
3. Deploy to internal test environment
4. Proceed with phased rollout
5. Monitor metrics closely
6. Document lessons learned

For questions or issues during deployment, refer to the troubleshooting section or contact the development team.

---

**Document Version**: 1.0  
**Last Updated**: January 2026  
**Author**: Development Team  
**Review Date**: Post-deployment + 30 days
