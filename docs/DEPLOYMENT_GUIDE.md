# Cloud Sync Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying the Household Docs App cloud synchronization implementation to AWS using Amplify. It covers the complete setup from initial configuration to production deployment.

## Prerequisites

### Required Tools

1. **AWS CLI** (version 2.0 or later)
   ```bash
   # Install AWS CLI
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   
   # Verify installation
   aws --version
   ```

2. **Amplify CLI** (version 12.0 or later)
   ```bash
   # Install Amplify CLI
   npm install -g @aws-amplify/cli
   
   # Verify installation
   amplify --version
   ```

3. **Flutter SDK** (version 3.16 or later)
   ```bash
   # Verify Flutter installation
   flutter --version
   flutter doctor
   ```

4. **Node.js** (version 18 or later)
   ```bash
   # Verify Node.js installation
   node --version
   npm --version
   ```

### AWS Account Setup

1. **Create AWS Account** (if not already done)
   - Go to https://aws.amazon.com/
   - Create a new account or sign in to existing account

2. **Configure AWS CLI**
   ```bash
   aws configure
   # Enter your AWS Access Key ID
   # Enter your AWS Secret Access Key
   # Enter your default region (e.g., us-east-1)
   # Enter output format (json)
   ```

3. **Verify AWS Configuration**
   ```bash
   aws sts get-caller-identity
   ```

## Initial Amplify Setup

### 1. Initialize Amplify Project

```bash
# Navigate to project directory
cd household_docs_app

# Initialize Amplify (if not already done)
amplify init

# Follow the prompts:
# ? Enter a name for the project: householddocsapp
# ? Initialize the project with the above configuration? Yes
# ? Select the authentication method you want to use: AWS profile
# ? Please choose the profile you want to use: default
```

### 2. Configure Amplify Categories

#### Authentication (Cognito)

```bash
# Add authentication
amplify add auth

# Configuration options:
# ? Do you want to use the default authentication and security configuration? Default configuration
# ? How do you want users to be able to sign in? Username
# ? Do you want to configure advanced settings? No, I am done.
```

#### API (GraphQL)

```bash
# Add GraphQL API
amplify add api

# Configuration options:
# ? Select from one of the below mentioned services: GraphQL
# ? Here is the GraphQL API that we will create. Select a setting to edit or continue: Continue
# ? Choose a schema template: Single object with fields (e.g., "Todo" with ID, name, description)
# ? Do you want to edit the schema now? Yes
```

Replace the generated schema with the project schema:

```bash
# Copy the project schema
cp amplify/backend/api/householddocsapp/schema.graphql amplify/backend/api/householddocsapp/schema.graphql.backup
cp schema.graphql amplify/backend/api/householddocsapp/schema.graphql
```

#### Storage (S3)

```bash
# Add S3 storage
amplify add storage

# Configuration options:
# ? Select from one of the below mentioned services: Content (Images, audio, video, etc.)
# ? Provide a friendly name for your resource that will be used to label this category in the project: fileAttachments
# ? Provide bucket name: householddocsapp-fileattachments
# ? Who should have access: Auth users only
# ? What kind of access do you want for Authenticated users? create/update, read, delete
```

### 3. Deploy Initial Infrastructure

```bash
# Deploy all resources
amplify push

# Configuration confirmation:
# ? Are you sure you want to continue? Yes
# ? Do you want to generate code for your newly created GraphQL API? Yes
# ? Choose the code generation language target: dart
# ? Enter the file name pattern of graphql queries, mutations and subscriptions: lib/models/**/*.dart
# ? Do you want to generate/update all possible GraphQL operations? Yes
# ? Enter maximum statement depth: 2
```

## Environment Configuration

### 1. Development Environment

```bash
# Add development environment
amplify env add dev

# Configuration:
# ? Enter a name for the environment: dev
# ? Select the authentication method you want to use: AWS profile
# ? Please choose the profile you want to use: default
```

### 2. Staging Environment

```bash
# Add staging environment
amplify env add staging

# Configuration:
# ? Enter a name for the environment: staging
# ? Select the authentication method you want to use: AWS profile
# ? Please choose the profile you want to use: default
```

### 3. Production Environment

```bash
# Add production environment
amplify env add prod

# Configuration:
# ? Enter a name for the environment: prod
# ? Select the authentication method you want to use: AWS profile
# ? Please choose the profile you want to use: default
```

### 4. Environment-Specific Configuration

Create environment-specific configuration files:

**amplify/team-provider-info.json**
```json
{
  "dev": {
    "awscloudformation": {
      "AuthRoleName": "amplify-householddocsapp-dev-authRole",
      "UnauthRoleName": "amplify-householddocsapp-dev-unauthRole",
      "AuthRoleArn": "arn:aws:iam::ACCOUNT:role/amplify-householddocsapp-dev-authRole",
      "UnauthRoleArn": "arn:aws:iam::ACCOUNT:role/amplify-householddocsapp-dev-unauthRole",
      "Region": "us-east-1",
      "DeploymentBucketName": "amplify-householddocsapp-dev-deployment",
      "StackName": "amplify-householddocsapp-dev",
      "StackId": "arn:aws:cloudformation:us-east-1:ACCOUNT:stack/amplify-householddocsapp-dev"
    }
  },
  "staging": {
    "awscloudformation": {
      "AuthRoleName": "amplify-householddocsapp-staging-authRole",
      "UnauthRoleName": "amplify-householddocsapp-staging-unauthRole",
      "Region": "us-east-1"
    }
  },
  "prod": {
    "awscloudformation": {
      "AuthRoleName": "amplify-householddocsapp-prod-authRole",
      "UnauthRoleName": "amplify-householddocsapp-prod-unauthRole",
      "Region": "us-east-1"
    }
  }
}
```

## AWS Service Configuration

### 1. DynamoDB Configuration

#### Table Settings

```bash
# Configure DynamoDB tables for production
aws dynamodb update-table \
  --table-name Document-XXXXX-prod \
  --provisioned-throughput ReadCapacityUnits=10,WriteCapacityUnits=10

aws dynamodb update-table \
  --table-name FileAttachment-XXXXX-prod \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

#### Auto Scaling Configuration

```bash
# Enable auto scaling for Document table
aws application-autoscaling register-scalable-target \
  --service-namespace dynamodb \
  --resource-id table/Document-XXXXX-prod \
  --scalable-dimension dynamodb:table:ReadCapacityUnits \
  --min-capacity 5 \
  --max-capacity 100

aws application-autoscaling register-scalable-target \
  --service-namespace dynamodb \
  --resource-id table/Document-XXXXX-prod \
  --scalable-dimension dynamodb:table:WriteCapacityUnits \
  --min-capacity 5 \
  --max-capacity 100

# Create scaling policies
aws application-autoscaling put-scaling-policy \
  --service-namespace dynamodb \
  --resource-id table/Document-XXXXX-prod \
  --scalable-dimension dynamodb:table:ReadCapacityUnits \
  --policy-name DocumentTableReadScalingPolicy \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "DynamoDBReadCapacityUtilization"
    }
  }'
```

#### Backup Configuration

```bash
# Enable point-in-time recovery
aws dynamodb update-continuous-backups \
  --table-name Document-XXXXX-prod \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true

aws dynamodb update-continuous-backups \
  --table-name FileAttachment-XXXXX-prod \
  --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true
```

### 2. S3 Configuration

#### Bucket Policy

Create a bucket policy for the S3 storage:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAuthenticatedUsers",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT:role/amplify-householddocsapp-prod-authRole"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::householddocsapp-fileattachments-prod/private/${cognito-identity.amazonaws.com:sub}/*"
    }
  ]
}
```

#### Lifecycle Configuration

```bash
# Configure S3 lifecycle rules
aws s3api put-bucket-lifecycle-configuration \
  --bucket householddocsapp-fileattachments-prod \
  --lifecycle-configuration '{
    "Rules": [
      {
        "ID": "DeleteIncompleteMultipartUploads",
        "Status": "Enabled",
        "AbortIncompleteMultipartUpload": {
          "DaysAfterInitiation": 7
        }
      },
      {
        "ID": "TransitionToIA",
        "Status": "Enabled",
        "Transitions": [
          {
            "Days": 30,
            "StorageClass": "STANDARD_IA"
          },
          {
            "Days": 90,
            "StorageClass": "GLACIER"
          }
        ]
      }
    ]
  }'
```

#### CORS Configuration

```bash
# Configure CORS for S3 bucket
aws s3api put-bucket-cors \
  --bucket householddocsapp-fileattachments-prod \
  --cors-configuration '{
    "CORSRules": [
      {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
        "AllowedOrigins": ["*"],
        "ExposeHeaders": ["ETag"],
        "MaxAgeSeconds": 3000
      }
    ]
  }'
```

### 3. Cognito Configuration

#### User Pool Settings

```bash
# Update user pool configuration
aws cognito-idp update-user-pool \
  --user-pool-id us-east-1_XXXXXXXXX \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": false
    }
  }' \
  --auto-verified-attributes email \
  --mfa-configuration OPTIONAL \
  --device-configuration '{
    "ChallengeRequiredOnNewDevice": false,
    "DeviceOnlyRememberedOnUserPrompt": true
  }'
```

#### Identity Pool Configuration

```bash
# Update identity pool
aws cognito-identity update-identity-pool \
  --identity-pool-id us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx \
  --identity-pool-name householddocsapp_identitypool_prod \
  --allow-unauthenticated-identities false
```

### 4. AppSync Configuration

#### API Settings

```bash
# Update GraphQL API settings
aws appsync update-graphql-api \
  --api-id XXXXXXXXXXXXXXXXXXXXXXXXXX \
  --name householddocsapp-prod \
  --log-config '{
    "fieldLogLevel": "ERROR",
    "cloudWatchLogsRoleArn": "arn:aws:iam::ACCOUNT:role/service-role/appsync-logs-role"
  }' \
  --additional-authentication-providers '[
    {
      "authenticationType": "AWS_IAM"
    }
  ]'
```

## Application Configuration

### 1. Flutter Dependencies

Ensure all required dependencies are in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  amplify_flutter: ^2.0.0
  amplify_auth_cognito: ^2.0.0
  amplify_api: ^2.0.0
  amplify_storage_s3: ^2.0.0
  amplify_datastore: ^2.0.0
  connectivity_plus: ^5.0.0
  shared_preferences: ^2.2.0
  path_provider: ^2.1.0
  crypto: ^3.0.3
```

### 2. Amplify Configuration

Update `lib/amplifyconfiguration.dart` with environment-specific settings:

```dart
const amplifyconfig = '''{
  "UserAgent": "aws-amplify-cli/2.0",
  "Version": "1.0",
  "api": {
    "plugins": {
      "awsAPIPlugin": {
        "householddocsapp": {
          "endpointType": "GraphQL",
          "endpoint": "https://XXXXXXXXXXXXXXXXXXXXXXXXXX.appsync-api.us-east-1.amazonaws.com/graphql",
          "region": "us-east-1",
          "authorizationType": "AMAZON_COGNITO_USER_POOLS"
        }
      }
    }
  },
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserAgent": "aws-amplify-cli/0.1.0",
        "Version": "0.1.0",
        "IdentityManager": {
          "Default": {}
        },
        "CredentialsProvider": {
          "CognitoIdentity": {
            "Default": {
              "PoolId": "us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
              "Region": "us-east-1"
            }
          }
        },
        "CognitoUserPool": {
          "Default": {
            "PoolId": "us-east-1_XXXXXXXXX",
            "AppClientId": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
            "Region": "us-east-1"
          }
        }
      }
    }
  },
  "storage": {
    "plugins": {
      "awsS3StoragePlugin": {
        "bucket": "householddocsapp-fileattachments-XXXXX",
        "region": "us-east-1",
        "defaultAccessLevel": "guest"
      }
    }
  }
}''';
```

### 3. Environment-Specific Configuration

Create configuration files for different environments:

**lib/config/environment_config.dart**
```dart
enum Environment { dev, staging, prod }

class EnvironmentConfig {
  static Environment _currentEnvironment = Environment.prod;
  
  static Environment get currentEnvironment => _currentEnvironment;
  
  static void setEnvironment(Environment env) {
    _currentEnvironment = env;
  }
  
  static String get apiEndpoint {
    switch (_currentEnvironment) {
      case Environment.dev:
        return 'https://dev-api.householddocs.com';
      case Environment.staging:
        return 'https://staging-api.householddocs.com';
      case Environment.prod:
        return 'https://api.householddocs.com';
    }
  }
  
  static bool get enableDebugLogging {
    return _currentEnvironment != Environment.prod;
  }
  
  static int get syncRetryAttempts {
    switch (_currentEnvironment) {
      case Environment.dev:
        return 3;
      case Environment.staging:
        return 5;
      case Environment.prod:
        return 5;
    }
  }
}
```

## Deployment Process

### 1. Pre-Deployment Checklist

- [ ] All tests pass (`flutter test`)
- [ ] Code analysis passes (`flutter analyze`)
- [ ] Dependencies are up to date
- [ ] Environment configuration is correct
- [ ] AWS credentials are configured
- [ ] Amplify CLI is authenticated

### 2. Development Deployment

```bash
# Switch to development environment
amplify env checkout dev

# Deploy changes
amplify push

# Verify deployment
amplify status
```

### 3. Staging Deployment

```bash
# Switch to staging environment
amplify env checkout staging

# Deploy changes
amplify push

# Run integration tests
flutter test integration_test/

# Verify deployment
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $STAGING_TOKEN" \
  -d '{"query": "query { listDocuments { items { id title } } }"}' \
  https://staging-api.householddocs.com/graphql
```

### 4. Production Deployment

```bash
# Switch to production environment
amplify env checkout prod

# Final verification
flutter test
flutter analyze
flutter build apk --release

# Deploy to production
amplify push

# Verify deployment
amplify status

# Test critical paths
flutter test integration_test/critical_path_test.dart
```

### 5. Post-Deployment Verification

```bash
# Check API health
curl https://api.householddocs.com/health

# Verify GraphQL endpoint
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"query": "query { __schema { types { name } } }"}' \
  https://XXXXXXXXXXXXXXXXXXXXXXXXXX.appsync-api.us-east-1.amazonaws.com/graphql

# Check S3 bucket access
aws s3 ls s3://householddocsapp-fileattachments-prod/

# Verify DynamoDB tables
aws dynamodb describe-table --table-name Document-XXXXX-prod
aws dynamodb describe-table --table-name FileAttachment-XXXXX-prod
```

## Monitoring Setup

### 1. CloudWatch Alarms

```bash
# Create API error rate alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "HouseholdDocs-API-ErrorRate" \
  --alarm-description "API error rate too high" \
  --metric-name "4XXError" \
  --namespace "AWS/AppSync" \
  --statistic "Sum" \
  --period 300 \
  --threshold 10 \
  --comparison-operator "GreaterThanThreshold" \
  --evaluation-periods 2 \
  --alarm-actions "arn:aws:sns:us-east-1:ACCOUNT:householddocs-alerts"

# Create DynamoDB throttling alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "HouseholdDocs-DynamoDB-Throttling" \
  --alarm-description "DynamoDB throttling detected" \
  --metric-name "ThrottledRequests" \
  --namespace "AWS/DynamoDB" \
  --statistic "Sum" \
  --period 300 \
  --threshold 1 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --evaluation-periods 1 \
  --dimensions "Name=TableName,Value=Document-XXXXX-prod"
```

### 2. Custom Metrics

```dart
// Application-level metrics
class DeploymentMetrics {
  static Future<void> recordSyncOperation(
    String operation,
    bool success,
    Duration duration,
  ) async {
    final metric = {
      'MetricName': 'SyncOperation',
      'Dimensions': [
        {'Name': 'Operation', 'Value': operation},
        {'Name': 'Success', 'Value': success.toString()},
      ],
      'Value': duration.inMilliseconds.toDouble(),
      'Unit': 'Milliseconds',
      'Timestamp': DateTime.now().toIso8601String(),
    };
    
    // Send to CloudWatch
    await _sendMetricToCloudWatch(metric);
  }
}
```

### 3. Log Aggregation

```bash
# Create CloudWatch log groups
aws logs create-log-group --log-group-name /aws/appsync/apis/XXXXXXXXXXXXXXXXXXXXXXXXXX
aws logs create-log-group --log-group-name /aws/lambda/householddocs-sync-processor

# Set retention policy
aws logs put-retention-policy \
  --log-group-name /aws/appsync/apis/XXXXXXXXXXXXXXXXXXXXXXXXXX \
  --retention-in-days 30
```

## Security Configuration

### 1. IAM Roles and Policies

**Authenticated User Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "appsync:GraphQL"
      ],
      "Resource": "arn:aws:appsync:us-east-1:ACCOUNT:apis/XXXXXXXXXXXXXXXXXXXXXXXXXX/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::householddocsapp-fileattachments-prod/private/${cognito-identity.amazonaws.com:sub}/*"
    }
  ]
}
```

### 2. API Security

```bash
# Enable WAF for AppSync
aws wafv2 create-web-acl \
  --name householddocs-api-protection \
  --scope CLOUDFRONT \
  --default-action Allow={} \
  --rules '[
    {
      "Name": "RateLimitRule",
      "Priority": 1,
      "Statement": {
        "RateBasedStatement": {
          "Limit": 2000,
          "AggregateKeyType": "IP"
        }
      },
      "Action": {
        "Block": {}
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "RateLimitRule"
      }
    }
  ]'
```

### 3. Data Encryption

```bash
# Enable encryption for DynamoDB tables
aws dynamodb update-table \
  --table-name Document-XXXXX-prod \
  --sse-specification Enabled=true,SSEType=KMS,KMSMasterKeyId=alias/aws/dynamodb

# Enable S3 bucket encryption
aws s3api put-bucket-encryption \
  --bucket householddocsapp-fileattachments-prod \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'
```

## Rollback Procedures

### 1. Application Rollback

```bash
# Rollback to previous Amplify deployment
amplify env checkout prod
amplify push --yes

# If needed, rollback to specific commit
git checkout <previous-commit-hash>
amplify push --yes
```

### 2. Infrastructure Rollback

```bash
# Rollback CloudFormation stack
aws cloudformation cancel-update-stack \
  --stack-name amplify-householddocsapp-prod

# Or rollback to previous template
aws cloudformation update-stack \
  --stack-name amplify-householddocsapp-prod \
  --template-body file://previous-template.json
```

### 3. Database Rollback

```bash
# Restore DynamoDB table from backup
aws dynamodb restore-table-from-backup \
  --target-table-name Document-XXXXX-prod-restored \
  --backup-arn arn:aws:dynamodb:us-east-1:ACCOUNT:table/Document-XXXXX-prod/backup/01234567890123-abcdefgh

# Point application to restored table (requires code change)
```

### 4. Emergency Procedures

**Complete Service Rollback:**
```bash
#!/bin/bash
# emergency-rollback.sh

echo "Starting emergency rollback..."

# 1. Switch to previous stable environment
amplify env checkout prod-stable

# 2. Deploy previous version
amplify push --yes

# 3. Update DNS to point to stable version
aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456789 \
  --change-batch file://rollback-dns-change.json

# 4. Notify stakeholders
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"text": "Emergency rollback completed for HouseholdDocs"}' \
  $SLACK_WEBHOOK_URL

echo "Emergency rollback completed"
```

## Performance Optimization

### 1. DynamoDB Optimization

```bash
# Enable DynamoDB Accelerator (DAX) for caching
aws dax create-cluster \
  --cluster-name householddocs-cache \
  --node-type dax.r4.large \
  --replication-factor 3 \
  --iam-role-arn arn:aws:iam::ACCOUNT:role/DAXServiceRole \
  --subnet-group-name householddocs-subnet-group \
  --security-group-ids sg-12345678
```

### 2. S3 Optimization

```bash
# Enable Transfer Acceleration
aws s3api put-bucket-accelerate-configuration \
  --bucket householddocsapp-fileattachments-prod \
  --accelerate-configuration Status=Enabled

# Configure CloudFront distribution for S3
aws cloudfront create-distribution \
  --distribution-config file://cloudfront-config.json
```

### 3. API Optimization

```bash
# Enable AppSync caching
aws appsync update-api-cache \
  --api-id XXXXXXXXXXXXXXXXXXXXXXXXXX \
  --ttl 3600 \
  --api-caching-behavior FULL_REQUEST_CACHING \
  --type LARGE
```

## Maintenance Procedures

### 1. Regular Maintenance Tasks

**Weekly:**
- Review CloudWatch metrics and alarms
- Check error logs for patterns
- Verify backup completion
- Update security patches

**Monthly:**
- Review and optimize DynamoDB capacity
- Analyze S3 storage costs and lifecycle policies
- Update dependencies and security patches
- Performance testing

**Quarterly:**
- Security audit and penetration testing
- Disaster recovery testing
- Cost optimization review
- Architecture review

### 2. Automated Maintenance

```bash
# Create maintenance Lambda function
aws lambda create-function \
  --function-name householddocs-maintenance \
  --runtime python3.9 \
  --role arn:aws:iam::ACCOUNT:role/lambda-execution-role \
  --handler maintenance.lambda_handler \
  --zip-file fileb://maintenance.zip

# Schedule maintenance tasks
aws events put-rule \
  --name householddocs-weekly-maintenance \
  --schedule-expression "cron(0 2 ? * SUN *)"

aws events put-targets \
  --rule householddocs-weekly-maintenance \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:ACCOUNT:function:householddocs-maintenance"
```

## Troubleshooting Common Deployment Issues

### 1. Amplify Push Failures

**Issue:** CloudFormation stack update fails
```bash
# Check stack events
aws cloudformation describe-stack-events \
  --stack-name amplify-householddocsapp-prod

# Check stack resources
aws cloudformation describe-stack-resources \
  --stack-name amplify-householddocsapp-prod
```

**Solution:**
```bash
# Delete failed stack and redeploy
amplify delete
amplify init
amplify push
```

### 2. Authentication Issues

**Issue:** Users cannot authenticate after deployment
```bash
# Verify Cognito configuration
aws cognito-idp describe-user-pool \
  --user-pool-id us-east-1_XXXXXXXXX

# Check identity pool
aws cognito-identity describe-identity-pool \
  --identity-pool-id us-east-1:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### 3. API Access Issues

**Issue:** GraphQL API returns authorization errors
```bash
# Test API with valid token
curl -X POST \
  -H "Authorization: Bearer $VALID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "query { listDocuments { items { id } } }"}' \
  https://XXXXXXXXXXXXXXXXXXXXXXXXXX.appsync-api.us-east-1.amazonaws.com/graphql
```

This deployment guide provides comprehensive instructions for deploying the cloud sync implementation. Follow each section carefully and verify each step before proceeding to the next.