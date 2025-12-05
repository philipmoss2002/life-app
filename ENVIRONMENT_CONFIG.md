# Environment Configuration Guide

This document explains how to configure and build the Household Docs App for different environments (development, staging, production).

## Overview

The app supports three environments:
- **Development (dev)**: For local development and testing
- **Staging**: For pre-production testing
- **Production (prod)**: For release to end users

Each environment has its own AWS resources (Cognito pools, S3 buckets, DynamoDB tables) to ensure isolation and prevent accidental data corruption.

## Configuration Files

### Main Configuration File

`lib/config/amplify_config.dart` contains the configuration for all environments. This file includes:
- Cognito User Pool and Identity Pool IDs
- S3 bucket names
- API Gateway endpoints
- AWS regions

### Environment Selection

The environment is selected at build time using Dart's `--dart-define` flag:

```dart
static const String environment = String.fromEnvironment(
  'ENVIRONMENT',
  defaultValue: 'dev',
);
```

## Setting Up Environments

### 1. Development Environment

**Purpose**: Local development and testing

**Setup Steps**:
1. Create AWS resources with `-dev` suffix (see AWS_SETUP_GUIDE.md)
2. Update `_devConfig` in `amplify_config.dart` with your dev resource IDs
3. Use relaxed security settings for easier testing

**Example Configuration**:
```dart
'PoolId': 'us-east-1_ABC123DEV',
'AppClientId': 'abc123def456dev',
'bucket': 'household-docs-files-dev',
```

### 2. Staging Environment

**Purpose**: Pre-production testing with production-like settings

**Setup Steps**:
1. Create AWS resources with `-staging` suffix
2. Update `_stagingConfig` in `amplify_config.dart`
3. Use production-like security settings
4. Test with a small group of beta users

**Example Configuration**:
```dart
'PoolId': 'us-east-1_ABC123STG',
'AppClientId': 'abc123def456stg',
'bucket': 'household-docs-files-staging',
```

### 3. Production Environment

**Purpose**: Live app for end users

**Setup Steps**:
1. Create AWS resources with `-prod` suffix
2. Update `_productionConfig` in `amplify_config.dart`
3. Use strict security settings
4. Enable monitoring and alerting
5. Set up automated backups

**Example Configuration**:
```dart
'PoolId': 'us-east-1_ABC123PRD',
'AppClientId': 'abc123def456prd',
'bucket': 'household-docs-files-prod',
```

## Building for Different Environments

### Development Build

```bash
# Android
flutter build apk --dart-define=ENVIRONMENT=dev

# iOS
flutter build ios --dart-define=ENVIRONMENT=dev

# Run in debug mode (defaults to dev)
flutter run
```

### Staging Build

```bash
# Android
flutter build apk --dart-define=ENVIRONMENT=staging --release

# iOS
flutter build ios --dart-define=ENVIRONMENT=staging --release
```

### Production Build

```bash
# Android
flutter build apk --dart-define=ENVIRONMENT=production --release

# iOS
flutter build ios --dart-define=ENVIRONMENT=production --release

# App Bundle for Google Play
flutter build appbundle --dart-define=ENVIRONMENT=production --release
```

## Verifying the Environment

To verify which environment the app is using:

1. Check the console logs during app startup:
   ```
   Amplify configured successfully for environment: dev
   ```

2. Add a debug screen in the app to display the current environment:
   ```dart
   Text('Environment: ${AmplifyConfig.environment}')
   ```

## Environment-Specific Settings

### Development
- **Logging**: Verbose logging enabled
- **Error handling**: Show detailed error messages
- **Caching**: Shorter cache durations
- **Sync interval**: More frequent (for testing)
- **Storage quota**: Lower limits for testing

### Staging
- **Logging**: Standard logging
- **Error handling**: User-friendly messages with error codes
- **Caching**: Production-like durations
- **Sync interval**: Production settings
- **Storage quota**: Production limits

### Production
- **Logging**: Minimal logging (errors only)
- **Error handling**: User-friendly messages only
- **Caching**: Optimized for performance
- **Sync interval**: 30 seconds (as specified)
- **Storage quota**: Full production limits

## Security Considerations

### Development
- Can use test credentials
- Relaxed password policies for testing
- Debug mode enabled

### Staging
- Use real credentials
- Production password policies
- Debug mode disabled
- Test with real payment methods (sandbox)

### Production
- Real credentials only
- Strict password policies
- Debug mode disabled
- Real payment processing
- Enable all security features (MFA, etc.)

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Deploy

on:
  push:
    branches:
      - develop
      - staging
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        
      - name: Build for Development
        if: github.ref == 'refs/heads/develop'
        run: flutter build apk --dart-define=ENVIRONMENT=dev
        
      - name: Build for Staging
        if: github.ref == 'refs/heads/staging'
        run: flutter build apk --dart-define=ENVIRONMENT=staging --release
        
      - name: Build for Production
        if: github.ref == 'refs/heads/main'
        run: flutter build appbundle --dart-define=ENVIRONMENT=production --release
```

## Environment Variables

You can also use environment variables for sensitive configuration:

```dart
static String getApiKey() {
  return const String.fromEnvironment('API_KEY', defaultValue: '');
}
```

Build with:
```bash
flutter build apk --dart-define=ENVIRONMENT=production --dart-define=API_KEY=your_key_here
```

## Best Practices

1. **Never commit AWS credentials**: Use placeholders in the config file
2. **Use separate AWS accounts**: Ideally, dev/staging/prod should be in separate AWS accounts
3. **Test in staging first**: Always test changes in staging before production
4. **Automate builds**: Use CI/CD to ensure consistent builds
5. **Version your environments**: Tag releases with environment info
6. **Monitor all environments**: Set up CloudWatch alarms for all environments
7. **Document changes**: Keep this file updated when adding new configuration

## Troubleshooting

### Wrong Environment Loaded

**Problem**: App is using the wrong environment

**Solution**:
1. Check the build command includes `--dart-define=ENVIRONMENT=xxx`
2. Verify the environment name is spelled correctly (dev, staging, production)
3. Clean and rebuild: `flutter clean && flutter build apk --dart-define=ENVIRONMENT=xxx`

### Configuration Not Found

**Problem**: "REPLACE_WITH_XXX" values still present

**Solution**:
1. Update `amplify_config.dart` with actual AWS resource IDs
2. Follow the AWS_SETUP_GUIDE.md to create resources
3. Ensure all placeholder values are replaced

### Build Fails

**Problem**: Build fails with configuration errors

**Solution**:
1. Run `flutter pub get` to ensure dependencies are installed
2. Check that all required AWS resources exist
3. Verify the configuration syntax is valid Dart/JSON

## Additional Resources

- [Flutter Build Modes](https://flutter.dev/docs/testing/build-modes)
- [Dart Environment Variables](https://dart.dev/guides/environment-declarations)
- [AWS Amplify Configuration](https://docs.amplify.aws/lib/project-setup/create-application/q/platform/flutter/)

## Support

For environment configuration issues:
1. Check this documentation first
2. Review AWS_SETUP_GUIDE.md
3. Check the console logs for specific error messages
4. Consult the team's internal documentation
