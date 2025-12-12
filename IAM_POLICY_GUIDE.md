# IAM Policy Configuration Guide

This guide provides detailed instructions for configuring IAM policies to implement least-privilege access control and row-level security for the Household Docs App.

## Overview

The application uses AWS Cognito Identity Pools to provide temporary AWS credentials with fine-grained access control. This ensures:

- Users can only access their own data
- No cross-user data access is possible
- Principle of least privilege is enforced
- Row-level security in DynamoDB
- User-scoped S3 object access

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Mobile App                            │
│                                                          │
│  User signs in → Gets Cognito User Pool token          │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              Cognito Identity Pool                       │
│                                                          │
│  Exchanges token → Temporary AWS credentials            │
│  (Access Key, Secret Key, Session Token)                │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│                  IAM Role                                │
│                                                          │
│  Authenticated Role with policies:                      │
│  - DynamoDB: Row-level security                         │
│  - S3: User-scoped object access                        │
└────────────────────────┬────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              AWS Resources                               │
│                                                          │
│  DynamoDB Tables  │  S3 Buckets                         │
└─────────────────────────────────────────────────────────┘
```

## Step 1: Configure Cognito User Pool

### Via Amplify CLI

```bash
amplify add auth

# Choose configuration
? Do you want to use the default authentication and security configuration? 
  > Manual configuration

? Select the authentication/authorization services that you want to use:
  > User Sign-Up, Sign-In, connected with AWS IAM controls

? Please provide a friendly name for your resource:
  > householddocsauth

? Please enter a name for your identity pool:
  > householddocsidentitypool

? Allow unauthenticated logins?
  > No

? Do you want to enable 3rd party authentication providers?
  > No

? Do you want to add User Pool Groups?
  > No

? Do you want to add an admin queries API?
  > No

? Multifactor authentication (MFA) user login options:
  > OFF

? Email based user registration/forgot password:
  > Enabled

? Please specify an email verification subject:
  > Your verification code

? Please specify an email verification message:
  > Your verification code is {####}

? Do you want to override the default password policy?
  > Yes

? Enter the minimum password length:
  > 8

? Select the password character requirements:
  > Requires Lowercase, Requires Uppercase, Requires Numbers

? What attributes are required for signing up?
  > Email

? Specify the app's refresh token expiration period (in days):
  > 30

? Do you want to specify the user attributes this app can read and write?
  > No

? Do you want to enable any of the following capabilities?
  > (none)

? Do you want to use an OAuth flow?
  > No

? Do you want to configure Lambda Triggers for Cognito?
  > No
```

### Via AWS Console

1. Navigate to [Cognito Console](https://console.aws.amazon.com/cognito/)
2. Click **Create user pool**
3. Configure sign-in options:
   - **Sign-in options**: Email
   - **User name requirements**: Email address
4. Configure security requirements:
   - **Password policy**: Custom
   - **Minimum length**: 8 characters
   - **Password requirements**: Lowercase, uppercase, numbers
   - **MFA**: Optional (can enable later)
5. Configure sign-up experience:
   - **Self-registration**: Enabled
   - **Required attributes**: Email
   - **Email verification**: Required
6. Configure message delivery:
   - **Email provider**: Cognito (or SES for production)
7. Integrate your app:
   - **App client name**: household-docs-app
   - **Generate client secret**: No (for mobile apps)
8. Review and create

## Step 2: Configure Cognito Identity Pool

### Via Amplify CLI

The identity pool is automatically created when you add auth with Amplify CLI.

### Via AWS Console

1. Navigate to [Cognito Identity Pools](https://console.aws.amazon.com/cognito/federated)
2. Click **Create identity pool**
3. Configure identity pool:
   - **Identity pool name**: household_docs_identity_pool
   - **Enable access to unauthenticated identities**: No
4. Configure authentication providers:
   - **Authentication provider**: Cognito
   - **User Pool ID**: (your user pool ID)
   - **App client ID**: (your app client ID)
5. Configure IAM roles:
   - Create new IAM roles for authenticated and unauthenticated access
   - Note the role ARNs for next step

## Step 3: Configure IAM Policies

### DynamoDB Row-Level Security Policy

Create a policy for the authenticated IAM role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowUserToAccessOwnDocuments",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:BatchGetItem",
        "dynamodb:Query",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:BatchWriteItem"
      ],
      "Resource": [
        "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/Document-*",
        "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/Document-*/index/*"
      ],
      "Condition": {
        "ForAllValues:StringEquals": {
          "dynamodb:LeadingKeys": [
            "${cognito-identity.amazonaws.com:sub}"
          ]
        }
      }
    },
    {
      "Sid": "AllowUserToQueryOwnDocuments",
      "Effect": "Allow",
      "Action": [
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/Document-*",
        "arn:aws:dynamodb:REGION:ACCOUNT_ID:table/Document-*/index/*"
      ],
      "Condition": {
        "ForAllValues:StringEquals": {
          "dynamodb:LeadingKeys": [
            "${cognito-identity.amazonaws.com:sub}"
          ]
        }
      }
    }
  ]
}
```

**Key Points:**
- `${cognito-identity.amazonaws.com:sub}` is replaced with the user's identity ID at runtime
- `LeadingKeys` condition ensures users can only access items with their user ID as the partition key
- Replace `REGION` and `ACCOUNT_ID` with your values

### S3 User-Scoped Access Policy

Create a policy for S3 access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowUserToAccessOwnFiles",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET_NAME/private/${cognito-identity.amazonaws.com:sub}/*"
      ]
    },
    {
      "Sid": "AllowUserToListOwnFiles",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET_NAME"
      ],
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "private/${cognito-identity.amazonaws.com:sub}/*"
          ]
        }
      }
    },
    {
      "Sid": "AllowUserToGetBucketLocation",
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET_NAME"
      ]
    }
  ]
}
```

**Key Points:**
- All user files are stored under `private/{identityId}/`
- Users can only access files under their own prefix
- Replace `BUCKET_NAME` with your S3 bucket name

### Applying Policies via AWS Console

1. Navigate to [IAM Console](https://console.aws.amazon.com/iam/)
2. Go to **Roles**
3. Find your Cognito authenticated role (e.g., `Cognito_HouseholdDocsAuth_Role`)
4. Click **Add permissions** → **Create inline policy**
5. Switch to **JSON** tab
6. Paste the DynamoDB policy
7. Click **Review policy**
8. Name it `DynamoDBRowLevelSecurity`
9. Click **Create policy**
10. Repeat for S3 policy, name it `S3UserScopedAccess`

### Applying Policies via AWS CLI

```bash
# Create DynamoDB policy
aws iam put-role-policy \
  --role-name Cognito_HouseholdDocsAuth_Role \
  --policy-name DynamoDBRowLevelSecurity \
  --policy-document file://dynamodb-policy.json

# Create S3 policy
aws iam put-role-policy \
  --role-name Cognito_HouseholdDocsAuth_Role \
  --policy-name S3UserScopedAccess \
  --policy-document file://s3-policy.json
```

## Step 4: Configure DynamoDB Table Schema

### Table Design for Row-Level Security

Your DynamoDB table must use the user ID as the partition key:

```
Table: Document
Partition Key: userId (String)
Sort Key: documentId (String)

Attributes:
- userId: String (partition key)
- documentId: String (sort key)
- title: String
- category: String
- renewalDate: String
- notes: String
- createdAt: String
- lastModified: String
- version: Number
- syncState: String
```

### Creating Table via Amplify CLI

```bash
amplify add api

? Please select from one of the below mentioned services:
  > GraphQL

? Provide API name:
  > householddocsapi

? Choose the default authorization type for the API:
  > Amazon Cognito User Pool

? Do you want to configure advanced settings for the GraphQL API:
  > Yes

? Configure additional auth types?
  > No

? Configure conflict detection?
  > Yes

? Select the default resolution strategy:
  > Auto Merge

? Do you want to enable DataStore for your API?
  > Yes
```

Then edit your GraphQL schema to include owner-based authorization:

```graphql
type Document @model @auth(rules: [{ allow: owner }]) {
  id: ID!
  title: String!
  category: String!
  renewalDate: AWSDateTime
  notes: String
  createdAt: AWSDateTime!
  lastModified: AWSDateTime!
  version: Int!
  syncState: String!
  owner: String @auth(rules: [{ allow: owner, operations: [read] }])
}
```

The `@auth(rules: [{ allow: owner }])` directive automatically:
- Adds an `owner` field with the user's identity
- Restricts all operations to the owner
- Implements row-level security

## Step 5: Configure S3 Bucket

### Bucket Configuration

1. Navigate to [S3 Console](https://console.aws.amazon.com/s3/)
2. Select your bucket
3. Go to **Permissions** tab
4. Edit **Bucket policy**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAuthenticatedUsersToAccessOwnFiles",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:role/Cognito_HouseholdDocsAuth_Role"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::BUCKET_NAME/private/*"
    }
  ]
}
```

5. Enable **Block all public access**
6. Enable **Server-side encryption** (AES-256)

## Step 6: Testing Access Controls

### Test DynamoDB Row-Level Security

```dart
import 'package:household_docs_app/services/access_control_service.dart';

// Get current user ID
final accessControl = AccessControlService();
final userId = await accessControl.getCurrentUserId();

// Try to access a document
final canAccess = await accessControl.canAccessDocument(
  'doc-123',
  userId!, // Document owner
);

print('Can access own document: $canAccess'); // Should be true

// Try to access another user's document
final canAccessOther = await accessControl.canAccessDocument(
  'doc-456',
  'other-user-id', // Different owner
);

print('Can access other user document: $canAccessOther'); // Should be false
```

### Test S3 User-Scoped Access

```dart
// Get user's S3 prefix
final s3Prefix = await accessControl.getUserS3Prefix();
print('User S3 prefix: $s3Prefix'); // private/{identityId}/

// Try to access own file
final canAccessFile = await accessControl.canAccessFile(
  'private/${identityId}/document.pdf',
);
print('Can access own file: $canAccessFile'); // Should be true

// Try to access another user's file
final canAccessOtherFile = await accessControl.canAccessFile(
  'private/other-identity-id/document.pdf',
);
print('Can access other user file: $canAccessOtherFile'); // Should be false
```

## Security Best Practices

1. **Never Use Root Credentials**
   - Always use IAM roles and temporary credentials
   - Never embed AWS access keys in the application

2. **Principle of Least Privilege**
   - Grant only the minimum permissions required
   - Regularly review and audit IAM policies

3. **Enable CloudTrail**
   - Log all API calls for audit purposes
   - Monitor for unauthorized access attempts

4. **Use Cognito Identity Pools**
   - Provides temporary credentials that expire
   - Automatically rotates credentials

5. **Implement Row-Level Security**
   - Use partition keys based on user identity
   - Enforce access controls at the IAM level

6. **Regular Security Audits**
   - Review IAM policies quarterly
   - Check for overly permissive policies
   - Monitor CloudTrail logs for anomalies

## Troubleshooting

### Access Denied Errors

**Problem**: User gets "Access Denied" when accessing DynamoDB

**Solution**:
1. Verify the IAM role has the correct policy
2. Check that the partition key includes the user ID
3. Verify the `LeadingKeys` condition is correct
4. Check CloudTrail logs for the exact error

### S3 Access Issues

**Problem**: User cannot upload files to S3

**Solution**:
1. Verify the S3 bucket policy allows the IAM role
2. Check that files are being uploaded to the correct prefix
3. Verify the identity ID is correct
4. Check S3 bucket permissions and CORS configuration

### Cross-User Access

**Problem**: User can see another user's data

**Solution**:
1. Verify row-level security is implemented correctly
2. Check that queries include the user ID filter
3. Review IAM policies for overly broad permissions
4. Audit application code for security bypasses

## Compliance

This configuration meets:

- **HIPAA**: User data isolation and access controls
- **PCI-DSS**: Least privilege access
- **SOC 2**: Logical access controls
- **GDPR**: Data protection by design and default
- **ISO 27001**: Access control requirements

## Additional Resources

- [AWS Cognito Identity Pools](https://docs.aws.amazon.com/cognito/latest/developerguide/identity-pools.html)
- [IAM Policy Variables](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_variables.html)
- [DynamoDB Fine-Grained Access Control](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/specifying-conditions.html)
- [S3 User-Based Access Control](https://docs.aws.amazon.com/AmazonS3/latest/userguide/walkthrough1.html)
- [Amplify Auth Documentation](https://docs.amplify.aws/lib/auth/getting-started/q/platform/flutter/)
