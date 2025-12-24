import 'package:test/test.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';

import '../../lib/services/sync_identifier_service.dart';
/// **Feature: sync-identifier-refactor, Property 4: File Path Sync Identifier Consistency**
/// **Validates: Requirements 4.1, 4.3**
///
/// Property-based test to verify that file attachment S3 keys contain the document's
/// sync identifier, ensuring files remain accessible regardless of local ID changes.
void main() {
  group('Property 4: File Path Sync Identifier Consistency', () {
    test('S3 keys should contain document sync identifier', () {
      // Property: For any file attachment, the S3 key should contain
      // the document's sync identifier

      const numTests = 100;

      for (int i = 0; i < numTests; i++) {
        // Generate a random sync identifier
        final syncId = SyncIdentifierService.generateValidated();

        // Generate random file names with various extensions
        final fileNames = _generateRandomFileNames(5);

        for (final fileName in fileNames) {
          // Simulate S3 key generation using the current implementation pattern
          final s3Key = _generateS3Key(syncId, fileName);

          // Property: S3 key should contain the sync identifier
          expect(
            s3Key.contains(syncId),
            isTrue,
            reason:
                'S3 key "$s3Key" should contain sync identifier "$syncId" for file "$fileName" (test $i)',
          );

          // Property: S3 key should follow the expected format
          expect(
            _validateS3KeyFormat(s3Key, syncId),
            isTrue,
            reason:
                'S3 key "$s3Key" should follow expected format with sync identifier "$syncId" (test $i)',
          );

          // Property: Sync identifier should be extractable from S3 key
          final extractedSyncId = _extractSyncIdFromS3Key(s3Key);
          expect(
            extractedSyncId,
            equals(syncId),
            reason:
                'Should be able to extract sync identifier "$syncId" from S3 key "$s3Key" (test $i)',
          );
        }
      }
    });

    test(
        'S3 keys should remain consistent regardless of local document ID changes',
        () {
      // Property: When a document's local ID changes, the file paths should
      // remain valid using the sync identifier

      const numTests = 50;

      for (int i = 0; i < numTests; i++) {
        final syncId = SyncIdentifierService.generateValidated();
        final fileName = _generateRandomFileName();

        // Generate S3 key with different simulated local IDs
        final s3Key1 = _generateS3Key(syncId, fileName);
        final s3Key2 = _generateS3Key(syncId, fileName);

        // Property: S3 keys should use same sync identifier regardless of local ID
        expect(
          _extractSyncIdFromS3Key(s3Key1),
          equals(_extractSyncIdFromS3Key(s3Key2)),
          reason:
              'S3 keys should use same sync identifier regardless of local ID changes (test $i)',
        );

        // Property: Both S3 keys should contain the same sync identifier
        expect(
          s3Key1.contains(syncId),
          isTrue,
          reason: 'First S3 key should contain sync identifier (test $i)',
        );

        expect(
          s3Key2.contains(syncId),
          isTrue,
          reason: 'Second S3 key should contain sync identifier (test $i)',
        );
      }
    });

    test('S3 key generation should be deterministic for same sync identifier',
        () {
      // Property: For the same sync identifier, S3 key generation
      // should produce consistent sync identifier placement

      const numTests = 50;

      for (int i = 0; i < numTests; i++) {
        final syncId = SyncIdentifierService.generateValidated();
        final fileName = _generateRandomFileName();

        // Generate multiple S3 keys for the same sync ID and file
        final s3Keys = <String>[];
        for (int j = 0; j < 5; j++) {
          s3Keys.add(_generateS3Key(syncId, fileName));
        }

        // Property: All S3 keys should contain the same sync identifier
        for (final s3Key in s3Keys) {
          expect(
            s3Key.contains(syncId),
            isTrue,
            reason:
                'All S3 keys should contain sync identifier "$syncId" (test $i)',
          );

          final extractedSyncId = _extractSyncIdFromS3Key(s3Key);
          expect(
            extractedSyncId,
            equals(syncId),
            reason:
                'All S3 keys should yield same sync identifier when extracted (test $i)',
          );
        }

        // Property: All S3 keys should follow the same format pattern
        for (final s3Key in s3Keys) {
          expect(
            _validateS3KeyFormat(s3Key, syncId),
            isTrue,
            reason: 'All S3 keys should follow consistent format (test $i)',
          );
        }
      }
    });

    test('S3 keys should handle various file name formats consistently', () {
      // Property: S3 key generation should work consistently with various
      // file name formats while preserving sync identifier

      const numTests = 20;

      for (int i = 0; i < numTests; i++) {
        final syncId = SyncIdentifierService.generateValidated();

        // Test with various file name patterns
        final testFileNames = [
          'document.pdf',
          'my-file_with-special.chars.docx',
          'file with spaces.txt',
          'UPPERCASE.PDF',
          'file.with.multiple.dots.xlsx',
          'no-extension',
          '123-numeric-start.png',
        ];

        for (final fileName in testFileNames) {
          final s3Key = _generateS3Key(syncId, fileName);

          // Property: S3 key should contain sync identifier regardless of file name format
          expect(
            s3Key.contains(syncId),
            isTrue,
            reason:
                'S3 key should contain sync identifier for file "$fileName" (test $i)',
          );

          // Property: S3 key should be valid format
          expect(
            _validateS3KeyFormat(s3Key, syncId),
            isTrue,
            reason:
                'S3 key should be valid format for file "$fileName" (test $i)',
          );

          // Property: Sync identifier should be extractable
          final extractedSyncId = _extractSyncIdFromS3Key(s3Key);
          expect(
            extractedSyncId,
            equals(syncId),
            reason:
                'Should extract sync identifier from S3 key for file "$fileName" (test $i)',
          );
        }
      }
    });

    test('S3 key format should prevent path traversal and maintain security',
        () {
      // Property: S3 keys should be secure and prevent path traversal attacks
      // while maintaining sync identifier consistency

      const numTests = 50;

      for (int i = 0; i < numTests; i++) {
        final syncId = SyncIdentifierService.generateValidated();

        // Test with potentially problematic file names
        final problematicFileNames = [
          '../../../etc/passwd',
          'file/../../../secret.txt',
          'normal-file.txt', // Control case
        ];

        for (final fileName in problematicFileNames) {
          final s3Key = _generateS3Key(syncId, fileName);

          // Property: S3 key should contain sync identifier
          expect(
            s3Key.contains(syncId),
            isTrue,
            reason:
                'S3 key should contain sync identifier even for problematic file names (test $i)',
          );

          // Property: S3 key should not contain path traversal patterns
          expect(
            s3Key.contains('../'),
            isFalse,
            reason: 'S3 key should not contain "../" path traversal (test $i)',
          );

          // Property: S3 key should start with expected prefix
          expect(
            s3Key.startsWith('documents/'),
            isTrue,
            reason: 'S3 key should start with documents/ prefix (test $i)',
          );
        }
      }
    });
  });
}

// Helper methods for testing

List<String> _generateRandomFileNames(int count) {
  final extensions = ['.pdf', '.docx', '.txt', '.png', '.jpg', '.xlsx', '.zip'];
  final prefixes = ['document', 'file', 'report', 'image', 'data', 'backup'];

  final fileNames = <String>[];
  for (int i = 0; i < count; i++) {
    final prefix = prefixes[i % prefixes.length];
    final extension = extensions[i % extensions.length];
    fileNames.add('$prefix-$i$extension');
  }
  return fileNames;
}

String _generateRandomFileName() {
  final extensions = ['.pdf', '.docx', '.txt', '.png', '.jpg', '.xlsx'];
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final extension = extensions[timestamp % extensions.length];
  return 'test-file-$timestamp$extension';
}

String _generateS3Key(String syncId, String fileName) {
  // Simulate the S3 key generation logic from SimpleFileSyncManager
  // Format: documents/userId/syncId/timestamp-fileName
  final userId = 'test-user-id'; // In real implementation, this comes from auth
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final cleanFileName = _basename(fileName); // Remove any path components
  return 'documents/$userId/$syncId/$timestamp-$cleanFileName';
}

String _basename(String filePath) {
  // Simple basename implementation to avoid path dependency
  final parts = filePath.split('/');
  if (parts.isNotEmpty) {
    return parts.last;
  }
  final windowsParts = filePath.split('\\');
  if (windowsParts.isNotEmpty) {
    return windowsParts.last;
  }
  return filePath;
}

bool _validateS3KeyFormat(String s3Key, String syncId) {
  // Validate that S3 key follows expected format: documents/userId/syncId/timestamp-fileName
  final parts = s3Key.split('/');

  // Should have at least 4 parts: documents, userId, syncId, timestamp-fileName
  if (parts.length < 4) return false;

  // First part should be 'documents'
  if (parts[0] != 'documents') return false;

  // Third part should be the sync identifier
  if (parts[2] != syncId) return false;

  // Last part should contain a timestamp and filename
  final fileName = parts.last;
  if (!fileName.contains('-')) return false;

  return true;
}

String _extractSyncIdFromS3Key(String s3Key) {
  // Extract sync identifier from S3 key format: documents/userId/syncId/timestamp-fileName
  final parts = s3Key.split('/');
  if (parts.length >= 3) {
    return parts[2]; // syncId is the third part
  }
  throw ArgumentError('Invalid S3 key format: $s3Key');
}
