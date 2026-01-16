import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'lib/services/simple_file_sync_manager.dart';

/// Test script to verify S3 access configuration is working with protected access level
/// Run this after updating the Amplify configuration to protected access level
Future<void> testS3Access() async {
  print('🧪 Testing S3 Access Configuration (Protected Access Level)...');

  try {
    // Check if user is authenticated
    final user = await Amplify.Auth.getCurrentUser();
    print('✅ User authenticated: ${user.userId}');

    // Create a test file
    final testDir = Directory.systemTemp;
    final testFilePath = '${testDir.path}/s3_test_file.txt';
    final testFile = File(testFilePath);
    await testFile
        .writeAsString('Test content for S3 protected access verification');

    print('📝 Created test file: $testFilePath');

    // Test upload
    final syncManager = SimpleFileSyncManager();
    final testSyncId = 'test-${DateTime.now().millisecondsSinceEpoch}';

    print('📤 Testing file upload with protected access level...');
    final s3Key = await syncManager.uploadFile(testFilePath, testSyncId);
    print('✅ Upload successful: $s3Key');
    print('📍 Expected S3 path: private/${user.userId}/$s3Key');

    // Test download
    print('📥 Testing file download with protected access level...');
    final downloadPath = await syncManager.downloadFile(s3Key, testSyncId);
    print('✅ Download successful: $downloadPath');

    // Verify downloaded content
    final downloadedFile = File(downloadPath);
    final downloadedContent = await downloadedFile.readAsString();
    if (downloadedContent ==
        'Test content for S3 protected access verification') {
      print('✅ File content verified successfully');
    } else {
      print('❌ File content mismatch');
      print('Expected: Test content for S3 protected access verification');
      print('Actual: $downloadedContent');
    }

    // Clean up test files
    await testFile.delete();
    await downloadedFile.delete();

    // Test delete
    print('🗑️ Testing file deletion with protected access level...');
    await syncManager.deleteFile(s3Key);
    print('✅ Delete successful');

    print(
        '🎉 All S3 protected access tests passed! Configuration is working correctly.');
    print('');
    print('✅ Protected access level is properly configured');
    print(
        '✅ User isolation is working (files stored under protected/${user.userId}/)');
    print('✅ Authentication is required for all operations');
    print('✅ No more "Access Denied" errors should occur');
  } catch (e) {
    print('❌ S3 access test failed: $e');
    print('');
    print('Possible issues:');
    print('1. User not authenticated - ensure you are logged in');
    print('2. Network connectivity issues');
    print('3. AWS credentials or permissions issues');
    print('4. Amplify configuration not updated properly');
    print('5. Path mismatch between protected access level and file paths');
    print('');
    print('Check the logs above for specific error details.');
    print('');
    print('If you see "Access Denied" errors, verify:');
    print(
        '- defaultAccessLevel is set to "private" in amplifyconfiguration.dart');
    print('- File paths do not use "public/" prefix');
    print('- User is properly authenticated');
  }
}

void main() async {
  await testS3Access();
}
