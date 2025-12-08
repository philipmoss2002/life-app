# Deployment Guide - Household Docs App

## Build Information

**Build Date:** December 8, 2025
**Environment:** Development (dev)
**Build Type:** Release APK
**Output:** `build/app/outputs/flutter-apk/app-release.apk` (58.7MB)

## AWS Infrastructure Status

Your app is connected to the following AWS resources in the **eu-west-2** (London) region:

### Authentication (Cognito)
- **User Pool ID:** `eu-west-2_2xiHKynQh`
- **App Client ID:** `4ibbtj25igrq5tvlp0arube5ar`
- **Identity Pool ID:** `eu-west-2:98104381-a588-43ca-a290-e1ea3ec4ba04`
- **Sign-in Method:** Email
- **Password Policy:** Minimum 8 characters

### API (AppSync GraphQL)
- **Endpoint:** `https://vzk56axy6bbttdpk3yqieo4zty.appsync-api.eu-west-2.amazonaws.com/graphql`
- **API Key:** `da2-novbj6zexfdinoyzfkbh2hgqfu`
- **Authorization:** Amazon Cognito User Pools

### Storage (S3)
- **Bucket:** `household-docs-files-dev940d5-dev`
- **Region:** `eu-west-2`
- **Access Level:** Private (per-user storage)

## Installation Instructions

### Android Device/Emulator

1. **Enable Unknown Sources** (if installing manually):
   - Go to Settings > Security
   - Enable "Unknown sources" or "Install unknown apps"

2. **Transfer the APK**:
   ```bash
   # Via ADB
   adb install build/app/outputs/flutter-apk/app-release.apk
   
   # Or copy to device and install manually
   ```

3. **Launch the app** and test the following:
   - Sign up with a new email
   - Verify email (check inbox)
   - Sign in
   - Create a document
   - Upload a file
   - Verify sync status

## Testing Checklist

### Authentication Flow
- [ ] Sign up with email
- [ ] Receive verification email
- [ ] Verify email address
- [ ] Sign in successfully
- [ ] Sign out
- [ ] Password reset flow

### Document Management
- [ ] Create new document
- [ ] Edit document
- [ ] Delete document
- [ ] View document list
- [ ] Filter by category

### File Sync
- [ ] Upload file attachment
- [ ] Download file
- [ ] View file thumbnail (PDF)
- [ ] Delete file

### Cloud Sync
- [ ] Document syncs to cloud
- [ ] Sync status indicators work
- [ ] Offline mode queues changes
- [ ] Online mode syncs queued changes
- [ ] Conflict resolution (test with 2 devices)

### Subscription (if implemented)
- [ ] View subscription plans
- [ ] Purchase subscription (test mode)
- [ ] View subscription status
- [ ] Cancel subscription

## Build Configuration

### Gradle Versions
- **Android Gradle Plugin:** 8.9.1
- **Gradle Wrapper:** 8.11.1
- **Kotlin:** 2.1.0
- **Compile SDK:** 35
- **Min SDK:** 21 (Android 5.0)
- **Target SDK:** 35

### Memory Settings
- **JVM Heap:** 4096M
- **Max Metaspace:** 1024M
- **Desugaring:** Enabled (JDK libs 2.1.5)

## Building for Other Environments

### Staging Build
```bash
flutter build apk --dart-define=ENVIRONMENT=staging --release
```

### Production Build
```bash
# APK
flutter build apk --dart-define=ENVIRONMENT=production --release

# App Bundle (for Google Play)
flutter build appbundle --dart-define=ENVIRONMENT=production --release
```

## Troubleshooting

### Build Fails with "Gradle version" error
- Ensure `android/settings.gradle` has version 8.9.1
- Ensure `android/build.gradle` has version 8.9.1
- Clean build: `flutter clean && flutter pub get`

### "Java heap space" error
- Increase memory in `android/gradle.properties`:
  ```
  org.gradle.jvmargs=-Xmx4096M -XX:MaxMetaspaceSize=1024m
  ```

### Amplify not configured
- Ensure `amplify push` has been run
- Check `lib/amplifyconfiguration.dart` exists
- Verify AWS credentials are configured

### Authentication fails
- Check Cognito User Pool is active
- Verify email verification is enabled
- Check network connectivity

### Files won't upload
- Verify S3 bucket exists and is accessible
- Check IAM permissions for authenticated users
- Ensure network connectivity

## Next Steps

### For Development
1. Test all features thoroughly
2. Fix any bugs found
3. Add more test coverage
4. Optimize performance

### For Staging
1. Create staging AWS environment
2. Update `amplify_config.dart` with staging IDs
3. Build with `--dart-define=ENVIRONMENT=staging`
4. Test with beta users

### For Production
1. Create production AWS environment
2. Set up monitoring (CloudWatch)
3. Configure billing alerts
4. Enable MFA for AWS console
5. Set up automated backups
6. Create signing keys for release
7. Build with `--dart-define=ENVIRONMENT=production`
8. Submit to Google Play Store

## Monitoring

### AWS CloudWatch
- Monitor API Gateway requests
- Track Lambda function errors
- Set up alarms for high costs
- Monitor DynamoDB read/write capacity

### App Analytics
- Track user sign-ups
- Monitor sync success/failure rates
- Track storage usage
- Monitor crash reports

## Cost Monitoring

Set up billing alerts in AWS:
- Alert at $10 (warning)
- Alert at $25 (review usage)
- Alert at $50 (investigate immediately)

Estimated monthly cost for dev environment: $5-15

## Support

### AWS Issues
- Check AWS Console for service status
- Review CloudWatch logs
- Check IAM permissions
- Verify resource configurations

### App Issues
- Check device logs: `adb logcat`
- Review Flutter console output
- Test on multiple devices
- Check network connectivity

## Security Notes

1. **Never commit AWS credentials** to version control
2. **Rotate API keys** regularly
3. **Use separate environments** for dev/staging/prod
4. **Enable MFA** on AWS console
5. **Review IAM policies** regularly
6. **Monitor CloudTrail** for suspicious activity
7. **Keep dependencies updated** for security patches

## Additional Resources

- [AWS Amplify Documentation](https://docs.amplify.aws/)
- [Flutter Deployment Guide](https://flutter.dev/docs/deployment/android)
- [AWS Setup Guide](AWS_SETUP_GUIDE.md)
- [Environment Configuration](ENVIRONMENT_CONFIG.md)

---

**Build completed successfully!** 🎉

The app is now ready for testing on Android devices with full cloud sync capabilities.
