# Implementation Plan

- [x] 1. Add synchronization and state tracking to NewDatabaseService





  - Add mutex lock for thread-safe database operations
  - Add _currentUserId field to track which user's database is open
  - Add _isSwitching flag to prevent concurrent database switches
  - Add dependency on synchronized package for mutex
  - _Requirements: 2.1, 2.2, 8.1, 8.2_

- [x] 1.1 Write property test for concurrent database access






  - **Property 9: Concurrent operation safety**
  - **Validates: Requirements 8.1, 8.2, 8.3**

- [x] 2. Implement user ID management methods





  - Create _getCurrentUserId() method to get authenticated user ID or 'guest'
  - Create _sanitizeUserId() method to sanitize user IDs for file names
  - Create _getDatabaseFileName() method to generate database file names
  - Add validation for user ID format (Cognito sub claim)
  - Handle edge cases (null, empty, invalid characters)
  - _Requirements: 2.1, 12.1, 12.2, 12.3, 12.4, 12.5_

- [ ]* 2.1 Write property test for user ID validation
  - **Property 10: User ID validation**
  - **Validates: Requirements 12.1, 12.2, 12.3, 12.4, 12.5**

- [x] 3. Implement database lifecycle methods





  - Modify get database getter to check for user changes
  - Create _openDatabase() method to open user-specific database
  - Create _switchDatabase() method to switch between user databases
  - Modify close() method to properly clean up resources
  - Add logging for all database lifecycle events
  - _Requirements: 1.1, 1.2, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 9.1, 9.2, 9.3_

- [ ]* 3.1 Write property test for database switching
  - **Property 3: Database switching correctness**
  - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**

- [ ]* 3.2 Write property test for connection cleanup
  - **Property 4: Connection cleanup**
  - **Validates: Requirements 3.1, 3.2, 3.3**

- [x] 4. Implement legacy database migration





  - Create migrateLegacyDatabase() method to migrate from shared database
  - Create _markLegacyDatabaseMigrated() method to track migrated users
  - Create hasBeenMigrated() method to check migration status
  - Use SharedPreferences to store list of migrated users
  - Handle migration errors gracefully with retry capability
  - Add progress logging during migration
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 9.4_

- [ ]* 4.1 Write property test for migration completeness
  - **Property 5: Migration completeness**
  - **Validates: Requirements 4.1, 4.2, 4.3, 4.4**

- [x] 5. Implement database maintenance methods





  - Create listUserDatabases() method to list all user database files
  - Create deleteUserDatabase() method to delete specific user's database
  - Create vacuumDatabase() method to optimize current database
  - Create getDatabaseStats() method to get database statistics
  - Add proper error handling for all maintenance operations
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 6. Modify AuthenticationService to manage database lifecycle





  - Modify signOut() to close database before signing out
  - Modify signIn() to initialize user database after authentication
  - Create _initializeUserDatabase() method to handle database setup
  - Trigger migration check on first sign-in
  - Add error handling for database initialization failures
  - _Requirements: 1.1, 1.5, 3.1, 3.5, 4.1_

- [ ]* 6.1 Write property test for database persistence
  - **Property 2: Database persistence**
  - **Validates: Requirements 1.5, 3.4**

- [x] 7. Implement user-scoped file storage in FileService





  - Create _getUserFileDirectory() method to get user-specific file directory
  - Modify uploadFile() to use user-specific directory
  - Modify downloadFile() to use user-specific directory
  - Create clearUserFiles() method for cleanup
  - Ensure file paths are relative in database
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ]* 7.1 Write property test for file isolation
  - **Property 6: File isolation**
  - **Validates: Requirements 5.1, 5.2, 5.3, 5.4**

- [x] 8. Implement guest database support




  - Ensure _getCurrentUserId() returns 'guest' when not authenticated
  - Ensure _getDatabaseFileName() creates 'household_docs_guest.db' for guest
  - Test guest database creation and usage
  - Verify guest mode works without authentication
  - _Requirements: 6.1, 6.2_

- [ ]* 8.1 Write property test for guest mode functionality
  - **Property 7: Guest mode functionality**
  - **Validates: Requirements 6.1, 6.2**

- [ ] 9. Implement guest data migration service
  - Create GuestDataMigrationService class
  - Implement hasGuestData() method to check for guest documents
  - Implement migrateGuestData() method to copy guest data to user database
  - Implement _clearGuestDatabase() method to clear guest data after migration
  - Add UI prompt to ask user if they want to migrate guest data
  - _Requirements: 6.3, 6.4, 6.5_

- [ ]* 9.1 Write property test for guest data migration
  - **Property 8: Guest data migration**
  - **Validates: Requirements 6.3, 6.4, 6.5**

- [x] 10. Add comprehensive error handling





  - Add try-catch blocks for all database operations
  - Implement retry logic with exponential backoff for transient errors
  - Add fallback to guest database on authentication failures
  - Create descriptive error messages for all error scenarios
  - Log all errors with full context (user ID, operation, stack trace)
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 11. Implement rapid authentication change handling





  - Add debouncing for rapid sign-in/sign-out cycles
  - Ensure operations complete before database switches
  - Add queue for pending operations during database switch
  - Test with rapid authentication changes
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 12. Add comprehensive logging





  - Log database open events with user ID and file name
  - Log database close events with user ID and duration
  - Log database switch events with old and new user IDs
  - Log migration events with progress and completion status
  - Log all errors with full context and stack traces
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 13. Update app initialization flow





  - Ensure database is initialized after authentication
  - Handle case where app starts without authentication (guest mode)
  - Add migration check on first authenticated app launch
  - Show migration progress indicator if migration takes time
  - Handle migration errors gracefully
  - _Requirements: 1.1, 4.1, 6.1_

- [ ] 14. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ]* 15. Write integration test for multi-user isolation
  - Test User A creates documents, signs out
  - Test User B creates documents, sees only their documents
  - Test User A signs in again, sees only their documents
  - Verify complete data isolation between users
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [ ]* 16. Write integration test for legacy migration
  - Create legacy database with test documents
  - Sign in as user
  - Verify migration occurs automatically
  - Verify all documents migrated correctly
  - Verify migration doesn't repeat on subsequent sign-ins
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ]* 17. Write integration test for guest mode flow
  - Create documents as guest user
  - Sign in as authenticated user
  - Verify guest data migration prompt appears
  - Accept migration
  - Verify guest data migrated to user database
  - Verify guest database cleared
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ]* 18. Write integration test for rapid authentication changes
  - Perform 20 rapid sign-in/sign-out cycles
  - Verify system remains stable
  - Verify no data corruption
  - Verify no file handle leaks
  - Verify correct database always open
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [ ]* 19. Write integration test for file isolation
  - User A uploads files, signs out
  - User B uploads files with same names
  - Verify User B's files don't overwrite User A's files
  - User A signs in, verifies their files intact
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [ ]* 20. Write unit tests for database service
  - Test database file naming with various user IDs
  - Test user ID sanitization edge cases
  - Test database opening and closing
  - Test database switching between users
  - Test guest database usage
  - Test concurrent access with mutex
  - _Requirements: 1.1, 1.2, 2.1, 2.2, 8.1, 12.1, 12.2_

- [ ]* 21. Write unit tests for migration logic
  - Test legacy database detection
  - Test migration data correctness
  - Test migration idempotency
  - Test migration failure recovery
  - Test migration status tracking
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ]* 22. Write unit tests for file service
  - Test user-specific directory creation
  - Test file path generation
  - Test file isolation between users
  - Test file cleanup
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 23. Add database cleanup utilities





  - Create admin function to list all user databases
  - Create admin function to delete legacy database after all users migrated
  - Create function to delete orphaned database files
  - Add database size monitoring
  - _Requirements: 11.1, 11.2, 11.4_

- [x] 24. Update documentation





  - Document new database architecture
  - Document migration process
  - Document guest mode behavior
  - Document error handling and recovery
  - Add troubleshooting guide
  - _Requirements: All_

- [ ] 25. Final checkpoint - Comprehensive testing




  - Run all unit tests
  - Run all property tests
  - Run all integration tests
  - Perform manual testing scenarios
  - Verify no regressions in existing functionality
  - Ensure all tests pass, ask the user if questions arise.
