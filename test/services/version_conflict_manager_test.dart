import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/version_conflict_manager.dart';
import 'package:household_docs_app/models/Document.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'dart:math';

void main() {
  group('VersionConflictManager', () {
    late VersionConflictManager conflictManager;

    setUp(() {
      conflictManager = VersionConflictManager();
      // Clear any existing conflicts before each test
      conflictManager.clearConflicts();
    });

    group('Property Tests', () {
      test(
          'Property 14: Version Conflict Detection - **Feature: cloud-sync-implementation-fix, Property 14: Version Conflict Detection**',
          () async {
        // **Validates: Requirements 4.3**

        // Property: For any document update where the local version differs from the remote version,
        // a VersionConflictException should be thrown and conflict should be registered

        final random = Random();

        // Test multiple scenarios with different version conflicts
        for (int scenario = 0; scenario < 10; scenario++) {
          final documentId = 'doc_${random.nextInt(1000)}';

          // Generate random documents with different versions
          final localVersion = random.nextInt(10) + 1;
          final remoteVersion = random.nextInt(10) + 1;

          // Ensure versions are different for conflict
          if (localVersion == remoteVersion) {
            continue; // Skip this iteration if versions are the same
          }

          final localDocument =
              _generateRandomDocument(random, documentId, localVersion);
          final remoteDocument =
              _generateRandomDocument(random, documentId, remoteVersion);

          // Detect conflict
          final conflict = conflictManager.detectConflict(
            documentId,
            localDocument,
            remoteDocument,
          );

          // Verify conflict is properly registered
          expect(conflict.documentId, equals(documentId),
              reason: 'Conflict should have correct document ID');
          expect(conflict.localDocument.version, equals(localVersion),
              reason: 'Conflict should preserve local document version');
          expect(conflict.remoteDocument.version, equals(remoteVersion),
              reason: 'Conflict should preserve remote document version');
          expect(conflict.localDocument.version,
              isNot(equals(conflict.remoteDocument.version)),
              reason: 'Conflict should only exist when versions differ');

          // Verify conflict is tracked
          expect(conflictManager.hasConflict(documentId), isTrue,
              reason: 'Conflict manager should track the conflict');

          final retrievedConflict = conflictManager.getConflict(documentId);
          expect(retrievedConflict, isNotNull,
              reason: 'Should be able to retrieve the conflict');
          expect(retrievedConflict!.conflictId, equals(conflict.conflictId),
              reason: 'Retrieved conflict should match original');
        }
      });

      test('Conflict differences are properly identified', () {
        final random = Random();
        final documentId = 'test_doc';

        // Create documents with different fields
        final localDoc = _generateRandomDocument(random, documentId, 1);
        final remoteDoc = localDoc.copyWith(
          version: 2,
          title: 'Different Title',
          category: 'Different Category',
          notes: 'Different Notes',
        );

        final conflict =
            conflictManager.detectConflict(documentId, localDoc, remoteDoc);
        final differences = conflict.getDifferences();

        // Should detect differences in title, category, and notes
        expect(differences.containsKey('title'), isTrue,
            reason: 'Should detect title difference');
        expect(differences.containsKey('category'), isTrue,
            reason: 'Should detect category difference');
        expect(differences.containsKey('notes'), isTrue,
            reason: 'Should detect notes difference');

        expect(differences['title']['local'], equals(localDoc.title));
        expect(differences['title']['remote'], equals(remoteDoc.title));
      });

      test('Identical documents have no differences', () {
        final random = Random();
        final documentId = 'test_doc';

        final localDoc = _generateRandomDocument(random, documentId, 1);
        final remoteDoc = localDoc.copyWith(version: 2); // Only version differs

        final conflict =
            conflictManager.detectConflict(documentId, localDoc, remoteDoc);
        final differences = conflict.getDifferences();

        // Should have no differences except version (which is not tracked in differences)
        expect(differences.isEmpty, isTrue,
            reason:
                'Should have no content differences when only version differs');
      });

      test('Conflict resolution strategies work correctly', () async {
        final random = Random();
        final documentId = 'test_doc';

        final localDoc = _generateRandomDocument(random, documentId, 1);
        final remoteDoc = localDoc.copyWith(
          version: 2,
          title: 'Remote Title',
        );

        // Register conflict
        conflictManager.detectConflict(documentId, localDoc, remoteDoc);

        // Test that conflict exists
        expect(conflictManager.hasConflict(documentId), isTrue,
            reason: 'Conflict should be registered');

        // Test different resolution strategies (without actual sync operations)
        final strategies = [
          ConflictResolutionStrategy.keepLocal,
          ConflictResolutionStrategy.keepRemote,
          ConflictResolutionStrategy.createBranch,
        ];

        for (final strategy in strategies) {
          // Re-register conflict for each test
          conflictManager.detectConflict(documentId, localDoc, remoteDoc);

          try {
            // Test that the method structure is correct
            final resolved =
                conflictManager.resolveConflict(documentId, strategy);
            expect(resolved, isNotNull,
                reason: 'Should return a resolved document');
          } catch (e) {
            // Should not fail for basic resolution strategies
            fail('Resolution should not fail: $e');
          }
        }
      });

      test('Auto-resolution works for simple conflicts', () async {
        final random = Random();
        final documentId = 'test_doc';

        // Create conflict with only title difference
        final localDoc = _generateRandomDocument(random, documentId, 1);
        final remoteDoc = localDoc.copyWith(
          version: 2,
          title: 'Different Title',
          lastModified: TemporalDateTime.now(), // More recent
        );

        conflictManager.detectConflict(documentId, localDoc, remoteDoc);

        try {
          // Test the auto-resolution logic structure
          final resolved = conflictManager.autoResolveConflict(documentId);
          expect(resolved, isNotNull,
              reason: 'Should auto-resolve simple conflicts');
        } catch (e) {
          // Should not fail for simple conflicts
          fail('Auto-resolution should not fail for simple conflicts: $e');
        }

        // Test file path merging logic
        final localDocWithFiles =
            localDoc.copyWith(filePaths: ['file1.pdf', 'file2.pdf']);
        final remoteDocWithFiles = localDoc.copyWith(
          version: 2,
          filePaths: ['file2.pdf', 'file3.pdf'],
        );

        conflictManager.clearConflicts();
        conflictManager.detectConflict(
            documentId, localDocWithFiles, remoteDocWithFiles);

        try {
          final resolved = conflictManager.autoResolveConflict(documentId);
          expect(resolved, isNotNull,
              reason: 'Should auto-resolve file path conflicts');
        } catch (e) {
          // Should not fail for file path merging
          fail('Auto-resolution should not fail for file path conflicts: $e');
        }
      });

      test('Conflict statistics are accurate', () {
        final random = Random();

        // Add multiple conflicts
        for (int i = 0; i < 5; i++) {
          final documentId = 'doc_$i';
          final localDoc = _generateRandomDocument(random, documentId, 1);
          final remoteDoc = localDoc.copyWith(version: 2);

          conflictManager.detectConflict(documentId, localDoc, remoteDoc);
        }

        final stats = conflictManager.getConflictStats();

        expect(stats['totalConflicts'], equals(5),
            reason: 'Should track correct number of conflicts');
        expect(stats['conflictsByDocument'], hasLength(5),
            reason: 'Should list all conflicted documents');
        expect(stats['oldestConflict'], isNotNull,
            reason: 'Should track oldest conflict time');
        expect(stats['newestConflict'], isNotNull,
            reason: 'Should track newest conflict time');
      });

      test('Clear conflicts removes all tracked conflicts', () {
        final random = Random();

        // Add some conflicts
        for (int i = 0; i < 3; i++) {
          final documentId = 'doc_$i';
          final localDoc = _generateRandomDocument(random, documentId, 1);
          final remoteDoc = localDoc.copyWith(version: 2);

          conflictManager.detectConflict(documentId, localDoc, remoteDoc);
        }

        expect(conflictManager.getActiveConflicts(), hasLength(3),
            reason: 'Should have 3 active conflicts');

        conflictManager.clearConflicts();

        expect(conflictManager.getActiveConflicts(), isEmpty,
            reason: 'Should have no conflicts after clearing');

        final stats = conflictManager.getConflictStats();
        expect(stats['totalConflicts'], equals(0),
            reason: 'Stats should show zero conflicts after clearing');
      });
    });
  });
}

/// Generate a random document for testing
Document _generateRandomDocument(
    Random random, String documentId, int version) {
  final titles = ['Invoice', 'Receipt', 'Contract', 'Report', 'Letter'];
  final categories = ['Financial', 'Legal', 'Personal', 'Business', 'Medical'];

  return Document(
    id: documentId,
    userId: 'user_${random.nextInt(100)}',
    title: titles[random.nextInt(titles.length)],
    category: categories[random.nextInt(categories.length)],
    filePaths: ['file${random.nextInt(10)}.pdf'],
    renewalDate: random.nextBool()
        ? TemporalDateTime(
            DateTime.now().add(Duration(days: random.nextInt(365))))
        : null,
    notes: random.nextBool() ? 'Random notes ${random.nextInt(1000)}' : null,
    createdAt: TemporalDateTime(
        DateTime.now().subtract(Duration(days: random.nextInt(30)))),
    lastModified: TemporalDateTime(
        DateTime.now().subtract(Duration(hours: random.nextInt(24)))),
    version: version,
    syncState: 'synced',
    conflictId: null,
    deleted: false,
    deletedAt: null,
  );
}
