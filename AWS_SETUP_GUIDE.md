# AWS Infrastructure Setup Guide

This guide provides step-by-step instructions for setting up the AWS infrastructure required for the Household Docs App cloud sync feature.

## Prerequisites

- AWS Account (create one at https://aws.amazon.com/)
- AWS CLI installed and configured (https://aws.amazon.com/cli/)
- Basic understanding of AWS services

## Overview

The cloud sync feature uses the following AWS services:
- **Amazon Cognito**: User authentication and authorization
- **AWS AppSync**: GraphQL API with real-time subscriptions
- **Amazon DynamoDB**: Document metadata storage (managed by AppSync)
- **Amazon S3**: File attachment storage
- **Amplify DataStore**: Automatic sync and offline support

**Note**: This guide uses **Amplify DataStore** which automatically sets up AppSync, DynamoDB, and handles all sync logic. You don't need to manually configure API Gateway or Lambda functions.

## Step 1: Create AWS Account

1. Go to https://aws.amazon.com/
2. Click "Create an AWS Account"
3. Follow the registration process
4. Set up billing alerts to monitor costs

## Step 1.5: Install Amplify CLI

Before proceeding, install the Amplify CLI:

```bash
npm install -g @aws-amplify/cli
amplify configure
```

Follow the prompts to:
1. Sign in to AWS Console
2. Create an IAM user with AdministratorAccess
3. Save the access key and secret key
4. Configure the Amplify CLI with these credentials

**Important**: The Amplify CLI will automatically create and configure most AWS resources for you!

## Step 2: Initialize Amplify Project (Automated Setup)

**Recommended Approach**: Use Amplify CLI to automatically set up all resources.

### Initialize Amplify

```bash
cd household_docs_app
amplify init
```

Configuration:
- Project name: `householdDocsApp`
- Environment: `dev`
- Default editor: Your choice
- App type: `flutter`
- Do you want to use an AWS profile: `Yes`
- Select your AWS profile

### Add Authentication

```bash
amplify add auth
```

Configuration:
- Default configuration: `Default configuration`
- Sign-in method: `Email`
- Advanced settings: Use defaults

### Add API with DataStore

```bash
amplify add api
```

Configuration:
- Service: `GraphQL`
- API name: `householdDocsAPI`
- Authorization mode: `Amazon Cognito User Pool`
- Do you want to configure advanced settings: `No`
- Do you have an annotated GraphQL schema: `No`
- Do you want a guided schema creation: `Yes`
- What best describes your project: `One-to-many relationship`
- Do you want to edit the schema now: `Yes`

See `AMPLIFY_DATASTORE_GUIDE.md` for the complete GraphQL schema.

### Add Storage

```bash
amplify add storage
```

Configuration:
- Service: `Content (Images, audio, video, etc.)`
- Resource name: `householdDocsFiles`
- Bucket name: Accept default
- Access: `Auth users only`
- Access level: `Private` (per-user storage)

### Push to AWS

```bash
amplify push
```

This single command will:
- Create Cognito User Pool and Identity Pool
- Create AppSync GraphQL API
- Create DynamoDB tables
- Create S3 bucket
- Generate Flutter models
- Generate configuration files

**That's it!** Amplify CLI handles all the manual setup for you.

---

## Alternative: Manual Setup (Not Recommended)

If you prefer to set up resources manually without Amplify CLI, follow the steps below. However, this is more complex and error-prone.

## Step 2 (Manual): Set Up Amazon Cognito

### Create User Pool

1. Open the AWS Console and navigate to Amazon Cognito
2. Click "Create user pool"
3. Configure the following settings:
   - **Sign-in options**: Email
   - **Password policy**: 
     - Minimum length: 8 characters
     - Require uppercase, lowercase, numbers
   - **MFA**: Optional (can enable later)
   - **Email verification**: Required
4. Create an app client:
   - Name: `household-docs-app-client`
   - Authentication flows: `USER_SRP_AUTH`
   - No client secret (for mobile apps)
5. Note the following values:
   - User Pool ID (e.g., `us-east-1_XXXXXXXXX`)
   - App Client ID (e.g., `1234567890abcdefghijklmnop`)
   - Region (e.g., `us-east-1`)

### Create Identity Pool

1. In Amazon Cognito, click "Create identity pool"
2. Configure:
   - Name: `household_docs_identity_pool`
   - Enable access to unauthenticated identities: No
   - Authentication providers: Add the User Pool ID and App Client ID from above
3. Create IAM roles for authenticated users
4. Note the Identity Pool ID (e.g., `us-east-1:12345678-1234-1234-1234-123456789012`)

## Step 3: Set Up Amazon S3

### Create S3 Bucket

1. Navigate to Amazon S3 in the AWS Console
2. Click "Create bucket"
3. Configure:
   - **Bucket name**: `household-docs-files-[environment]` (e.g., `household-docs-files-dev`)
   - **Region**: Same as Cognito (e.g., `us-east-1`)
   - **Block all public access**: Enabled
   - **Bucket versioning**: Enabled (recommended)
   - **Default encryption**: AES-256 (SSE-S3)
4. Create separate buckets for dev, staging, and production

### Configure CORS

Add the following CORS configuration to your S3 bucket:

```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
    "AllowedOrigins": ["*"],
    "ExposeHeaders": ["ETag", "x-amz-meta-custom-header"],
    "MaxAgeSeconds": 3000
  }
]
```

### Set Up Bucket Policy

Configure the bucket policy to allow authenticated Cognito users to access their files:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::851725440788:role/service-role/iam-cognito-identity-pool-role"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::household-docs-files-dev/private/${cognito-identity.amazonaws.com:sub}/*"
    }
  ]
}
```

## Step 4: Set Up Amazon DynamoDB

### Create Documents Table

1. Navigate to Amazon DynamoDB in the AWS Console
2. Click "Create table"
3. Configure:
   - **Table name**: `household_docs_documents_[environment]`
   - **Partition key**: `userId` (String)
   - **Sort key**: `documentId` (String)
   - **Table settings**: On-demand capacity
   - **Encryption**: AWS owned key or AWS managed key
4. Add Global Secondary Indexes (GSI):
   - **GSI 1**: 
     - Name: `documentId-index`
     - Partition key: `documentId` (String)
     - Projection: All attributes

### Create Devices Table

1. Create another table for device management:
   - **Table name**: `household_docs_devices_[environment]`
   - **Partition key**: `userId` (String)
   - **Sort key**: `deviceId` (String)
   - **Table settings**: On-demand capacity

### Create Sync Queue Table

1. Create a table for the sync queue:
   - **Table name**: `household_docs_sync_queue_[environment]`
   - **Partition key**: `userId` (String)
   - **Sort key**: `timestamp` (Number)
   - **Table settings**: On-demand capacity
   - **TTL**: Enable with attribute `expiresAt` (set to 7 days)

## Step 5: Set Up IAM Policies

### Update Cognito Authenticated Role

1. Navigate to IAM in the AWS Console
2. Find the role created by Cognito (e.g., `Cognito_household_docs_identity_poolAuth_Role`)
3. Attach the following inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::household-docs-files-dev/private/${cognito-identity.amazonaws.com:sub}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/household_docs_documents_dev",
        "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/household_docs_devices_dev",
        "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/household_docs_sync_queue_dev"
      ],
      "Condition": {
        "ForAllValues:StringEquals": {
          "dynamodb:LeadingKeys": ["${cognito-identity.amazonaws.com:sub}"]
        }
      }
    }
  ]
}
```

## Step 6: Set Up API Gateway (Optional)

If you need custom API endpoints:

1. Navigate to API Gateway in the AWS Console
2. Create a new REST API
3. Configure:
   - **API name**: `household-docs-api`
   - **Endpoint type**: Regional
4. Create resources and methods as needed
5. Set up Cognito User Pool as the authorizer
6. Deploy the API to a stage (e.g., `dev`, `staging`, `prod`)
7. Note the API endpoint URL

## Step 7: Set Up Lambda Functions (Optional)

For custom sync logic or data processing:

1. Navigate to AWS Lambda in the AWS Console
2. Create functions as needed (e.g., conflict resolution, data migration)
3. Configure:
   - **Runtime**: Node.js 18.x or Python 3.11
   - **Execution role**: Create role with DynamoDB and S3 access
4. Connect to API Gateway or trigger from DynamoDB Streams

## Step 8: Configure the Flutter App

### If Using Amplify CLI (Recommended)

After running `amplify push`, configuration is automatic! The CLI generates:
- `lib/amplifyconfiguration.dart` - Contains all AWS resource IDs
- `lib/models/` - Generated DataStore models

Update `lib/services/amplify_service.dart`:

```dart
import 'package:amplify_datastore/amplify_datastore.dart';
import '../models/ModelProvider.dart';
import '../amplifyconfiguration.dart';

// In initialize():
await Amplify.addPlugin(
  AmplifyDataStore(modelProvider: ModelProvider.instance),
);
await Amplify.configure(amplifyconfig);
```

### If Using Manual Setup

1. Open `lib/config/amplify_config.dart`
2. Replace the placeholder values with your actual AWS resource IDs:

**For Development Environment:**
```dart
'PoolId': 'YOUR_DEV_IDENTITY_POOL_ID',
'Region': 'YOUR_REGION',
'PoolId': 'YOUR_DEV_USER_POOL_ID',
'AppClientId': 'YOUR_DEV_APP_CLIENT_ID',
'bucket': 'household-docs-files-dev',
'endpoint': 'YOUR_DEV_API_ENDPOINT', // if using API Gateway
```

**For Staging Environment:**
- Update the `_stagingConfig` section with staging resource IDs

**For Production Environment:**
- Update the `_productionConfig` section with production resource IDs

### Environment Variables

To build the app for different environments:

```bash
# Development
flutter build apk --dart-define=ENVIRONMENT=dev

# Staging
flutter build apk --dart-define=ENVIRONMENT=staging

# Production
flutter build apk --dart-define=ENVIRONMENT=production
```

## Step 9: Test the Configuration

1. Run the app in development mode
2. Check the console logs for Amplify initialization messages
3. Verify that you can:
   - Sign up a new user
   - Receive verification email
   - Sign in successfully
   - Access AWS resources

## Security Best Practices

1. **Never commit AWS credentials to version control**
2. **Use separate AWS accounts or environments for dev/staging/prod**
3. **Enable CloudTrail for audit logging**
4. **Set up billing alerts to monitor costs**
5. **Regularly rotate IAM credentials**
6. **Use AWS Secrets Manager for sensitive configuration**
7. **Enable MFA for AWS Console access**
8. **Review and minimize IAM permissions regularly**

## Cost Estimation

Estimated monthly costs for moderate usage (1000 active users):

- **Cognito**: ~$5-10 (first 50,000 MAUs free)
- **DynamoDB**: ~$10-25 (on-demand pricing)
- **S3**: ~$5-20 (depends on storage and transfer)
- **API Gateway**: ~$3-10 (if used)
- **Lambda**: ~$0-5 (generous free tier)

**Total estimated cost**: $23-70/month

Set up billing alerts at $10, $25, and $50 to monitor costs.

## Troubleshooting

### Common Issues

1. **"Amplify is not configured" error**
   - Ensure `AmplifyService.initialize()` is called before using Amplify
   - Check that all configuration values are correct

2. **"Access Denied" errors**
   - Verify IAM policies are correctly configured
   - Check that the Cognito Identity Pool is linked to the User Pool
   - Ensure bucket policies allow access from the Cognito role

3. **CORS errors**
   - Verify CORS configuration on S3 bucket
   - Check that allowed origins include your app's domain

4. **Authentication failures**
   - Verify User Pool and App Client IDs are correct
   - Check that email verification is working
   - Ensure password meets policy requirements

## Next Steps

After completing the AWS setup:

1. Proceed to Task 2: Implement authentication service
2. Test authentication flow with real AWS resources
3. Implement document and file synchronization
4. Set up monitoring and logging with CloudWatch

## Additional Resources

- [AWS Amplify Documentation](https://docs.amplify.aws/)
- [Amazon Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [Amazon S3 Documentation](https://docs.aws.amazon.com/s3/)
- [Amazon DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [AWS Free Tier](https://aws.amazon.com/free/)

## Support

For issues with AWS setup, consult:
- AWS Support (if you have a support plan)
- AWS Forums: https://forums.aws.amazon.com/
- Stack Overflow: Tag questions with `aws-amplify`, `amazon-cognito`, etc.
