# Implementation Plan

- [x] 1. Enhance Subscription Service with caching and gating logic





  - Add subscription status caching with 24 hour TTL
  - Implement `hasActiveSubscription()` method for quick checks
  - Add cache invalidation logic
  - Implement `refreshSubscriptionStatus()` for manual refresh
  - Add `clearCache()` method for testing
  - _Requirements: 9.1, 9.2, 9.5_

- [x] 1.1 Write property test for subscription status caching


  - **Property 14: Subscription status caching**
  - **Validates: Requirements 9.1**

- [x] 1.2 Write property test for cache expiration


  - **Property 15: Cache expiration query**
  - **Validates: Requirements 9.2**

- [x] 1.3 Write property test for manual refresh bypass


  - **Property 17: Manual refresh bypasses cache**
  - **Validates: Requirements 9.5**

- [x] 2. Create Subscription Gating Middleware component





  - Create new `SubscriptionGatingMiddleware` class
  - Implement `canPerformCloudSync()` method
  - Implement `getDenialReason()` for logging
  - Implement `executeWithGating()` for operation execution
  - Add comprehensive logging for gating decisions
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 2.1 Write property test for sync gating logic


  - **Property 4: Subscription status query on sync**
  - **Validates: Requirements 5.1**

- [x] 2.2 Write property test for active subscription allows sync


  - **Property 5: Active subscription allows sync**
  - **Validates: Requirements 5.2**

- [x] 2.3 Write property test for inactive subscription blocks sync


  - **Property 6: Inactive subscription blocks sync**
  - **Validates: Requirements 5.3, 5.4**

- [x] 3. Modify Sync Service to integrate subscription gating





  - Inject `SubscriptionGatingMiddleware` into `SyncService`
  - Add subscription check before all cloud sync operations in `performSync()`
  - Add subscription check in `syncDocument()`
  - Implement `syncPendingDocuments()` for new subscribers
  - Add `_isSyncAllowed()` private method
  - Ensure local operations always proceed regardless of subscription
  - Add logging for skipped sync operations
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 3.1 Write property test for local operations independence



  - **Property 1: Local operations independence**
  - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**

- [x] 3.2 Write property test for subscribed user cloud sync


  - **Property 2: Subscribed user cloud sync initiation**
  - **Validates: Requirements 2.1, 2.2, 2.3, 2.4**

- [x] 3.3 Write property test for sync uses cached status


  - **Property 16: Sync uses cached status**
  - **Validates: Requirements 9.4**

- [x] 4. Implement subscription activation sync trigger
  - Listen for subscription status changes in `SyncService`
  - Detect transition from inactive to active status
  - Query `DocumentRepository` for documents with `pendingUpload` status
  - Trigger `syncPendingDocuments()` on activation
  - Display notification with sync progress
  - _Requirements: 5.5, 10.1, 10.2, 10.4_

- [x] 4.1 Write property test for subscription activation triggers sync
  - **Property 7: Subscription activation triggers pending sync**
  - **Validates: Requirements 5.5, 10.1, 10.2**
  - **PBT Status: passed**

- [x] 4.2 Write property test for metadata preservation
  - **Property 18: Metadata preservation during sync**
  - **Validates: Requirements 10.3**
  - **PBT Status: passed**

- [x] 5. Create Subscription Status Notifier component





  - Create `SubscriptionStatusNotifier` extending `ChangeNotifier`
  - Implement `initialize()` to listen for subscription changes
  - Add `isCloudSyncEnabled` getter
  - Implement `_onStatusChanged()` handler
  - Broadcast changes to UI components
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

- [x] 5.1 Write property test for visual indicator consistency


  - **Property 11: Visual indicator consistency**
  - **Validates: Requirements 7.2, 7.3, 7.4**

- [x] 5.2 Write property test for UI responsiveness


  - **Property 12: UI responsiveness to status changes**
  - **Validates: Requirements 7.5**

- [x] 6. Enhance Subscription Status Screen





  - Update screen to use `SubscriptionStatusNotifier`
  - Add visual indicators for cloud sync status
  - Enhance status card with subscription-specific messaging
  - Add "Cloud Sync Enabled/Disabled" indicator
  - Update restore purchases flow to refresh UI
  - Add loading states during status checks
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 7.1_

- [x] 6.1 Write unit tests for subscription status screen UI states


  - Test display for each subscription status (active, expired, none, grace period)
  - Test restore purchases button behavior
  - Test manage subscription navigation
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.4, 4.5_

- [x] 7. Add subscription indicators to document screens





  - Add sync status indicator to document list screen
  - Add sync status indicator to document detail screen
  - Show "Local Only" badge for non-subscribed users
  - Show "Cloud Synced" badge for subscribed users
  - Update indicators when subscription status changes
  - _Requirements: 7.2, 7.3, 7.4_

- [x] 7.1 Write unit tests for document screen indicators


  - Test indicator display for subscribed users
  - Test indicator display for non-subscribed users
  - Test indicator updates on status change
  - _Requirements: 7.2, 7.3, 7.4_

- [x] 8. Add subscription status to settings screen



  - Add subscription status section to settings
  - Display current status (Active/Expired/None)
  - Add "View Subscription" button linking to status screen
  - Show cloud sync enabled/disabled indicator
  - _Requirements: 7.1_

- [x] 8.1 Write unit tests for settings screen subscription section




  - Test status display
  - Test navigation to subscription status screen
  - _Requirements: 7.1_

- [x] 9. Implement subscription expiration handling





  - Listen for subscription expiration events
  - Prevent new cloud sync operations when expired
  - Continue local operations when expired
  - Display notification when subscription expires
  - Ensure local data remains accessible
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 9.1 Write property test for data retention after expiration


  - **Property 8: Data retention after expiration**
  - **Validates: Requirements 6.1, 6.3**

- [x] 9.2 Write property test for sync prevention after expiration


  - **Property 9: Sync prevention after expiration**
  - **Validates: Requirements 6.2**

- [x] 10. Implement subscription renewal handling




  - Listen for subscription renewal events
  - Resume cloud sync operations when renewed
  - Trigger sync for pending documents
  - Display notification when subscription renews
  - _Requirements: 6.5_

- [x] 10.1 Write property test for sync resumption after renewal

  - **Property 10: Sync resumption after renewal**
  - **Validates: Requirements 6.5**

- [x] 11. Enhance purchase restoration flow





  - Update `restorePurchases()` to handle status updates
  - Implement proper error handling with user feedback
  - Add success/failure notifications
  - Update UI immediately after restoration
  - Trigger sync if subscription is restored
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [x] 11.1 Write property test for purchase restoration status update


  - **Property 19: Purchase restoration status update**
  - **Validates: Requirements 4.1, 4.2**

- [x] 11.2 Write property test for purchase restoration no subscription


  - **Property 20: Purchase restoration no subscription**
  - **Validates: Requirements 4.3**

- [x] 12. Implement platform store navigation





  - Add platform-specific navigation for Android (Google Play)
  - Add platform-specific navigation for iOS (App Store)
  - Handle navigation errors gracefully
  - Add logging for navigation attempts
  - _Requirements: 8.1, 8.2_

- [x] 12.1 Write unit tests for platform store navigation


  - Test Android navigation to Google Play
  - Test iOS navigation to App Store
  - _Requirements: 8.1, 8.2_

- [x] 13. Add comprehensive error handling





  - Implement retry logic for platform query failures
  - Handle cache corruption gracefully
  - Handle network timeouts with cached fallback
  - Add user-friendly error messages
  - Implement fail-safe defaults (assume no subscription on error)
  - Add detailed logging for all error scenarios
  - _Requirements: All_

- [x] 13.1 Write unit tests for error handling scenarios


  - Test platform query failure with retry
  - Test cache corruption recovery
  - Test network timeout with fallback
  - Test fail-safe defaults
  - _Requirements: All_

- [x] 14. Implement subscription status change detection





  - Poll platform for status changes on app resume
  - Detect cancellations made through platform store
  - Detect renewals made through platform store
  - Update local status when platform changes detected
  - _Requirements: 8.3, 8.4, 8.5_

- [x] 14.1 Write property test for platform status reflection


  - **Property 13: Platform status reflection**
  - **Validates: Requirements 8.4, 8.5**

- [x] 15. Add logging and analytics





  - Log all subscription status checks
  - Log all gating decisions (sync allowed/denied)
  - Log subscription state transitions
  - Log purchase restoration attempts
  - Add analytics events for subscription lifecycle
  - _Requirements: All_

- [x] 15.1 Write unit tests for logging functionality


  - Test subscription check logging
  - Test gating decision logging
  - Test state transition logging
  - _Requirements: All_

- [x] 16. Update documentation





  - Document subscription gating architecture
  - Document caching strategy
  - Document error handling approach
  - Add code comments for key methods
  - Update README with subscription feature info
  - _Requirements: All_

- [ ] 17. Checkpoint - Ensure all tests pass








  - Ensure all tests pass, ask the user if questions arise.

- [x] 18. Integration testing





  - Test complete subscription lifecycle (subscribe → use → expire → renew)
  - Test multi-device scenario (simulated)
  - Test error recovery flows
  - Test performance with large document sets
  - _Requirements: All_

- [ ] 19. Manual testing on physical devices
  - Test actual Google Play purchase flow
  - Test actual App Store purchase flow
  - Test subscription management navigation
  - Test purchase restoration on fresh install
  - Test UI/UX across different subscription states
  - Test edge cases (expiration while running, offline subscription, etc.)
  - _Requirements: All_
