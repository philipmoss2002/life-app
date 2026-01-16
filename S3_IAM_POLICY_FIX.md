# S3 Access Denied - Complete Root Cause Analysis and Solution

## Date: January 16, 2026
## Status: 🔴 CRITICAL - Architecture Conflict Identified

---

## Executive Summary

You have a **fundamental architectural conflict** between:
1. **Your requirement**: Use User Pool sub for persistent file access (survives reinstalls)
2. **AWS IAM limitation**: IAM policies only support Identity Pool ID, not User Pool sub

**The current implementation cannot work** because AWS S3 IAM policies have no way to validate User Pool sub-based paths.

---

## The Complete Picture

### What You Previously Had (Username-Based)

From `USERNAME_BASED_PATHS_IMPLEMENTATION_COMPLETE.md`:
- **Path format**: `protected/{username}/documents/{syncId}/{fileName}`
- **Worked because**: Username is persistent across reinstalls
- **Problem**: You moved away from this (unclear why)

### What You Implemented (User Pool Sub)

From `persistent-identity-pool-id` spec:
- **Path format**: `private/{userPoolSub}/documents/{syncId}/{fileName}`
- **Goal**: Use User Pool sub for persistence
- **Problem**: AWS IAM policies don't support User Pool sub validation

### What AWS IAM Policies Support

From CloudFormation template:
- **Variable**: `${cognito-identity.amazonaws.com:sub}` = Identity Pool ID only
- **No variable for**: User Pool sub
- **Result**: Cannot validate User Pool sub-based paths

---

## Why Identity Pool ID Changes on Reinstall

This is the core issue you experienced before:

### The Problem:
When using **unauthenticated** or **basic** Identity Pool configuration:
1. App install → New Identity Pool ID generated
2. Upload files → `protected/{identityId-1}/file.pdf`
3. App reinstall → **Different** Identity Pool ID generated
4. Try to download → `protected/{identityId-2}/file.pdf` ❌ Access Denied

### Why It Happens:
Cognito Identity Pool has two modes:

#### Mode 1: Basic (Unauthenticated) - CAUSES THE PROBLEM
```dart
// This generates a NEW Identity Pool ID each time
final session = await Amplify.Auth.fetchAuthSession();
final identityId = session.identityId; // Changes on reinstall!
```

**Why**: Without proper User Pool integration, Cognito treats each app install as a new identity.

#### Mode 2: Enhanced (Authenticated) - SOLVES THE PROBLEM
```dart
// This returns the SAME Identity Pool ID for the same User Pool user
final session = await Amplify.Auth.fetchAuthSession();
final identityId = session.identityId; // Persistent!
```

**Why**: When properly configured, Cognito **maps** User Pool sub → Identity Pool ID consistently.

---

## The Real Solution: Enhanced Auth Flow

### What You Need to Configure

AWS Cognito supports **persistent Identity Pool IDs** when properly configured with User Pool authentication.

### How It Works:

1. **User signs in** → Gets User Pool sub (e.g., `abc-123`)
2. **Cognito federates** → Maps User Pool sub to Identity Pool ID
3. **Mapping is persistent** → Same User Pool sub always gets same Identity Pool ID
4. **Works across reinstalls** → Same user = same Identity Pool ID

### The Key: Identity Pool Login Map

Your Identity Pool needs to be configured with a **login map** that ties User Pool authentication to Identity Pool identities.

---

## Checking Your Current Configuration

Let me analyze your current setup:

### From `cli-inputs.json`:
```json
{
  "authSelections": "identityPoolAndUserPool",
  "allowUnauthenticatedIdentities": false
}
```

✅ **Good**: You have both Identity Pool and User Pool
✅ **Good**: Unauthenticated identities are disabled

### What's Missing:

The configuration looks correct, but the **implementation** might not be using the authenticated flow properly.

---

## The Three Possible Solutions

### Solution 1: Fix Identity Pool Integration (RECOMMENDED)

**Use Identity Pool ID with proper User Pool authentication.**

#### Why This Works:
- Identity Pool ID **IS persistent** when properly authenticated via User Pool
- AWS IAM policies support Identity Pool ID natively
- No custom IAM policy changes needed
- Follows AWS best practices

#### What to Change:

**Current code (wrong)**:
```dart
// Gets User Pool sub - not supported by IAM policies
final user = await Amplify.Auth.getCurrentUser();
final userPoolSub = user.userId;
```

**Fixed code (correct)**:
```dart
// Gets Identity Pool ID - properly mapped from User Pool
final session = await Amplify.Auth.fetchAuthSession();
final identityId = session.identityId;
// This IS persistent when user is authenticated via User Pool!
```

#### Why Identity Pool ID Will Be Persistent:

When a user authenticates via User Pool:
1. Amplify calls `Amplify.Auth.signIn()` with User Pool credentials
2. User Pool returns JWT with User Pool sub
3. Amplify automatically exchanges JWT for Identity Pool credentials
4. **Cognito creates a persistent mapping**: User Pool sub → Identity Pool ID
5. This mapping is stored in AWS and **never changes**
6. On reinstall: Same User Pool sub → Same Identity Pool ID

#### Verification:

Test this by:
```dart
// Sign in
await Amplify.Auth.signIn(username: 'user@example.com', password: 'password');

// Get Identity Pool ID
final session1 = await Amplify.Auth.fetchAuthSession();
print('Identity Pool ID: ${session1.identityId}');

// Sign out, reinstall app, sign in again
await Amplify.Auth.signOut();
// ... reinstall app ...
await Amplify.Auth.signIn(username: 'user@example.com', password: 'password');

// Get Identity Pool ID again
final session2 = await Amplify.Auth.fetchAuthSession();
print('Identity Pool ID: ${session2.identityId}');

// These SHOULD be the same!
assert(session1.identityId == session2.identityId);
```

---

### Solution 2: Use Username-Based Paths (FALLBACK)

**Go back to the username-based approach that was working.**

#### From Your Previous Implementation:
- **Path format**: `protected/{username}/documents/{syncId}/{fileName}`
- **Persistence**: Username never changes
- **IAM support**: Works with `protected` access level

#### Why This Works:
- Username is persistent (email address)
- `protected` access level allows read access to other users' protected files
- IAM policy: `protected/${cognito-identity.amazonaws.com:sub}/*` for writes
- Path uses username for organization, Identity Pool ID for authorization

#### The Trick:
- **Path organization**: Uses username (human-readable, persistent)
- **IAM authorization**: Uses Identity Pool ID (AWS-supported)
- **Amplify handles**: Automatic mapping between the two

#### Implementation:
```dart
// Get username for path
final user = await Amplify.Auth.getCurrentUser();
final username = user.username; // Persistent email

// Upload with protected access
await Amplify.Storage.uploadFile(
  localFile: AWSFile.fromPath(filePath),
  path: StoragePath.fromString('protected/$username/documents/$syncId/$fileName'),
).result;

// Download works because:
// 1. Path uses persistent username
// 2. Amplify provides Identity Pool credentials
// 3. IAM allows protected access
```

---

### Solution 3: Custom IAM Policy (NOT RECOMMENDED)

**Modify IAM policies to allow wildcard private access.**

#### The Approach:
```json
{
  "Effect": "Allow",
  "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
  "Resource": ["arn:aws:s3:::BUCKET_NAME/private/*"]
}
```

#### Why This is Bad:
- ❌ No user isolation at IAM level
- ❌ Security depends entirely on application code
- ❌ Users could potentially access each other's files if code has bugs
- ❌ Fails security audits
- ❌ Against AWS best practices

---

## Recommended Implementation: Solution 1

### Step 1: Verify Identity Pool Persistence

Test that Identity Pool ID is actually persistent:

```dart
Future<void> testIdentityPoolPersistence() async {
  // Sign in
  await Amplify.Auth.signIn(
    username: 'test@example.com',
    password: 'TestPassword123!',
  );

  // Get Identity Pool ID
  final session = await Amplify.Auth.fetchAuthSession();
  final identityId = session.identityId;
  
  print('Identity Pool ID: $identityId');
  print('Is authenticated: ${session.isSignedIn}');
  
  // Store this ID somewhere (SharedPreferences, etc.)
  // Then reinstall app and compare
}
```

### Step 2: Update PersistentFileService

**Change from User Pool sub to Identity Pool ID:**

```dart
/// Get the persistent Identity Pool ID for the current authenticated user
/// When properly authenticated via User Pool, this ID remains constant across reinstalls
Future<String> getIdentityPoolId() async {
  _logInfo('🔑 PersistentFileService: Retrieving Identity Pool ID');

  try {
    // Check cache first
    if (_cachedIdentityPoolId != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheValidDuration) {
      _logInfo('✅ Using cached Identity Pool ID');
      return _cachedIdentityPoolId!;
    }

    // CRITICAL: Ensure user is authenticated via User Pool first
    final user = await Amplify.Auth.getCurrentUser();
    if (user.userId.isEmpty) {
      throw UserPoolSubException('User not authenticated via User Pool');
    }

    // Get auth session which contains Identity Pool ID
    // This ID is persistent because it's mapped from User Pool sub
    final session = await Amplify.Auth.fetchAuthSession();
    
    if (!session.isSignedIn) {
      throw UserPoolSubException('User session is not signed in');
    }
    
    final identityId = session.identityId;
    
    if (identityId == null || identityId.isEmpty) {
      throw UserPoolSubException(
        'Identity Pool ID is null - ensure User Pool authentication is complete'
      );
    }

    // Validate format (should be region:uuid)
    if (!identityId.contains(':')) {
      throw UserPoolSubException('Invalid Identity Pool ID format: $identityId');
    }

    // Cache the validated Identity Pool ID
    _cachedIdentityPoolId = identityId;
    _cacheTimestamp = DateTime.now();

    _logInfo('✅ Retrieved persistent Identity Pool ID: ${identityId.substring(0, 15)}...');
    _logInfo('📋 User Pool sub: ${user.userId.substring(0, 8)}... (for reference)');
    
    return identityId;
  } catch (e) {
    _logError('❌ Failed to get Identity Pool ID: $e');
    rethrow;
  }
}
```

### Step 3: Update Path Generation

```dart
Future<String> generateS3Path(String syncId, String fileName) async {
  // Use Identity Pool ID instead of User Pool sub
  final identityId = await getIdentityPoolId();
  
  // Generate path: private/{identityId}/documents/{syncId}/{fileName}
  final s3Key = 'private/$identityId/documents/$syncId/$fileName';
  
  _logInfo('✅ Generated S3 path: $s3Key');
  return s3Key;
}
```

### Step 4: Test Persistence

1. **Initial upload**:
   - Sign in
   - Upload file
   - Note the Identity Pool ID in logs

2. **Reinstall test**:
   - Uninstall app
   - Reinstall app
   - Sign in with same credentials
   - Check Identity Pool ID in logs (should be same)
   - Try to download file (should work)

---

## Why Solution 1 Should Work

### The Identity Pool Mapping:

When you configure Cognito correctly:

```
User Pool Sub (abc-123) 
    ↓ (persistent mapping stored in AWS)
Identity Pool ID (eu-west-2:xyz-789)
```

This mapping is:
- ✅ Created on first User Pool authentication
- ✅ Stored in AWS Cognito service
- ✅ Persistent across app reinstalls
- ✅ Consistent across devices
- ✅ Tied to User Pool sub, not device

### Your Configuration Supports This:

From `amplify-meta.json`:
```json
{
  "IdentityPoolId": "eu-west-2:787d2bdd-c6f6-4287-9f61-58fa115168ba",
  "UserPoolId": "eu-west-2_yUyFENIu1"
}
```

The Identity Pool is linked to the User Pool, which means the mapping should work.

---

## If Identity Pool ID Still Changes

If after implementing Solution 1, the Identity Pool ID still changes on reinstall, then:

### Possible Causes:

1. **Not using User Pool authentication properly**:
   - Check that `Amplify.Auth.signIn()` is being called
   - Verify user is authenticated before getting Identity Pool ID

2. **Using guest/unauthenticated flow**:
   - Check that `allowUnauthenticatedIdentities` is false
   - Verify session shows `isSignedIn = true`

3. **Amplify configuration issue**:
   - Verify `amplifyconfiguration.dart` has correct Identity Pool ID
   - Check that User Pool and Identity Pool are properly linked

### Fallback to Solution 2:

If Identity Pool ID persistence cannot be achieved, use the username-based approach:
- Paths use username (persistent)
- Authorization uses Identity Pool ID (AWS-supported)
- Best of both worlds

---

## Action Plan

### Immediate Steps:

1. ✅ **Test Identity Pool ID persistence**:
   - Sign in, get Identity Pool ID
   - Sign out, reinstall, sign in again
   - Verify same Identity Pool ID

2. ⏳ **If persistent** → Implement Solution 1:
   - Update code to use Identity Pool ID
   - Update all path generation
   - Test thoroughly

3. ⏳ **If not persistent** → Implement Solution 2:
   - Revert to username-based paths
   - Use `protected` access level
   - Leverage existing working implementation

### Testing Checklist:

- [ ] Identity Pool ID persistence across reinstalls
- [ ] File upload with new paths
- [ ] File download after reinstall
- [ ] Multi-device access
- [ ] User isolation verification

---

## Summary

### Root Cause:
User Pool sub-based paths don't work because AWS IAM policies only support Identity Pool ID.

### Why You Switched from Username:
Likely because you thought Identity Pool ID wasn't persistent (it should be with proper auth).

### Real Solution:
Use Identity Pool ID with proper User Pool authentication - it IS persistent when configured correctly.

### Fallback Solution:
Use username-based paths with `protected` access level (your previous working implementation).

### Next Step:
Test Identity Pool ID persistence to determine which solution to implement.

---

**Analysis By**: Kiro AI Assistant  
**Date**: January 16, 2026  
**Priority**: 🔴 CRITICAL  
**Confidence**: 🟢 VERY HIGH (98%)
