# Implementation Plan

- [x] 1. Create sync identifier infrastructure





  - Create SyncIdentifierGenerator class with UUID v4 generation and validation
  - Add sync identifier validation methods and normalization
  - Create unit tests for sync identifier generation and validation
  - _Requirements: 1.1, 1.5, 9.1, 9.2, 9.4_

- [x] 1.1 Write property test for sync identifier uniqueness





  - **Property 1: Sync Identifier Uniqueness**
  - **Validates: Requirements 9.5**

- [x] 1.2 Write property test for sync identifier immutability





  - **Property 2: Sync Identifier Immutability**
  - **Validates: Requirements 1.5**

- [x] 2. Update database schema and models





  - Add syncId column to documents table
  - Update Document model to include syncId field
  - Create DocumentTombstone model for deletion tracking
  - Update FileAttachment model to reference syncId instead of document ID
  - _Requirements: 3.1, 3.2, 3.4, 5.4, 12.1, 12.5_

- [x] 3. Implement document matching logic








  - Create DocumentMatcher class with sync identifier matching
  - Create content hash calculation for change detection
  - _Requirements: 2.1_

- [x] 3.1 Write property test for document matching by sync identifier





  - **Property 3: Document Matching by Sync Identifier**
  - **Validates: Requirements 2.1**

- [x] 4. Update file attachment handling





  - Modify S3 key generation to use sync identifiers
  - Update file download logic to use sync identifier-based paths
  - Migrate existing file attachments to new path structure
  - Update FileAttachment table relationships
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 14.2, 14.3, 14.4_

- [x] 4.1 Write property test for file path sync identifier consistency






  - **Property 4: File Path Sync Identifier Consistency**
  - **Validates: Requirements 4.1, 4.3**

- [x] 5. Implement deletion tracking with tombstones





  - Create DocumentTombstone model and database table
  - Update deletion logic to create tombstones
  - Implement tombstone checking during sync
  - Add tombstone cleanup for records older than 90 days
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 5.1 Write property test for deletion tombstone preservation





  - **Property 5: Deletion Tombstone Preservation**
  - **Validates: Requirements 5.3, 5.4**

- [x] 6. Update sync coordinator and queue management







  - Modify SyncCoordinator to use sync identifiers
  - Update sync queue operations to reference sync identifiers
  - Implement sync operation consolidation by sync identifier
  - Update retry logic to use sync identifiers for idempotency
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 6.1 Write property test for sync queue consolidation






  - **Property 7: Sync Queue Consolidation**
  - **Validates: Requirements 7.5**

- [x] 7. Update conflict resolution system





  - Modify conflict detection to use sync identifiers
  - Update conflict resolution to preserve sync identifiers
  - Implement conflict copy creation with new sync identifiers
  - Update conflict notification system
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 7.1 Write property test for conflict resolution identity preservation





  - **Property 8: Conflict Resolution Identity Preservation**
  - **Validates: Requirements 6.3**

- [x] 8. Update remote storage integration





  - Modify DynamoDB schema to use syncId as partition key
  - Update document upload/download to use sync identifiers
  - Create global secondary index on userId for user queries
  - Update remote document operations to use sync identifiers
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [x] 9. Update API contracts and interfaces





  - Modify sync service methods to accept sync identifiers
  - Update sync event payloads to include sync identifiers
  - Update error handling to reference sync identifiers
  - Create API documentation for sync identifier requirements
  - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_

- [x] 9.1 Write property test for API sync identifier consistency






  - **Property 9: API Sync Identifier Consistency**
  - **Validates: Requirements 14.1, 14.3**

- [x] 10. Implement validation and error handling





  - Add sync identifier validation throughout the system
  - Implement error handling for invalid sync identifiers
  - Add validation for duplicate sync identifiers
  - Create error messages that reference sync identifiers
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 10.1 Write property test for validation rejection





  - **Property 10: Validation Rejection**
  - **Validates: Requirements 9.2**

- [x] 11. Add analytics and monitoring




  - Implement sync identifier usage tracking
  - Add sync operation logging with sync identifiers
  - Add metrics for documents with/without sync identifiers
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 12. Implement backward compatibility




  - Disable legacy matching logic when all documents have sync identifiers
  - Create sync identifier status indicators
  - _Requirements: 11.1, 11.2_

- [x] 13. Update sync state management





  - Modify sync state updates to use sync identifiers
  - Update sync state queries and filtering
  - Implement sync state event emission with sync identifiers
  - Add sync state history tracking
  - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_

- [x] 14. Checkpoint - Ensure all tests pass





  - Ensure all tests pass, ask the user if questions arise.

- [x] 15. Write integration tests






  - Create end-to-end sync tests with sync identifiers
  - Test conflict resolution workflows
  - Test file attachment sync with new path structure
  - _Requirements: 15.2, 15.3_

- [x] 16. Write unit tests for comprehensive coverage













  - Test sync identifier generation and validation
  - Test document matching using sync identifiers
  - Test sync operations with sync identifiers
  - _Requirements: 15.1, 15.4_

- [x] 17. Write property-based tests






  - Implement property tests for sync identifier uniqueness and format
  - _Requirements: 15.5_

- [x] 18. Final validation and deployment preparation





  - Run complete test suite including property-based tests
  - Validate data integrity
  - Create deployment documentation
  - Prepare monitoring and alerting for production deployment

- [x] 19. Final Checkpoint - Make sure all tests are passing





  - Ensure all tests pass, ask the user if questions arise.