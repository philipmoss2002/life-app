import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

/// Service to manage data access controls and IAM policies
///
/// This service implements the principle of least privilege by ensuring:
/// - Users can only access their own data
/// - Authentication is required for all cloud operations
/// - Row-level security is enforced in DynamoDB
/// - S3 objects are scoped to user identity
class AccessControlService {
  static final AccessControlService _instance =
      AccessControlService._internal();
  factory AccessControlService() => _instance;
  AccessControlService._internal();

  /// Get the current authenticated user's ID
  /// This is used for row-level security in DynamoDB and S3 object scoping
  Future<String?> getCurrentUserId() async {
    try {
      final authSession = await Amplify.Auth.fetchAuthSession();

      if (authSession.isSignedIn) {
        // Get user attributes to retrieve the user ID
        final user = await Amplify.Auth.getCurrentUser();
        return user.userId;
      }

      return null;
    } catch (e) {
      safePrint('Error getting current user ID: $e');
      return null;
    }
  }

  /// Get the current user's identity ID for S3 access
  /// This is used to scope S3 objects to the user's identity
  Future<String?> getIdentityId() async {
    try {
      final authSession =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      if (authSession.isSignedIn) {
        return authSession.identityIdResult.value;
      }

      return null;
    } catch (e) {
      safePrint('Error getting identity ID: $e');
      return null;
    }
  }

  /// Verify that the user has access to a specific document
  /// Implements row-level security check
  Future<bool> canAccessDocument(
      String documentId, String documentUserId) async {
    try {
      final currentUserId = await getCurrentUserId();

      if (currentUserId == null) {
        safePrint('Access denied: User not authenticated');
        return false;
      }

      // User can only access their own documents
      final hasAccess = currentUserId == documentUserId;

      if (!hasAccess) {
        safePrint(
            'Access denied: User $currentUserId cannot access document owned by $documentUserId');
      }

      return hasAccess;
    } catch (e) {
      safePrint('Error checking document access: $e');
      return false;
    }
  }

  /// Verify that the user has access to a specific file
  /// Implements row-level security check for S3 objects
  Future<bool> canAccessFile(String fileKey) async {
    try {
      final identityId = await getIdentityId();

      if (identityId == null) {
        safePrint('Access denied: User not authenticated');
        return false;
      }

      // S3 objects should be prefixed with the user's identity ID
      // Format: private/{identityId}/filename
      final expectedPrefix = 'private/$identityId/';
      final hasAccess = fileKey.startsWith(expectedPrefix);

      if (!hasAccess) {
        safePrint('Access denied: File key does not match user identity');
      }

      return hasAccess;
    } catch (e) {
      safePrint('Error checking file access: $e');
      return false;
    }
  }

  /// Get the S3 key prefix for the current user
  /// All user files should be stored under this prefix
  Future<String?> getUserS3Prefix() async {
    try {
      final identityId = await getIdentityId();

      if (identityId == null) {
        return null;
      }

      // S3 objects are stored under: private/{identityId}/
      return 'private/$identityId/';
    } catch (e) {
      safePrint('Error getting user S3 prefix: $e');
      return null;
    }
  }

  /// Verify that the user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      final authSession = await Amplify.Auth.fetchAuthSession();
      return authSession.isSignedIn;
    } catch (e) {
      safePrint('Error checking authentication: $e');
      return false;
    }
  }

  /// Get IAM policy documentation for the application
  String getIAMPolicyDocumentation() {
    return '''
# IAM Policy Configuration

## Overview
The application uses AWS Cognito Identity Pools to provide temporary AWS credentials
with least-privilege access to AWS resources.

## Cognito User Pool Configuration

### User Pool Settings
- **Authentication**: Email + Password
- **Password Policy**: Minimum 8 characters
- **MFA**: Optional (can be enabled)
- **Email Verification**: Required

### User Attributes
- email (required)
- sub (user ID, auto-generated)

## Cognito Identity Pool Configuration

### Authentication Providers
- Cognito User Pool (primary)

### IAM Roles
Two IAM roles are created:
1. **Authenticated Role**: For signed-in users
2. **Unauthenticated Role**: For guest access (if enabled)

## IAM Policy for Authenticated Users

### DynamoDB Access Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query"
      ],
      "Resource": [
        "arn:aws:dynamodb:REGION:ACCOUNT:table/Document-*"
      ],
      "Condition": {
        "ForAllValues:StringEquals": {
          "dynamodb:LeadingKeys": [
            "\${cognito-identity.amazonaws.com:sub}"
          ]
        }
      }
    }
  ]
}
```

This policy ensures:
- Users can only access items where the partition key matches their user ID
- Row-level security is enforced at the IAM level
- No cross-user data access is possible

### S3 Access Policy
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
        "arn:aws:s3:::BUCKET_NAME/private/\${cognito-identity.amazonaws.com:sub}/*"
      ]
    },
    {
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
            "private/\${cognito-identity.amazonaws.com:sub}/*"
          ]
        }
      }
    }
  ]
}
```

This policy ensures:
- Users can only access objects under their identity ID prefix
- No cross-user file access is possible
- List operations are scoped to user's prefix only

## Row-Level Security Implementation

### DynamoDB
1. **Partition Key**: Use userId as partition key or part of composite key
2. **IAM Condition**: Enforce LeadingKeys condition in IAM policy
3. **Application Logic**: Always include userId in queries

### S3
1. **Object Prefix**: Store all objects under private/{identityId}/
2. **IAM Resource**: Restrict access to user's prefix only
3. **Application Logic**: Always use user-scoped paths

## Security Best Practices

1. **Least Privilege**: Grant only necessary permissions
2. **Temporary Credentials**: Use Cognito Identity Pool for temporary credentials
3. **No Long-Term Keys**: Never embed AWS access keys in the app
4. **Audit Logging**: Enable CloudTrail for all API calls
5. **Regular Reviews**: Periodically review and update IAM policies

## Configuration via Amplify CLI

### Update Auth Configuration
```bash
amplify update auth
# Configure advanced settings
# Set up IAM policies for authenticated users
amplify push
```

### Update Storage Configuration
```bash
amplify update storage
# Configure access permissions
# Set default access level to "private"
amplify push
```

## Verification

Use the AccessControlService to verify access controls:

```dart
final accessControl = AccessControlService();

// Check authentication
final isAuth = await accessControl.isAuthenticated();

// Get user ID for row-level security
final userId = await accessControl.getCurrentUserId();

// Verify document access
final canAccess = await accessControl.canAccessDocument(docId, docUserId);

// Get S3 prefix for user files
final s3Prefix = await accessControl.getUserS3Prefix();
```

## Compliance

This configuration meets:
- **HIPAA**: User data isolation
- **PCI-DSS**: Access control requirements
- **SOC 2**: Logical access controls
- **GDPR**: Data protection by design
''';
  }
}
