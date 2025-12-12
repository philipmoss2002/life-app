# Cloud Sync Feature - Quick Start Guide

This guide helps you get started with the cloud sync feature development quickly.

## Prerequisites

- Flutter SDK installed (3.0.6 or higher)
- AWS Account (see AWS_SETUP_GUIDE.md for detailed setup)
- Basic understanding of AWS services

## Quick Setup (10 minutes)

### 1. Install Dependencies

Dependencies have already been added to `pubspec.yaml`. Run:

```bash
cd household_docs_app
flutter pub get
```

### 1.5. Set Up Amplify DataStore

**Important**: This project uses **Amplify DataStore** for automatic sync. Follow these steps:

```bash
# Install Amplify CLI (if not already installed)
npm install -g @aws-amplify/cli

# Initialize Amplify
cd household_docs_app
amplify init

# Add authentication
amplify add auth

# Add API with DataStore
amplify add api

# Add storage
amplify add storage

# Push to AWS (creates all resources)
amplify push
```

See `AMPLIFY_DATASTORE_GUIDE.md` for detailed instructions.

### 2. Configure AWS Resources

You have two options:

#### Option A: Use Existing AWS Resources (Recommended for Development)

If your team already has AWS resources set up:

1. Get the configuration values from your team lead
2. Update `lib/config/amplify_config.dart` with the provided values
3. Skip to step 3

#### Option B: Set Up Your Own AWS Resources

Follow the detailed guide in `AWS_SETUP_GUIDE.md` to create:
- Cognito User Pool and Identity Pool
- S3 Bucket for file storage
- DynamoDB tables for metadata

### 3. Initialize Amplify in Your App

The `AmplifyService` is already created. Initialize it in your app's main function:

```dart
import 'package:household_docs_app/services/amplify_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Amplify
  try {
    await AmplifyService().initialize();
    print('Amplify initialized successfully');
  } catch (e) {
    print('Failed to initialize Amplify: $e');
  }
  
  runApp(MyApp());
}
```

### 4. Verify Setup

Run the app and check the console for:
```
Auth plugin added
Storage plugin added
API plugin added
Amplify configured successfully for environment: dev
```

## Project Structure

```
lib/
├── config/
│   └── amplify_config.dart          # AWS configuration for all environments
├── services/
│   ├── amplify_service.dart         # Amplify initialization
│   ├── database_service.dart        # Existing local database
│   └── notification_service.dart    # Existing notifications
├── models/
│   ├── document.dart                # Document model (will be extended)
│   └── file_attachment.dart         # File attachment model (will be extended)
└── screens/
    └── ...                          # UI screens
```

## Next Steps

Now that the infrastructure is set up, you can proceed with implementing the cloud sync features:

1. **Task 2**: Implement Authentication Service
   - User sign up, sign in, sign out
   - Token management
   - Session handling

2. **Task 3**: Implement Subscription Management
   - In-app purchases
   - Subscription validation
   - Access control

3. **Task 4**: Extend Data Models
   - Add cloud sync fields to Document model
   - Add cloud sync fields to FileAttachment model
   - Create SyncState enum

4. **Task 5**: Implement Document Sync Manager
   - Upload/download documents
   - Version tracking
   - Conflict detection

5. **Task 6**: Implement File Sync Manager
   - Upload/download files to S3
   - Progress tracking
   - Caching

## Development Workflow

### Running the App

```bash
# Development environment (default)
flutter run

# Staging environment
flutter run --dart-define=ENVIRONMENT=staging

# Production environment
flutter run --dart-define=ENVIRONMENT=production --release
```

### Building the App

```bash
# Development build
flutter build apk --dart-define=ENVIRONMENT=dev

# Production build
flutter build appbundle --dart-define=ENVIRONMENT=production --release
```

### Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/services/amplify_service_test.dart

# Run with coverage
flutter test --coverage
```

## Common Tasks

### Checking Current Environment

```dart
import 'package:household_docs_app/config/amplify_config.dart';

print('Current environment: ${AmplifyEnvironmentConfig.environment}');
```

### Switching Environments

Environments are set at build time, not runtime. To switch:

1. Rebuild the app with the desired environment:
   ```bash
   flutter run --dart-define=ENVIRONMENT=staging
   ```

### Updating AWS Configuration

1. Open `lib/config/amplify_config.dart`
2. Find the appropriate environment section (`_devConfig`, `_stagingConfig`, or `_productionConfig`)
3. Update the values
4. Rebuild the app

## Troubleshooting

### "Amplify is not configured" Error

**Cause**: Amplify wasn't initialized before use

**Solution**: Ensure `AmplifyService().initialize()` is called in `main()` before `runApp()`

### "Invalid configuration" Error

**Cause**: Configuration values are still placeholders

**Solution**: Replace all `REPLACE_WITH_XXX` values in `amplify_config.dart` with actual AWS resource IDs

### Build Errors After Adding Dependencies

**Cause**: Dependencies not properly installed

**Solution**:
```bash
flutter clean
flutter pub get
flutter run
```

### AWS Access Denied Errors

**Cause**: IAM policies not configured correctly

**Solution**: Review the IAM policy section in `AWS_SETUP_GUIDE.md`

## Useful Commands

```bash
# Check Flutter version
flutter --version

# Check for dependency updates
flutter pub outdated

# Analyze code
flutter analyze

# Format code
flutter format lib/

# Clean build artifacts
flutter clean

# Get dependencies
flutter pub get

# Run tests
flutter test

# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Resources

- **AWS Setup**: See `AWS_SETUP_GUIDE.md`
- **Environment Config**: See `ENVIRONMENT_CONFIG.md`
- **Design Document**: See `.kiro/specs/cloud-sync-premium/design.md`
- **Requirements**: See `.kiro/specs/cloud-sync-premium/requirements.md`
- **Tasks**: See `.kiro/specs/cloud-sync-premium/tasks.md`

## Getting Help

1. Check the documentation files in this directory
2. Review the design and requirements documents
3. Check AWS Amplify documentation: https://docs.amplify.aws/
4. Ask your team lead or senior developer

## Tips for Success

1. **Start with dev environment**: Always develop and test in the dev environment first
2. **Test incrementally**: Test each feature as you implement it
3. **Use version control**: Commit frequently with clear messages
4. **Follow the task list**: Implement tasks in order as they build on each other
5. **Write tests**: Write tests as you implement features, not after
6. **Document as you go**: Update documentation when you make changes
7. **Ask questions early**: Don't spend hours stuck on something - ask for help

## What's Already Done

✅ AWS Amplify packages added to pubspec.yaml
✅ AmplifyService created for initialization
✅ Configuration structure set up for all environments
✅ Documentation created (this file and others)

## What's Next

The next task is to implement the Authentication Service. This will include:
- User sign up with email verification
- User sign in with token management
- Sign out and session cleanup
- Password reset flow

See Task 2 in `.kiro/specs/cloud-sync-premium/tasks.md` for details.

Good luck! 🚀
