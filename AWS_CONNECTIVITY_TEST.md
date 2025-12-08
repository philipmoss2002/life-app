# AWS Connectivity Testing Guide

This guide helps you verify that your app can successfully connect to AWS services.

## Quick Test Methods

### Method 1: Using Amplify CLI (Fastest)

```bash
# Check Amplify status
amplify status

# Test API endpoint
amplify api gql-compile

# Check auth configuration
amplify auth console
```

### Method 2: Using AWS CLI

```bash
# Test Cognito User Pool
aws cognito-idp describe-user-pool --user-pool-id eu-west-2_2xiHKynQh --region eu-west-2

# Test AppSync API
aws appsync get-graphql-api --api-id vzk56axy6bbttdpk3yqieo4zty --region eu-west-2

# Test S3 Bucket
aws s3 ls s3://household-docs-files-dev940d5-dev --region eu-west-2

# Test overall connectivity
aws sts get-caller-identity
```

### Method 3: Using curl/HTTP Requests

```bash
# Test AppSync endpoint (should return 401 without auth)
curl -X POST https://vzk56axy6bbttdpk3yqieo4zty.appsync-api.eu-west-2.amazonaws.com/graphql

# Test with API Key
curl -X POST \
  https://vzk56axy6bbttdpk3yqieo4zty.appsync-api.eu-west-2.amazonaws.com/graphql \
  -H "Content-Type: application/json" \
  -H "x-api-key: da2-novbj6zexfdinoyzfkbh2hgqfu" \
  -d '{"query":"query { __typename }"}'
```

### Method 4: Run the App with Debug Logging

The easiest way is to run the app and check the console logs:

```bash
# Run in debug mode with verbose logging
flutter run --dart-define=ENVIRONMENT=dev -v
```

Look for these log messages:
- ✅ "Amplify configured successfully"
- ✅ "Auth plugin initialized"
- ✅ "Storage plugin initialized"
- ✅ "API plugin initialized"
- ❌ Any error messages about configuration or connectivity

## Detailed Connectivity Tests

### 1. Test Cognito Authentication

**From AWS Console:**
1. Go to AWS Console → Cognito
2. Select User Pool: `eu-west-2_2xiHKynQh`
3. Check "Users" tab - should be accessible
4. Check "App integration" → App clients - should show your client

**From App:**
1. Launch the app
2. Try to sign up with a test email
3. Check if verification email arrives
4. Try to sign in

**Expected Results:**
- Sign up creates user in Cognito
- Verification email is sent
- Sign in returns auth token
- Console shows: "User authenticated successfully"

### 2. Test AppSync GraphQL API

**Using Amplify CLI:**
```bash
cd household_docs_app
amplify api console
```

**Using GraphQL Query:**
```graphql
query ListDocuments {
  listDocuments {
    items {
      id
      title
      category
    }
  }
}
```

**Expected Results:**
- API console opens successfully
- Query returns data or empty array (not error)
- Console shows: "GraphQL query successful"

### 3. Test S3 Storage

**From AWS Console:**
1. Go to AWS Console → S3
2. Find bucket: `household-docs-files-dev940d5-dev`
3. Check if bucket exists and is accessible
4. Check bucket permissions

**From App:**
1. Sign in to the app
2. Create a document
3. Try to upload a file
4. Check S3 bucket for the uploaded file

**Expected Results:**
- File appears in S3 under `private/{user-id}/`
- Console shows: "File uploaded successfully"
- File size matches original

### 4. Test Network Connectivity

**Check DNS Resolution:**
```bash
# Test if endpoints are reachable
nslookup vzk56axy6bbttdpk3yqieo4zty.appsync-api.eu-west-2.amazonaws.com
nslookup household-docs-files-dev940d5-dev.s3.eu-west-2.amazonaws.com
```

**Check HTTPS Connectivity:**
```bash
# Test SSL/TLS connection
openssl s_client -connect vzk56axy6bbttdpk3yqieo4zty.appsync-api.eu-west-2.amazonaws.com:443
```

**Expected Results:**
- DNS resolves to AWS IP addresses
- SSL connection succeeds with valid certificate
- No firewall or proxy blocking

## Common Issues and Solutions

### Issue 1: "Amplify is not configured"

**Symptoms:**
- App crashes on startup
- Error: "Amplify has not been configured"

**Solutions:**
1. Check `lib/amplifyconfiguration.dart` exists
2. Verify `AmplifyService.initialize()` is called in `main.dart`
3. Run `amplify pull` to sync configuration

### Issue 2: "Auth plugin not added"

**Symptoms:**
- Sign up/sign in fails
- Error: "Auth plugin has not been added to Amplify"

**Solutions:**
1. Check `amplify_auth_cognito` is in `pubspec.yaml`
2. Verify auth plugin is added in `AmplifyService.initialize()`
3. Run `flutter clean && flutter pub get`

### Issue 3: "Network request failed"

**Symptoms:**
- Requests timeout
- Error: "Network request failed"

**Solutions:**
1. Check internet connectivity
2. Verify firewall/proxy settings
3. Check AWS service status: https://status.aws.amazon.com/
4. Verify region is correct (eu-west-2)

### Issue 4: "Access Denied" errors

**Symptoms:**
- 403 errors
- "Access Denied" messages

**Solutions:**
1. Check IAM roles in AWS Console
2. Verify Cognito Identity Pool is linked to User Pool
3. Check S3 bucket policies
4. Verify user is authenticated before accessing resources

### Issue 5: "Invalid API Key"

**Symptoms:**
- GraphQL queries fail
- Error: "Invalid API key"

**Solutions:**
1. Check API key in `amplifyconfiguration.dart`
2. Verify API key hasn't expired in AppSync console
3. Regenerate API key if needed: `amplify api update`

## Monitoring and Debugging

### Enable Debug Logging

Add to your app's initialization:

```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Enable Amplify logging
  Amplify.addPlugin(AmplifyLogger());
  
  await AmplifyService.initialize();
  runApp(MyApp());
}
```

### Check AWS CloudWatch Logs

1. Go to AWS Console → CloudWatch
2. Select "Log groups"
3. Look for logs from:
   - `/aws/appsync/apis/{api-id}`
   - `/aws/lambda/{function-name}` (if using Lambda)
4. Check for errors or unusual patterns

### Monitor API Usage

1. Go to AWS Console → AppSync
2. Select your API
3. Click "Metrics" tab
4. Check:
   - Request count
   - Error rate
   - Latency

### Check Cognito Users

1. Go to AWS Console → Cognito
2. Select User Pool
3. Click "Users" tab
4. Verify test users are created
5. Check user status (CONFIRMED, UNCONFIRMED, etc.)

## Automated Connectivity Test Script

Run this test to check all connections:

```bash
# Save as test_aws_connectivity.sh
#!/bin/bash

echo "Testing AWS Connectivity..."
echo "=========================="

# Test 1: Amplify Status
echo "1. Checking Amplify status..."
cd household_docs_app
amplify status

# Test 2: AWS CLI Connectivity
echo "2. Testing AWS CLI connectivity..."
aws sts get-caller-identity

# Test 3: Cognito User Pool
echo "3. Testing Cognito User Pool..."
aws cognito-idp describe-user-pool \
  --user-pool-id eu-west-2_2xiHKynQh \
  --region eu-west-2 \
  --query 'UserPool.Name'

# Test 4: AppSync API
echo "4. Testing AppSync API..."
aws appsync get-graphql-api \
  --api-id vzk56axy6bbttdpk3yqieo4zty \
  --region eu-west-2 \
  --query 'graphqlApi.name'

# Test 5: S3 Bucket
echo "5. Testing S3 Bucket..."
aws s3 ls s3://household-docs-files-dev940d5-dev --region eu-west-2

# Test 6: Network Connectivity
echo "6. Testing network connectivity..."
curl -s -o /dev/null -w "%{http_code}" \
  https://vzk56axy6bbttdpk3yqieo4zty.appsync-api.eu-west-2.amazonaws.com/graphql

echo ""
echo "=========================="
echo "Connectivity test complete!"
```

## Testing Checklist

Use this checklist to verify connectivity:

- [ ] Amplify CLI shows all resources as "No Change"
- [ ] AWS CLI can authenticate and list resources
- [ ] Cognito User Pool is accessible
- [ ] AppSync API endpoint responds
- [ ] S3 bucket is accessible
- [ ] App can initialize Amplify without errors
- [ ] App can sign up new users
- [ ] App can sign in existing users
- [ ] App can upload files to S3
- [ ] App can query GraphQL API
- [ ] CloudWatch logs show successful requests
- [ ] No 403 or 401 errors in logs

## Next Steps

Once connectivity is verified:

1. ✅ Test full user flow (sign up → verify → sign in)
2. ✅ Test document creation and sync
3. ✅ Test file upload and download
4. ✅ Test offline mode and sync
5. ✅ Monitor AWS costs and usage
6. ✅ Set up CloudWatch alarms
7. ✅ Test on multiple devices

## Support Resources

- **AWS Status:** https://status.aws.amazon.com/
- **Amplify Docs:** https://docs.amplify.aws/
- **AWS Support:** https://console.aws.amazon.com/support/
- **Community:** https://github.com/aws-amplify/amplify-flutter/discussions

## Emergency Contacts

If connectivity fails completely:

1. Check AWS Service Health Dashboard
2. Verify billing account is active
3. Check for service limits/quotas
4. Contact AWS Support (if you have a support plan)
5. Check Amplify GitHub issues for known problems

---

**Last Updated:** December 8, 2025
**Region:** eu-west-2 (London)
**Environment:** Development
