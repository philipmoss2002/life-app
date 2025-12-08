#!/bin/bash

# AWS Connectivity Test Script
# Tests connectivity to all AWS services used by the app

echo "========================================="
echo "AWS Connectivity Test"
echo "Environment: Development"
echo "Region: eu-west-2"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0
WARNINGS=0

# Function to print test result
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        ((PASSED++))
    elif [ $1 -eq 2 ]; then
        echo -e "${YELLOW}⚠ WARN${NC}: $2"
        ((WARNINGS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        ((FAILED++))
    fi
}

# Test 1: Check if AWS CLI is installed
echo "Test 1: AWS CLI Installation"
if command -v aws &> /dev/null; then
    AWS_VERSION=$(aws --version 2>&1)
    print_result 0 "AWS CLI installed: $AWS_VERSION"
else
    print_result 1 "AWS CLI not installed. Install from: https://aws.amazon.com/cli/"
fi
echo ""

# Test 2: Check AWS credentials
echo "Test 2: AWS Credentials"
if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>&1)
    print_result 0 "AWS credentials configured. Account: $ACCOUNT"
else
    print_result 1 "AWS credentials not configured. Run: aws configure"
fi
echo ""

# Test 3: Check Amplify CLI
echo "Test 3: Amplify CLI Installation"
if command -v amplify &> /dev/null; then
    AMPLIFY_VERSION=$(amplify --version 2>&1)
    print_result 0 "Amplify CLI installed: $AMPLIFY_VERSION"
else
    print_result 2 "Amplify CLI not installed. Install: npm install -g @aws-amplify/cli"
fi
echo ""

# Test 4: Test Cognito User Pool
echo "Test 4: Cognito User Pool Connectivity"
COGNITO_RESULT=$(aws cognito-idp describe-user-pool \
    --user-pool-id eu-west-2_2xiHKynQh \
    --region eu-west-2 \
    --query 'UserPool.Name' \
    --output text 2>&1)

if [ $? -eq 0 ]; then
    print_result 0 "Cognito User Pool accessible: $COGNITO_RESULT"
else
    print_result 1 "Cannot access Cognito User Pool: $COGNITO_RESULT"
fi
echo ""

# Test 5: Test AppSync API
echo "Test 5: AppSync API Connectivity"
APPSYNC_RESULT=$(aws appsync get-graphql-api \
    --api-id vzk56axy6bbttdpk3yqieo4zty \
    --region eu-west-2 \
    --query 'graphqlApi.name' \
    --output text 2>&1)

if [ $? -eq 0 ]; then
    print_result 0 "AppSync API accessible: $APPSYNC_RESULT"
else
    print_result 1 "Cannot access AppSync API: $APPSYNC_RESULT"
fi
echo ""

# Test 6: Test S3 Bucket
echo "Test 6: S3 Bucket Connectivity"
S3_RESULT=$(aws s3 ls s3://household-docs-files-dev940d5-dev --region eu-west-2 2>&1)

if [ $? -eq 0 ]; then
    FILE_COUNT=$(echo "$S3_RESULT" | wc -l)
    print_result 0 "S3 Bucket accessible. Files/folders: $FILE_COUNT"
else
    if echo "$S3_RESULT" | grep -q "NoSuchBucket"; then
        print_result 1 "S3 Bucket does not exist"
    elif echo "$S3_RESULT" | grep -q "AccessDenied"; then
        print_result 1 "Access denied to S3 Bucket"
    else
        print_result 2 "S3 Bucket accessible but empty or access limited"
    fi
fi
echo ""

# Test 7: Test AppSync Endpoint HTTP
echo "Test 7: AppSync Endpoint HTTP Connectivity"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    https://vzk56axy6bbttdpk3yqieo4zty.appsync-api.eu-west-2.amazonaws.com/graphql \
    -H "Content-Type: application/json" \
    -H "x-api-key: da2-novbj6zexfdinoyzfkbh2hgqfu" \
    -d '{"query":"query { __typename }"}' 2>&1)

if [ "$HTTP_CODE" = "200" ]; then
    print_result 0 "AppSync endpoint responding (HTTP $HTTP_CODE)"
elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    print_result 2 "AppSync endpoint reachable but auth required (HTTP $HTTP_CODE)"
else
    print_result 1 "AppSync endpoint not responding (HTTP $HTTP_CODE)"
fi
echo ""

# Test 8: Test DNS Resolution
echo "Test 8: DNS Resolution"
if nslookup vzk56axy6bbttdpk3yqieo4zty.appsync-api.eu-west-2.amazonaws.com &> /dev/null; then
    print_result 0 "DNS resolution successful for AppSync endpoint"
else
    print_result 1 "DNS resolution failed for AppSync endpoint"
fi
echo ""

# Test 9: Check Amplify Project Status
echo "Test 9: Amplify Project Status"
if [ -d "amplify" ]; then
    cd household_docs_app 2>/dev/null || true
    if command -v amplify &> /dev/null; then
        AMPLIFY_STATUS=$(amplify status 2>&1)
        if echo "$AMPLIFY_STATUS" | grep -q "No Change"; then
            print_result 0 "Amplify project in sync"
        else
            print_result 2 "Amplify project has pending changes"
        fi
    else
        print_result 2 "Amplify CLI not available to check status"
    fi
else
    print_result 2 "Amplify directory not found"
fi
echo ""

# Test 10: Check Flutter Configuration
echo "Test 10: Flutter Amplify Configuration"
if [ -f "household_docs_app/lib/amplifyconfiguration.dart" ]; then
    if grep -q "eu-west-2_2xiHKynQh" "household_docs_app/lib/amplifyconfiguration.dart"; then
        print_result 0 "Amplify configuration file exists and contains correct User Pool ID"
    else
        print_result 1 "Amplify configuration file exists but may be incorrect"
    fi
else
    print_result 1 "Amplify configuration file not found"
fi
echo ""

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Failed:${NC} $FAILED"
echo ""

TOTAL=$((PASSED + WARNINGS + FAILED))
if [ $TOTAL -gt 0 ]; then
    SUCCESS_RATE=$((PASSED * 100 / TOTAL))
    echo "Success Rate: $SUCCESS_RATE%"
fi

echo ""
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All critical tests passed! ✓${NC}"
    echo "Your app should be able to connect to AWS services."
    exit 0
else
    echo -e "${RED}Some tests failed. ✗${NC}"
    echo "Please review the failures above and check:"
    echo "  1. AWS credentials are configured"
    echo "  2. AWS services are deployed"
    echo "  3. Network connectivity is working"
    echo "  4. IAM permissions are correct"
    exit 1
fi
