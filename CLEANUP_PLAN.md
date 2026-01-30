# Cleanup Plan - Legacy Files to Remove

## Phase 1, Task 1.1: Remove Legacy Services and Files

### Legacy Models to Remove
- [x] `lib/models/file_migration_mapping.dart`
- [x] `lib/models/file_path.dart`

### Legacy Services to Remove
- [x] `lib/services/persistent_file_service.dart` - Migration service
- [x] `lib/services/document_sync_manager.dart` - Obsolete sync
- [x] `lib/services/file_attachment_sync_manager.dart` - Obsolete sync
- [x] `lib/services/sync_aware_file_manager.dart` - Obsolete sync
- [x] `lib/services/offline_sync_queue_service.dart` - Obsolete sync
- [x] `lib/services/deletion_tracking_service.dart` - Obsolete sync
- [x] `lib/services/monitoring_service.dart` - Not needed
- [x] `lib/services/sync_identifier_analytics_service.dart` - Not needed
- [x] `lib/services/data_cleanup_service.dart` - Not needed
- [x] `lib/services/file_cache_service.dart` - Not needed
- [x] `lib/services/simple_file_sync_manager.dart` - Will be replaced
- [x] `lib/services/file_sync_manager.dart` - Will be replaced
- [x] `lib/services/storage_manager.dart` - Will be replaced

### Legacy Utilities to Remove
- [x] `lib/utils/file_operation_error_handler.dart`
- [x] `lib/utils/retry_manager.dart`
- [x] `lib/utils/data_integrity_validator.dart`
- [x] `lib/utils/security_validator.dart`
- [x] `lib/utils/file_operation_logger.dart`
- [x] `lib/utils/user_pool_sub_validator.dart`

### Test Screens to Remove
- [x] `lib/screens/api_test_screen.dart`
- [x] `lib/screens/s3_test_screen.dart`
- [x] `lib/screens/upload_download_test_screen.dart`
- [x] `lib/screens/minimal_sync_test_screen.dart`
- [x] `lib/screens/detailed_sync_debug_screen.dart`
- [x] `lib/screens/path_debug_screen.dart`
- [x] `lib/screens/error_trace_screen.dart`
- [x] `lib/screens/subscription_debug_screen.dart`
- [x] `lib/screens/sync_diagnostic_screen.dart`

### Widgets to Remove
- [x] `lib/widgets/monitoring_dashboard_widget.dart`

### Legacy Documentation to Remove
- [x] `USERNAME_BASED_PATHS_IMPLEMENTATION_COMPLETE.md`
- [x] `PERSISTENT_FILE_ACCESS_SPEC_COMPLETE.md`
- [x] `S3_ACCESS_DENIED_FIX_APPLIED.md`
- [x] `S3_ACCESS_DENIED_ROOT_CAUSE_ANALYSIS.md`
- [x] `S3_ACCESS_LEVEL_FIX_COMPLETE.md`
- [x] `S3_IAM_POLICY_FIX.md`
- [x] All other S3_* and TASK_* documentation files

### Test Files to Remove
- [x] Test files for removed services
- [x] Complex test_helpers.dart
- [x] *.mocks.dart files

## Status: Ready to Execute
