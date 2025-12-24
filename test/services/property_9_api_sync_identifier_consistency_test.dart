import 'package:test/test.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';

import '../../lib/services/sync_identifier_service.dart';
void main() {
  group('Property 9: API Sync Identifier Consistency', () {
    test('basic sync identifier consistency test', () {
      final syncId = SyncIdentifierService.generateValidated();
      expect(syncId, isNotEmpty);
      expect(SyncIdentifierGenerator.isValid(syncId), isTrue);
    });
  });
}
