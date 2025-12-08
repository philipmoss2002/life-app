# AWS Connectivity Test Script (PowerShell)
# Tests connectivity to all AWS services used by the app

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "AWS Connectivity Test" -ForegroundColor Cyan
Write-Host "Environment: Development" -ForegroundColor Cyan
Write-Host "Region: eu-west-2" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Test counters
$script:Passed = 0
$script:Failed = 0
$script:Warnings = 0

# Function to print test result
function Print-Result {
    param(
        [int]$Status,
        [string]$Message
    )
    
    if ($Status -eq 0) {
        Write-Host "✓ PASS: " -ForegroundColor Green -NoNewline
        Write-Host $Message
        $script:Passed++
    }
    elseif ($Status -eq 2) {
        Write-Host "⚠ WARN: " -ForegroundColor Yellow -NoNewline
        Write-Host $Message
        $script:Warnings++
    }
    else {
        Write-Host "✗ FAIL: " -ForegroundColor Red -NoNewline
        Write-Host $Message
        $script:Failed++
    }
}

# Test 1: Check if AWS CLI is installed
Write-Host "Test 1: AWS CLI Installation"
try {
    $awsVersion = aws --version 2>&1
    Print-Result 0 "AWS CLI installed: $awsVersion"
}
catch {
    Print-Result 1 "AWS CLI not installed. Install from: https://aws.amazon.com/cli/"
}
Write-Host ""

# Test 2: Check AWS credentials
Write-Host "Test 2: AWS Credentials"
try {
    $account = aws sts get-caller-identity --query Account --output text 2>&1
    if ($LASTEXITCODE -eq 0) {
        Print-Result 0 "AWS credentials configured. Account: $account"
    }
    else {
        Print-Result 1 "AWS credentials not configured. Run: aws configure"
    }
}
catch {
    Print-Result 1 "AWS credentials not configured. Run: aws configure"
}
Write-Host ""

# Test 3: Check Amplify CLI
Write-Host "Test 3: Amplify CLI Installation"
try {
    $amplifyVersion = amplify --version 2>&1
    Print-Result 0 "Amplify CLI installed: $amplifyVersion"
}
catch {
    Print-Result 2 "Amplify CLI not installed. Install: npm install -g @aws-amplify/cli"
}
Write-Host ""

# Test 4: Test Cognito User Pool
Write-Host "Test 4: Cognito User Pool Connectivity"
try {
    $cognitoResult = aws cognito-idp describe-user-pool `
        --user-pool-id eu-west-2_2xiHKynQh `
        --region eu-west-2 `
        --query 'UserPool.Name' `
        --output text 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Print-Result 0 "Cognito User Pool accessible: $cognitoResult"
    }
    else {
        Print-Result 1 "Cannot access Cognito User Pool: $cognitoResult"
    }
}
catch {
    Print-Result 1 "Cannot access Cognito User Pool: $_"
}
Write-Host ""

# Test 5: Test AppSync API
Write-Host "Test 5: AppSync API Connectivity"
try {
    $appsyncResult = aws appsync get-graphql-api `
        --api-id vzk56axy6bbttdpk3yqieo4zty `
        --region eu-west-2 `
        --query 'graphqlApi.name' `
        --output text 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Print-Result 0 "AppSync API accessible: $appsyncResult"
    }
    else {
        Print-Result 1 "Cannot access AppSync API: $appsyncResult"
    }
}
catch {
    Print-Result 1 "Cannot access AppSync API: $_"
}
Write-Host ""

# Test 6: Test S3 Bucket
Write-Host "Test 6: S3 Bucket Connectivity"
try {
    $s3Result = aws s3 ls s3://household-docs-files-dev940d5-dev --region eu-west-2 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $fileCount = ($s3Result | Measure-Object -Line).Lines
        Print-Result 0 "S3 Bucket accessible. Files/folders: $fileCount"
    }
    else {
        if ($s3Result -match "NoSuchBucket") {
            Print-Result 1 "S3 Bucket does not exist"
        }
        elseif ($s3Result -match "AccessDenied") {
            Print-Result 1 "Access denied to S3 Bucket"
        }
        else {
            Print-Result 2 "S3 Bucket accessible but empty or access limited"
        }
    }
}
catch {
    Print-Result 1 "Cannot access S3 Bucket: $_"
}
Write-Host ""

# Test 7: Test AppSync Endpoint HTTP
Write-Host "Test 7: AppSync Endpoint HTTP Connectivity"
try {
    $response = Invoke-WebRequest `
        -Uri "https://vzk56axy6bbttdpk3yqieo4zty.appsync-api.eu-west-2.amazonaws.com/graphql" `
        -Method POST `
        -Headers @{
            "Content-Type" = "application/json"
            "x-api-key" = "da2-novbj6zexfdinoyzfkbh2hgqfu"
        } `
        -Body '{"query":"query { __typename }"}' `
        -ErrorAction SilentlyContinue
    
    $httpCode = $response.StatusCode
    if ($httpCode -eq 200) {
        Print-Result 0 "AppSync endpoint responding (HTTP $httpCode)"
    }
    elseif ($httpCode -eq 401 -or $httpCode -eq 403) {
        Print-Result 2 "AppSync endpoint reachable but auth required (HTTP $httpCode)"
    }
    else {
        Print-Result 1 "AppSync endpoint not responding (HTTP $httpCode)"
    }
}
catch {
    $httpCode = $_.Exception.Response.StatusCode.value__
    if ($httpCode -eq 401 -or $httpCode -eq 403) {
        Print-Result 2 "AppSync endpoint reachable but auth required (HTTP $httpCode)"
    }
    else {
        Print-Result 1 "AppSync endpoint not responding: $_"
    }
}
Write-Host ""

# Test 8: Test DNS Resolution
Write-Host "Test 8: DNS Resolution"
try {
    $dnsResult = Resolve-DnsName -Name "vzk56axy6bbttdpk3yqieo4zty.appsync-api.eu-west-2.amazonaws.com" -ErrorAction Stop
    Print-Result 0 "DNS resolution successful for AppSync endpoint"
}
catch {
    Print-Result 1 "DNS resolution failed for AppSync endpoint"
}
Write-Host ""

# Test 9: Check Amplify Project Status
Write-Host "Test 9: Amplify Project Status"
if (Test-Path "amplify") {
    Push-Location "household_docs_app" -ErrorAction SilentlyContinue
    try {
        $amplifyStatus = amplify status 2>&1
        if ($amplifyStatus -match "No Change") {
            Print-Result 0 "Amplify project in sync"
        }
        else {
            Print-Result 2 "Amplify project has pending changes"
        }
    }
    catch {
        Print-Result 2 "Amplify CLI not available to check status"
    }
    finally {
        Pop-Location -ErrorAction SilentlyContinue
    }
}
else {
    Print-Result 2 "Amplify directory not found"
}
Write-Host ""

# Test 10: Check Flutter Configuration
Write-Host "Test 10: Flutter Amplify Configuration"
$configPath = "household_docs_app/lib/amplifyconfiguration.dart"
if (Test-Path $configPath) {
    $configContent = Get-Content $configPath -Raw
    if ($configContent -match "eu-west-2_2xiHKynQh") {
        Print-Result 0 "Amplify configuration file exists and contains correct User Pool ID"
    }
    else {
        Print-Result 1 "Amplify configuration file exists but may be incorrect"
    }
}
else {
    Print-Result 1 "Amplify configuration file not found"
}
Write-Host ""

# Summary
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Passed: " -ForegroundColor Green -NoNewline
Write-Host $script:Passed
Write-Host "Warnings: " -ForegroundColor Yellow -NoNewline
Write-Host $script:Warnings
Write-Host "Failed: " -ForegroundColor Red -NoNewline
Write-Host $script:Failed
Write-Host ""

$total = $script:Passed + $script:Warnings + $script:Failed
if ($total -gt 0) {
    $successRate = [math]::Round(($script:Passed / $total) * 100, 2)
    Write-Host "Success Rate: $successRate%"
}

Write-Host ""
if ($script:Failed -eq 0) {
    Write-Host "All critical tests passed! ✓" -ForegroundColor Green
    Write-Host "Your app should be able to connect to AWS services."
    exit 0
}
else {
    Write-Host "Some tests failed. ✗" -ForegroundColor Red
    Write-Host "Please review the failures above and check:"
    Write-Host "  1. AWS credentials are configured"
    Write-Host "  2. AWS services are deployed"
    Write-Host "  3. Network connectivity is working"
    Write-Host "  4. IAM permissions are correct"
    exit 1
}
