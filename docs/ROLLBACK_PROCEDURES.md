# Rollback Procedures

## Overview

This document provides comprehensive rollback procedures for the Household Docs App cloud synchronization implementation. It covers various rollback scenarios, from simple application updates to complete infrastructure rollbacks.

## Rollback Decision Matrix

| Issue Severity | Rollback Type | Timeline | Approval Required |
|---------------|---------------|----------|-------------------|
| Critical (Service Down) | Emergency | Immediate | Post-action |
| High (Data Loss Risk) | Full Application | 15 minutes | Team Lead |
| Medium (Feature Issues) | Partial Feature | 30 minutes | Product Owner |
| Low (Minor Bugs) | Configuration | 1 hour | Developer |

## Pre-Rollback Checklist

### 1. Assessment Phase

- [ ] Identify the scope of the issue
- [ ] Determine affected users/features
- [ ] Assess data integrity risks
- [ ] Check if issue can be hotfixed
- [ ] Verify rollback target version
- [ ] Notify stakeholders

### 2. Preparation Phase

- [ ] Backup current state
- [ ] Prepare rollback commands
- [ ] Identify rollback dependencies
- [ ] Prepare communication plan
- [ ] Set up monitoring for rollback

## Rollback Types

### 1. Emergency Rollback (Critical Issues)

**Triggers:**
- Complete service outage
- Data corruption detected
- Security breach
- Authentication system failure

**Procedure:**

```bash
#!/bin/bash
# emergency-rollback.sh

set -e

echo "=== EMERGENCY ROLLBACK INITIATED ==="
echo "Timestamp: $(date)"
echo "Initiated by: $USER"

# 1. Immediate notification
curl -X POST \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"🚨 EMERGENCY ROLLBACK INITIATED for HouseholdDocs at $(date)\"}" \
  $SLACK_EMERGENCY_WEBHOOK

# 2. Switch to last known good environment
echo "Switching to stable environment..."
amplify env checkout prod-stable

# 3. Deploy stable version
echo "Deploying stable version..."
amplify push --yes

# 4. Verify rollback success
echo "Verifying rollback..."
./scripts/verify-deployment.sh

# 5. Update DNS if needed
if [ "$UPDATE_DNS" = "true" ]; then
  echo "Updating DNS to stable endpoint..."
  aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file://dns-rollback.json
fi

# 6. Final notification
curl -X POST \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"✅ Emergency rollback completed at $(date). Service restored.\"}" \
  $SLACK_EMERGENCY_WEBHOOK

echo "=== EMERGENCY ROLLBACK COMPLETED ==="
```

**Verification Steps:**
```bash
# Verify API health
curl -f https://api.householddocs.com/health || echo "API health check failed"

# Test authentication
./scripts/test-auth.sh

# Verify database connectivity
./scripts/test-db-connection.sh

# Check critical user flows
./scripts/test-critical-flows.sh
```

### 2. Application Rollback

**Triggers:**
- New feature causing issues
- Performance degradation
- Non-critical functionality broken

#### 2.1 Flutter Application Rollback

```bash
#!/bin/bash
# app-rollback.sh

ROLLBACK_VERSION=$1
ENVIRONMENT=${2:-prod}

if [ -z "$ROLLBACK_VERSION" ]; then
  echo "Usage: $0 <rollback-version> [environment]"
  exit 1
fi

echo "Rolling back application to version $ROLLBACK_VERSION"

# 1. Checkout rollback version
git checkout $ROLLBACK_VERSION

# 2. Verify version
echo "Current commit: $(git rev-parse HEAD)"
echo "Version info:"
grep version pubspec.yaml

# 3. Build application
flutter clean
flutter pub get
flutter build apk --release

# 4. Deploy to Amplify
amplify env checkout $ENVIRONMENT
amplify push --yes

# 5. Verify deployment
flutter test integration_test/smoke_test.dart

echo "Application rollback completed"
```

#### 2.2 Selective Feature Rollback

```bash
#!/bin/bash
# feature-rollback.sh

FEATURE_NAME=$1

case $FEATURE_NAME in
  "realtime-sync")
    echo "Disabling real-time sync feature..."
    # Update feature flag
    aws ssm put-parameter \
      --name "/householddocs/features/realtime-sync" \
      --value "false" \
      --overwrite
    ;;
  "batch-operations")
    echo "Disabling batch operations feature..."
    aws ssm put-parameter \
      --name "/householddocs/features/batch-operations" \
      --value "false" \
      --overwrite
    ;;
  "offline-queue")
    echo "Disabling offline queue feature..."
    aws ssm put-parameter \
      --name "/householddocs/features/offline-queue" \
      --value "false" \
      --overwrite
    ;;
  *)
    echo "Unknown feature: $FEATURE_NAME"
    exit 1
    ;;
esac

echo "Feature $FEATURE_NAME has been disabled"
```

### 3. Infrastructure Rollback

#### 3.1 Amplify Infrastructure Rollback

```bash
#!/bin/bash
# infrastructure-rollback.sh

ENVIRONMENT=${1:-prod}
BACKUP_TIMESTAMP=$2

echo "Rolling back Amplify infrastructure for environment: $ENVIRONMENT"

# 1. Switch to environment
amplify env checkout $ENVIRONMENT

# 2. Get current stack status
STACK_NAME="amplify-householddocsapp-$ENVIRONMENT"
CURRENT_STATUS=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --query 'Stacks[0].StackStatus' \
  --output text)

echo "Current stack status: $CURRENT_STATUS"

# 3. If stack is in failed state, try to continue update rollback
if [[ "$CURRENT_STATUS" == *"ROLLBACK_FAILED"* ]]; then
  echo "Stack is in failed rollback state, attempting to continue rollback..."
  aws cloudformation continue-update-rollback --stack-name $STACK_NAME
  
  # Wait for rollback to complete
  aws cloudformation wait stack-rollback-complete --stack-name $STACK_NAME
fi

# 4. If backup timestamp provided, restore from backup
if [ -n "$BACKUP_TIMESTAMP" ]; then
  echo "Restoring from backup: $BACKUP_TIMESTAMP"
  ./scripts/restore-from-backup.sh $BACKUP_TIMESTAMP $ENVIRONMENT
fi

# 5. Verify infrastructure
./scripts/verify-infrastructure.sh $ENVIRONMENT

echo "Infrastructure rollback completed"
```

#### 3.2 Database Rollback

```bash
#!/bin/bash
# database-rollback.sh

ENVIRONMENT=$1
BACKUP_ARN=$2

if [ -z "$BACKUP_ARN" ]; then
  echo "Usage: $0 <environment> <backup-arn>"
  exit 1
fi

echo "Rolling back database for environment: $ENVIRONMENT"

# 1. Get table names
DOCUMENT_TABLE=$(aws dynamodb list-tables \
  --query "TableNames[?contains(@, 'Document') && contains(@, '$ENVIRONMENT')]" \
  --output text)

FILEATTACHMENT_TABLE=$(aws dynamodb list-tables \
  --query "TableNames[?contains(@, 'FileAttachment') && contains(@, '$ENVIRONMENT')]" \
  --output text)

echo "Document table: $DOCUMENT_TABLE"
echo "FileAttachment table: $FILEATTACHMENT_TABLE"

# 2. Create backup of current state
echo "Creating backup of current state..."
CURRENT_BACKUP_DOC=$(aws dynamodb create-backup \
  --table-name $DOCUMENT_TABLE \
  --backup-name "rollback-backup-$(date +%Y%m%d-%H%M%S)" \
  --query 'BackupDetails.BackupArn' \
  --output text)

CURRENT_BACKUP_FILE=$(aws dynamodb create-backup \
  --table-name $FILEATTACHMENT_TABLE \
  --backup-name "rollback-backup-$(date +%Y%m%d-%H%M%S)" \
  --query 'BackupDetails.BackupArn' \
  --output text)

echo "Current state backed up:"
echo "  Document table: $CURRENT_BACKUP_DOC"
echo "  FileAttachment table: $CURRENT_BACKUP_FILE"

# 3. Restore from specified backup
echo "Restoring from backup: $BACKUP_ARN"

# Note: DynamoDB restore creates a new table, so we need to:
# a) Restore to new table
# b) Update application to use new table
# c) Delete old table

RESTORE_TABLE_NAME="${DOCUMENT_TABLE}-restored-$(date +%Y%m%d%H%M%S)"

aws dynamodb restore-table-from-backup \
  --target-table-name $RESTORE_TABLE_NAME \
  --backup-arn $BACKUP_ARN

# Wait for restore to complete
aws dynamodb wait table-exists --table-name $RESTORE_TABLE_NAME

echo "Database rollback completed. New table: $RESTORE_TABLE_NAME"
echo "Manual step required: Update application configuration to use restored table"
```

#### 3.3 S3 Rollback

```bash
#!/bin/bash
# s3-rollback.sh

BUCKET_NAME=$1
ROLLBACK_DATE=$2

if [ -z "$ROLLBACK_DATE" ]; then
  echo "Usage: $0 <bucket-name> <rollback-date-YYYY-MM-DD>"
  exit 1
fi

echo "Rolling back S3 bucket $BUCKET_NAME to date: $ROLLBACK_DATE"

# 1. Enable versioning if not already enabled
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# 2. List objects modified after rollback date
aws s3api list-object-versions \
  --bucket $BUCKET_NAME \
  --query "Versions[?LastModified>'$ROLLBACK_DATE'].{Key:Key,VersionId:VersionId}" \
  --output json > /tmp/objects-to-rollback.json

# 3. For each object, restore previous version
while IFS= read -r line; do
  KEY=$(echo $line | jq -r '.Key')
  VERSION_ID=$(echo $line | jq -r '.VersionId')
  
  echo "Rolling back object: $KEY"
  
  # Get previous version
  PREVIOUS_VERSION=$(aws s3api list-object-versions \
    --bucket $BUCKET_NAME \
    --prefix $KEY \
    --query "Versions[?LastModified<'$ROLLBACK_DATE'] | [0].VersionId" \
    --output text)
  
  if [ "$PREVIOUS_VERSION" != "None" ]; then
    # Copy previous version as current
    aws s3api copy-object \
      --bucket $BUCKET_NAME \
      --copy-source "$BUCKET_NAME/$KEY?versionId=$PREVIOUS_VERSION" \
      --key $KEY
  fi
  
done < <(jq -c '.[]' /tmp/objects-to-rollback.json)

echo "S3 rollback completed"
```

### 4. Configuration Rollback

#### 4.1 Feature Flag Rollback

```bash
#!/bin/bash
# feature-flag-rollback.sh

ROLLBACK_CONFIG_FILE=$1

if [ ! -f "$ROLLBACK_CONFIG_FILE" ]; then
  echo "Rollback configuration file not found: $ROLLBACK_CONFIG_FILE"
  exit 1
fi

echo "Rolling back feature flags from: $ROLLBACK_CONFIG_FILE"

# Read rollback configuration
while IFS='=' read -r key value; do
  if [[ $key && $value ]]; then
    echo "Setting $key = $value"
    aws ssm put-parameter \
      --name "/householddocs/features/$key" \
      --value "$value" \
      --overwrite
  fi
done < "$ROLLBACK_CONFIG_FILE"

echo "Feature flag rollback completed"
```

**Example rollback configuration file:**
```
# feature-rollback-config.txt
realtime-sync=false
batch-operations=false
offline-queue=true
conflict-resolution=true
performance-monitoring=false
```

#### 4.2 Environment Variable Rollback

```bash
#!/bin/bash
# env-var-rollback.sh

ENVIRONMENT=$1
BACKUP_FILE=$2

if [ ! -f "$BACKUP_FILE" ]; then
  echo "Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "Rolling back environment variables for: $ENVIRONMENT"

# Restore environment variables from backup
while IFS='=' read -r key value; do
  if [[ $key && $value ]]; then
    echo "Restoring $key"
    aws ssm put-parameter \
      --name "/householddocs/$ENVIRONMENT/$key" \
      --value "$value" \
      --overwrite
  fi
done < "$BACKUP_FILE"

# Restart services to pick up new configuration
./scripts/restart-services.sh $ENVIRONMENT

echo "Environment variable rollback completed"
```

## Rollback Verification

### 1. Automated Verification

```bash
#!/bin/bash
# verify-rollback.sh

ENVIRONMENT=${1:-prod}

echo "Verifying rollback for environment: $ENVIRONMENT"

# 1. Health checks
echo "Running health checks..."
./scripts/health-check.sh $ENVIRONMENT

# 2. Smoke tests
echo "Running smoke tests..."
flutter test integration_test/smoke_test.dart

# 3. Critical path tests
echo "Testing critical paths..."
./scripts/test-critical-paths.sh

# 4. Performance baseline
echo "Checking performance baseline..."
./scripts/performance-check.sh

# 5. Data integrity check
echo "Verifying data integrity..."
./scripts/data-integrity-check.sh

echo "Rollback verification completed"
```

### 2. Manual Verification Checklist

**Functional Verification:**
- [ ] User authentication works
- [ ] Document creation/editing works
- [ ] File upload/download works
- [ ] Sync operations complete successfully
- [ ] Real-time updates are received
- [ ] Offline mode functions correctly

**Performance Verification:**
- [ ] API response times are acceptable
- [ ] File upload/download speeds are normal
- [ ] Memory usage is within limits
- [ ] No memory leaks detected

**Data Verification:**
- [ ] No data loss occurred
- [ ] Data consistency is maintained
- [ ] User permissions are correct
- [ ] File integrity is preserved

## Post-Rollback Procedures

### 1. Immediate Actions

```bash
#!/bin/bash
# post-rollback-actions.sh

ROLLBACK_TYPE=$1
ROLLBACK_REASON=$2

echo "Executing post-rollback actions for: $ROLLBACK_TYPE"

# 1. Update status page
curl -X POST \
  -H "Authorization: Bearer $STATUS_PAGE_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"status\": \"operational\",
    \"message\": \"Service restored after rollback. Issue: $ROLLBACK_REASON\"
  }" \
  https://api.statuspage.io/v1/pages/$PAGE_ID/incidents

# 2. Notify stakeholders
./scripts/notify-stakeholders.sh "rollback-completed" "$ROLLBACK_REASON"

# 3. Create incident report
./scripts/create-incident-report.sh "$ROLLBACK_TYPE" "$ROLLBACK_REASON"

# 4. Schedule post-mortem
./scripts/schedule-postmortem.sh

echo "Post-rollback actions completed"
```

### 2. Monitoring and Alerting

```bash
#!/bin/bash
# setup-post-rollback-monitoring.sh

echo "Setting up enhanced monitoring after rollback..."

# 1. Increase monitoring frequency
aws cloudwatch put-metric-alarm \
  --alarm-name "Post-Rollback-API-Errors" \
  --alarm-description "Enhanced monitoring after rollback" \
  --metric-name "4XXError" \
  --namespace "AWS/AppSync" \
  --statistic "Sum" \
  --period 60 \
  --threshold 5 \
  --comparison-operator "GreaterThanThreshold" \
  --evaluation-periods 1

# 2. Set up temporary alerts
aws sns publish \
  --topic-arn $ALERT_TOPIC_ARN \
  --message "Enhanced monitoring enabled after rollback. Will auto-disable in 24 hours."

# 3. Schedule monitoring reset
echo "aws cloudwatch delete-alarms --alarm-names Post-Rollback-API-Errors" | at now + 24 hours

echo "Enhanced monitoring configured"
```

### 3. Documentation and Learning

```bash
#!/bin/bash
# document-rollback.sh

ROLLBACK_ID=$1
ROLLBACK_TYPE=$2
ROLLBACK_REASON=$3

# Create rollback documentation
cat > "rollback-report-$ROLLBACK_ID.md" << EOF
# Rollback Report: $ROLLBACK_ID

## Summary
- **Date**: $(date)
- **Type**: $ROLLBACK_TYPE
- **Reason**: $ROLLBACK_REASON
- **Duration**: [TO BE FILLED]
- **Impact**: [TO BE FILLED]

## Timeline
- **Issue Detected**: [TO BE FILLED]
- **Rollback Initiated**: [TO BE FILLED]
- **Rollback Completed**: [TO BE FILLED]
- **Service Restored**: [TO BE FILLED]

## Root Cause
[TO BE FILLED]

## Actions Taken
[TO BE FILLED]

## Lessons Learned
[TO BE FILLED]

## Prevention Measures
[TO BE FILLED]
EOF

echo "Rollback documentation created: rollback-report-$ROLLBACK_ID.md"
```

## Rollback Testing

### 1. Regular Rollback Drills

```bash
#!/bin/bash
# rollback-drill.sh

DRILL_TYPE=${1:-application}

echo "Starting rollback drill: $DRILL_TYPE"

# 1. Switch to test environment
amplify env checkout test

# 2. Deploy current version
amplify push --yes

# 3. Simulate issue
case $DRILL_TYPE in
  "application")
    ./scripts/simulate-app-issue.sh
    ;;
  "database")
    ./scripts/simulate-db-issue.sh
    ;;
  "infrastructure")
    ./scripts/simulate-infra-issue.sh
    ;;
esac

# 4. Execute rollback
./scripts/execute-rollback.sh $DRILL_TYPE test

# 5. Verify rollback
./scripts/verify-rollback.sh test

# 6. Document results
./scripts/document-drill-results.sh $DRILL_TYPE

echo "Rollback drill completed"
```

### 2. Automated Rollback Testing

```yaml
# .github/workflows/rollback-test.yml
name: Rollback Testing

on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday at 2 AM
  workflow_dispatch:

jobs:
  test-rollback:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      
      - name: Setup Amplify CLI
        run: npm install -g @aws-amplify/cli
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Run rollback drill
        run: ./scripts/rollback-drill.sh application
      
      - name: Upload drill results
        uses: actions/upload-artifact@v3
        with:
          name: rollback-drill-results
          path: rollback-drill-*.md
```

## Emergency Contacts and Escalation

### 1. Contact Information

```bash
# emergency-contacts.sh

EMERGENCY_CONTACTS=(
  "primary:john.doe@company.com:+1234567890"
  "secondary:jane.smith@company.com:+1234567891"
  "infrastructure:devops@company.com:+1234567892"
  "security:security@company.com:+1234567893"
)

notify_emergency_contacts() {
  local message=$1
  
  for contact in "${EMERGENCY_CONTACTS[@]}"; do
    IFS=':' read -r role email phone <<< "$contact"
    
    # Send email
    echo "$message" | mail -s "EMERGENCY: HouseholdDocs Rollback" "$email"
    
    # Send SMS (using AWS SNS)
    aws sns publish \
      --phone-number "$phone" \
      --message "EMERGENCY: HouseholdDocs rollback initiated. Check email for details."
  done
}
```

### 2. Escalation Matrix

| Time Since Issue | Action | Responsible |
|------------------|--------|-------------|
| 0-5 minutes | Initial assessment | On-call engineer |
| 5-15 minutes | Rollback decision | Team lead |
| 15-30 minutes | Execute rollback | DevOps team |
| 30+ minutes | Escalate to management | Engineering manager |

This comprehensive rollback procedures document ensures that any issues with the cloud sync implementation can be quickly and safely resolved with minimal impact to users.