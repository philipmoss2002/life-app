import 'dart:async';
import 'database_service.dart';
import 'log_service.dart' as app_log;

/// Service responsible for managing backward compatibility during the sync identifier migration
class BackwardCompatibilityService {
  final DatabaseService _databaseService;

  // Cache for migration status to avoid frequent database queries
  bool? _allDocumentsHaveSyncIds;
  DateTime? _lastStatusCheck;
  static const Duration _statusCacheTimeout = Duration(minutes: 5);

  BackwardCompatibilityService({
    DatabaseService? databaseService,
  }) : _databaseService = databaseService ?? DatabaseService.instance;

  /// Check if all documents have sync identifiers
  /// This determines whether legacy matching logic should be disabled
  Future<bool> allDocumentsHaveSyncIdentifiers() async {
    try {
      // Use cached result if available and not expired
      if (_allDocumentsHaveSyncIds != null &&
          _lastStatusCheck != null &&
          DateTime.now().difference(_lastStatusCheck!) < _statusCacheTimeout) {
        return _allDocumentsHaveSyncIds!;
      }

      final documents = await _databaseService.getAllDocuments();

      if (documents.isEmpty) {
        // No documents means migration is complete (vacuously true)
        _allDocumentsHaveSyncIds = true;
        _lastStatusCheck = DateTime.now();
        return true;
      }

      // Check if all documents have non-null, non-empty sync identifiers
      final documentsWithSyncIds = documents
          .where((doc) => doc.syncId != null && doc.syncId!.isNotEmpty)
          .length;

      final allHaveSyncIds = documentsWithSyncIds == documents.length;

      // Cache the result
      _allDocumentsHaveSyncIds = allHaveSyncIds;
      _lastStatusCheck = DateTime.now();

      app_log.LogService().log(
          'BackwardCompatibilityService: $documentsWithSyncIds/${documents.length} documents have sync identifiers');

      return allHaveSyncIds;
    } catch (e) {
      app_log.LogService().log('Error checking sync identifier status: $e',
          level: app_log.LogLevel.error);
      // Return false to maintain legacy compatibility on error
      return false;
    }
  }

  /// Check if legacy matching logic should be enabled
  /// Returns true if legacy matching should be used (not all documents have sync IDs)
  Future<bool> shouldUseLegacyMatching() async {
    final allHaveSyncIds = await allDocumentsHaveSyncIdentifiers();
    return !allHaveSyncIds;
  }

  /// Clear cached status to force refresh on next check
  void clearStatusCache() {
    _allDocumentsHaveSyncIds = null;
    _lastStatusCheck = null;
  }
}
