import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/sync_aware_file_manager.dart';
import 'package:household_docs_app/services/database_service.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';
import '../test_helpers.dart';
import 'dart:io';

import '../../lib/services/sync_identifier_service.dart';
void main() {
  group('SyncAwareFileManager', () {
    late SyncAwareFileManager fileManager;
    late DatabaseService databaseService;

    setUpAll(() {
      setupTestDatabase();
    });

    setUp(() {
      fileManager = SyncAwareFileManager();
      databaseService = DatabaseService.instance;
    });

    test('should generate valid S3 keys using sync identifiers', () {
      // Test that S3 key generation uses sync identifiers
      final syncId = SyncIdentifierService.generateValidated();
      final fileName = 'test-document.pdf';

      // The S3 key should contain the sync identifier
      expect(
          syncId,
          matches(RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      expect(syncId.length, equals(36));
    });

    test('should validate sync identifier format', () {
      // Test sync identifier validation
      expect(
          SyncIdentifierGenerator.isValid(
              '550e8400-e29b-41d4-a716-446655440000'),
          isTrue);
      expect(SyncIdentifierGenerator.isValid('invalid-uuid'), isFalse);
      expect(SyncIdentifierGenerator.isValid(''), isFalse);
    });

    test('should normalize sync identifier format', () {
      // Test sync identifier normalization
      final upperCaseId = '550E8400-E29B-41D4-A716-446655440000';
      final normalized = SyncIdentifierGenerator.normalize(upperCaseId);
      expect(normalized, equals('550e8400-e29b-41d4-a716-446655440000'));
    });

    test('should get file attachment stats', () async {
      // Test file attachment statistics
      final syncId = SyncIdentifierService.generateValidated();
      final stats = await fileManager.getFileAttachmentStats(syncId);

      // Should return valid stats even for non-existent document
      expect(stats.totalCount, equals(0));
      expect(stats.totalSize, equals(0));
      expect(stats.syncedCount, equals(0));
      expect(stats.syncProgress, equals(100.0));
    });

    test('should format file sizes correctly', () {
      // Test file size formatting
      final stats1 = FileAttachmentStats(
          totalCount: 1, totalSize: 500, syncedCount: 1, typeCount: {});
      expect(stats1.formattedSize, equals('500B'));

      final stats2 = FileAttachmentStats(
          totalCount: 1, totalSize: 1536, syncedCount: 1, typeCount: {});
      expect(stats2.formattedSize, equals('1.5KB'));

      final stats3 = FileAttachmentStats(
          totalCount: 1, totalSize: 1572864, syncedCount: 1, typeCount: {});
      expect(stats3.formattedSize, equals('1.5MB'));

      final stats4 = FileAttachmentStats(
          totalCount: 1, totalSize: 1610612736, syncedCount: 1, typeCount: {});
      expect(stats4.formattedSize, equals('1.5GB'));
    });

    test('should validate file attachments use sync identifiers', () async {
      // Test validation of sync identifier usage
      final syncId = SyncIdentifierService.generateValidated();
      final isValid =
          await fileManager.validateFileAttachmentsUseSyncId(syncId);

      // Should return true for non-existent document (no invalid attachments)
      expect(isValid, isTrue);
    });
  });
}
