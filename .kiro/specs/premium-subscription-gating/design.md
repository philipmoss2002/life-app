# Design Document: Premium Subscription Gating

## Overview

This design implements subscription-based access control for cloud synchronization features in the household documents application. The system allows all users to access core document management functionality with local storage, while restricting AWS cloud synchronization to users with active premium subscriptions. The design integrates with existing authentication, sync, and subscription services, leveraging in-app purchase platforms (Google Play and App Store) for subscription verification.

The key principle is graceful degradation: non-subscribed users experience full local functionality, while subscribed users gain additional cloud backup and multi-device sync capabilities. The system maintains data integrity and user experience during subscription state transitions.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  Document    │  │ Subscription │  │   Settings   │     │
│  │   Screens    │  │    Status    │  │    Screen    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                     Service Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Subscription │  │     Sync     │  │     Auth     │     │
│  │   Service    │◄─┤   Service    │◄─┤   Service    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                  │                                 │
│         │          ┌──────────────┐                         │
│         │          │   Document   │                         │
│         │          │ Sync Service │                         │
│         │          └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
         │                   │
┌────────┴────────┐  ┌──────┴──────────────────────────────┐
│   In-App        │  │      Data Layer                      │
│   Purchase      │  │  ┌──────────────┐  ┌──────────────┐ │
│   Platform      │  │  │  Document    │  │     AWS      │ │
│  (Google/Apple) │  │  │  Repository  │  │   Services   │ │
└─────────────────┘  │  └──────────────┘  └──────────────┘ │
                     │         │                  │          │
                     │  ┌──────┴──────┐    ┌──────┴──────┐  │
                     │  │   SQLite    │    │  S3/DynamoDB│  │
                     │  │   Database  │    │             │  │
                     │  └─────────────┘    └─────────────┘  │
                     └─────────────────────────────────────┘
```

### Component Interaction Flow

1. **Subscription Check Flow**:
   - User performs action (create/edit/delete document)
   - Sync Service queries Subscription Service for status
   - Subscription Service returns cached or fresh status
   - Sync Service decides whether to perform cloud sync

2. **Subscription Status Update Flow**:
   - User opens subscription status screen or restores purchases
   - Subscription Service queries In-App Purchase Platform
   - Platform returns subscription details
   - Subscription Service updates local cache and broadcasts status change
   - UI components update to reflect new status

3. **Document Operation Flow**:
   - User performs document operation
   - Document Repository saves to local SQLite
   - Sync Service checks subscription status
   - If subscribed: initiate cloud sync to AWS
   - If not subscribed: skip cloud sync, operation complete

## Components and Interfaces

### 1. Subscription Service (Enhanced)

**Responsibilities**:
- Query in-app purchase platforms for subscription status
- Cache subscription status with 5-minute TTL
- Broadcast subscription status changes
- Handle purchase restoration
- Provide subscription status to other services

**Key Methods**:
```dart
class SubscriptionService {
  // Check if user has active subscription (uses cache)
  Future<bool> hasActiveSubscription();
  
  // Get detailed subscription status
  Future<SubscriptionStatus> getSubscriptionStatus();
  
  // Force refresh from platform (bypass cache)
  Future<void> refreshSubscriptionStatus();
  
  // Restore previous purchases
  Future<void> restorePurchases();
  
  // Stream of subscription status changes
  Stream<SubscriptionStatus> get subscriptionChanges;
  
  // Clear cache (for testing/debugging)
  void clearCache();
}
```

**Caching Strategy**:
- Cache subscription status for 5 minutes
- Cache includes: status, expiration date, last check timestamp
- Cache invalidated on: manual refresh, purchase completion, app restart
- Cache shared across all service instances (singleton pattern)

### 2. Sync Service (Modified)

**Responsibilities**:
- Coordinate document synchronization
- Check subscription status before cloud operations
- Handle subscription state transitions
- Maintain local operations regardless of subscription

**Key Methods**:
```dart
class SyncService {
  // Perform sync with subscription check
  Future<SyncResult> performSync();
  
  // Sync specific document (checks subscription)
  Future<void> syncDocument(String syncId);
  
  // Sync all pending documents (for new subscribers)
  Future<void> syncPendingDocuments();
  
  // Check if sync is allowed for current user
  Future<bool> _isSyncAllowed();
}
```

**Modified Behavior**:
- Before any cloud operation, check `hasActiveSubscription()`
- If not subscribed: skip cloud sync, log reason, return success
- If subscribed: proceed with existing sync logic
- Local operations always proceed regardless of subscription

### 3. Subscription Status Screen (Enhanced)

**Responsibilities**:
- Display current subscription status
- Show expiration date for active subscriptions
- Provide restore purchases functionality
- Navigate to platform store for management
- Display visual indicators of sync capability

**UI Components**:
- Status card with gradient background (color-coded by status)
- Expiration date display
- Restore purchases button
- Manage subscription button (platform-specific)
- Subscription details section
- Info box with platform-specific instructions

### 4. Subscription Gating Middleware

**New Component**

**Responsibilities**:
- Intercept sync operations
- Enforce subscription requirements
- Log gating decisions
- Provide consistent gating logic across services

**Interface**:
```dart
class SubscriptionGatingMiddleware {
  final SubscriptionService _subscriptionService;
  
  // Check if operation is allowed
  Future<bool> canPerformCloudSync();
  
  // Get reason for denial (for logging)
  String getDenialReason();
  
  // Execute operation with gating
  Future<T> executeWithGating<T>({
    required Future<T> Function() cloudOperation,
    required Future<T> Function() localOperation,
  });
}
```

### 5. Subscription Status Notifier

**New Component**

**Responsibilities**:
- Listen for subscription status changes
- Notify UI components of changes
- Trigger sync for newly subscribed users
- Update visual indicators

**Interface**:
```dart
class SubscriptionStatusNotifier extends ChangeNotifier {
  SubscriptionStatus _status;
  DateTime? _expirationDate;
  
  // Current status
  SubscriptionStatus get status => _status;
  
  // Is cloud sync enabled
  bool get isCloudSyncEnabled;
  
  // Initialize and listen for changes
  Future<void> initialize();
  
  // Handle status change
  void _onStatusChanged(SubscriptionStatus newStatus);
}
```

## Data Models

### Subscription Status Cache

```dart
class SubscriptionStatusCache {
  final SubscriptionStatus status;
  final DateTime? expirationDate;
  final DateTime lastChecked;
  final String? planId;
  
  bool get isExpired => 
    DateTime.now().difference(lastChecked) > Duration(minutes: 5);
  
  bool get hasActiveSubscription => 
    status == SubscriptionStatus.active;
}
```

### Sync Decision

```dart
class SyncDecision {
  final bool shouldSync;
  final String reason;
  final SubscriptionStatus subscriptionStatus;
  
  SyncDecision.allowed(this.subscriptionStatus)
    : shouldSync = true,
      reason = 'Active subscription';
  
  SyncDecision.denied(this.subscriptionStatus, this.reason)
    : shouldSync = false;
}
```

### Subscription Status (Existing - Enhanced)

The existing `SubscriptionStatus` enum will be used:
```dart
enum SubscriptionStatus {
  active,      // Active subscription, cloud sync enabled
  expired,     // Expired subscription, cloud sync disabled
  gracePeriod, // Grace period, cloud sync still enabled
  none,        // No subscription, cloud sync disabled
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Local operations independence
*For any* user without an active subscription, all document CRUD operations (create, read, update, delete) should complete successfully using only local storage, without attempting cloud synchronization.
**Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**

### Property 2: Subscribed user cloud sync initiation
*For any* user with an active subscription, all document CRUD operations should save to local storage AND initiate cloud synchronization to AWS services.
**Validates: Requirements 2.1, 2.2, 2.3, 2.4**

### Property 3: Sync state consistency
*For any* document that completes cloud synchronization successfully, the sync state should be updated to "synced" in the local database.
**Validates: Requirements 2.5**

### Property 4: Subscription status query on sync
*For any* sync operation initiated by the Sync Service, the service should query the Subscription Service for current subscription status before proceeding with cloud operations.
**Validates: Requirements 5.1**

### Property 5: Active subscription allows sync
*For any* sync operation where subscription status is active, the Sync Service should proceed with cloud synchronization operations.
**Validates: Requirements 5.2**

### Property 6: Inactive subscription blocks sync
*For any* sync operation where subscription status is not active, the Sync Service should skip cloud synchronization operations while continuing local storage operations.
**Validates: Requirements 5.3, 5.4**

### Property 7: Subscription activation triggers pending sync
*For any* subscription status change from inactive to active, the application should initiate cloud synchronization for all documents with pending upload status.
**Validates: Requirements 5.5, 10.1, 10.2**

### Property 8: Data retention after expiration
*For any* subscription that expires, all documents in local storage should remain accessible and editable.
**Validates: Requirements 6.1, 6.3**

### Property 9: Sync prevention after expiration
*For any* subscription that expires, new cloud sync operations should be prevented while local operations continue.
**Validates: Requirements 6.2**

### Property 10: Sync resumption after renewal
*For any* expired subscription that is renewed, cloud sync operations should resume for all documents.
**Validates: Requirements 6.5**

### Property 11: Visual indicator consistency
*For any* subscription status, the UI should display visual indicators that accurately reflect whether cloud sync is enabled or disabled.
**Validates: Requirements 7.2, 7.3, 7.4**

### Property 12: UI responsiveness to status changes
*For any* subscription status change, all visual indicators should update within 2 seconds.
**Validates: Requirements 7.5**

### Property 13: Platform status reflection
*For any* subscription status check after a platform-side change (cancellation or renewal), the Subscription Service should reflect the updated status.
**Validates: Requirements 8.4, 8.5**

### Property 14: Subscription status caching
*For any* subscription status check within 5 minutes of the previous check, the Subscription Service should return the cached status without querying the platform.
**Validates: Requirements 9.1**

### Property 15: Cache expiration query
*For any* subscription status check when the cache is older than 5 minutes, the Subscription Service should query the In-App Purchase Platform for updated status.
**Validates: Requirements 9.2**

### Property 16: Sync uses cached status
*For any* sync operation, the Sync Service should use the cached subscription status without triggering a new platform query.
**Validates: Requirements 9.4**

### Property 17: Manual refresh bypasses cache
*For any* manual subscription status refresh, the Subscription Service should bypass the cache and query the In-App Purchase Platform directly.
**Validates: Requirements 9.5**

### Property 18: Metadata preservation during sync
*For any* document synced to the cloud, the original metadata (including creation date, title, category) should be preserved exactly.
**Validates: Requirements 10.3**

### Property 19: Purchase restoration status update
*For any* purchase restoration that returns an active subscription from the platform, the local subscription status should be updated to active.
**Validates: Requirements 4.1, 4.2**

### Property 20: Purchase restoration no subscription
*For any* purchase restoration that returns no active subscriptions from the platform, the local subscription status should be updated to none.
**Validates: Requirements 4.3**

## Error Handling

### Subscription Service Errors

1. **Platform Query Failure**:
   - Retry with exponential backoff (3 attempts)
   - If all retries fail, use cached status if available
   - If no cache, assume no subscription (fail-safe)
   - Log error for monitoring

2. **Cache Corruption**:
   - Clear corrupted cache
   - Query platform for fresh status
   - Rebuild cache from platform response

3. **Network Timeout**:
   - Use cached status if available and not expired
   - Display warning to user if cache is stale
   - Retry on next operation

### Sync Service Errors

1. **Subscription Check Failure**:
   - Log error
   - Assume no subscription (fail-safe)
   - Continue with local operations only
   - Retry subscription check on next sync

2. **Cloud Sync Failure (Subscribed User)**:
   - Mark document as error state
   - Retry with existing retry logic
   - Do not block local operations
   - Notify user of sync failure

3. **State Transition Errors**:
   - Log inconsistency
   - Attempt to reconcile state
   - If reconciliation fails, trigger full sync
   - Notify user if manual intervention needed

### UI Error Handling

1. **Status Screen Load Failure**:
   - Display cached status with warning
   - Provide manual refresh option
   - Show error message with details

2. **Purchase Restoration Failure**:
   - Display user-friendly error message
   - Suggest troubleshooting steps
   - Provide retry option
   - Log technical details

## Testing Strategy

### Unit Testing

Unit tests will verify specific behaviors and edge cases:

1. **Subscription Service Tests**:
   - Cache hit/miss scenarios
   - Cache expiration logic
   - Platform query success/failure
   - Status update broadcasting

2. **Sync Service Tests**:
   - Subscription check integration
   - Sync gating logic
   - Local-only operation flow
   - Cloud sync operation flow

3. **UI Component Tests**:
   - Status display for each subscription state
   - Button visibility and behavior
   - Navigation to platform stores
   - Visual indicator updates

### Property-Based Testing

Property-based tests will verify universal properties across many inputs using the `test` package with custom generators. Each property test will run a minimum of 100 iterations.

**Test Library**: Dart `test` package with custom property-based testing utilities

**Property Test Structure**:
```dart
// Example property test structure
void main() {
  group('Property Tests', () {
    test('Property 1: Local operations independence', () async {
      // Run 100+ iterations with random documents
      for (int i = 0; i < 100; i++) {
        final doc = generateRandomDocument();
        final result = await performOperationWithoutSubscription(doc);
        expect(result.savedLocally, isTrue);
        expect(result.attemptedCloudSync, isFalse);
      }
    });
  });
}
```

**Generators**:
- Random document generator (various categories, dates, notes)
- Random file attachment generator (various sizes, types)
- Random subscription status generator
- Random timestamp generator (for cache expiration tests)

**Property Test Coverage**:
1. Property 1-6: Document operations with/without subscription
2. Property 7, 10: State transition behaviors
3. Property 8-9: Data retention and sync prevention
4. Property 11-12: UI consistency and responsiveness
5. Property 13-17: Caching and platform integration
6. Property 18-20: Metadata preservation and restoration

### Integration Testing

Integration tests will verify end-to-end flows:

1. **Subscription Lifecycle**:
   - User subscribes → documents sync to cloud
   - Subscription expires → sync stops, local continues
   - User renews → pending documents sync

2. **Multi-Device Scenario** (simulated):
   - Device A: create documents while subscribed
   - Device B: restore purchases, download documents
   - Verify data consistency

3. **Error Recovery**:
   - Network failure during sync
   - Platform query timeout
   - Cache corruption recovery

### Manual Testing Checklist

1. **Platform Integration**:
   - Test actual Google Play purchase flow
   - Test actual App Store purchase flow
   - Verify subscription management navigation
   - Test purchase restoration on fresh install

2. **UI/UX Verification**:
   - Visual indicators match subscription state
   - Status screen displays correct information
   - Notifications appear at appropriate times
   - Performance remains smooth with large document sets

3. **Edge Cases**:
   - Subscription expires while app is running
   - User subscribes while offline
   - Rapid subscription status changes
   - App backgrounded during sync

## Performance Considerations

### Caching Strategy

- **Cache Duration**: 5 minutes balances freshness with API call reduction
- **Cache Storage**: In-memory cache (singleton service)
- **Cache Invalidation**: Explicit on purchase events, app restart, manual refresh

### Sync Optimization

- **Batch Operations**: Group pending documents for efficient sync
- **Debouncing**: Prevent excessive sync triggers (existing 2-second debounce)
- **Background Sync**: Use existing background sync capabilities
- **Incremental Sync**: Only sync changed documents

### UI Performance

- **Lazy Loading**: Load subscription status asynchronously
- **Optimistic UI**: Show cached status immediately, update when fresh data arrives
- **Minimal Redraws**: Only update UI components affected by status change

## Security Considerations

### Subscription Verification

- **Platform Verification**: Rely on platform (Google/Apple) for purchase verification
- **No Client-Side Bypass**: All subscription checks server-side or platform-verified
- **Token Validation**: Validate purchase tokens/receipts through platform APIs

### Data Protection

- **Local Data**: Remains accessible regardless of subscription (user owns their data)
- **Cloud Access**: Restricted to subscribed users only
- **No Data Loss**: Subscription expiration never deletes user data

### Privacy

- **Minimal Data Collection**: Only collect subscription status, no payment details
- **Platform Handles Payment**: All payment processing through Google/Apple
- **User Control**: Users can cancel anytime through platform

## Migration Strategy

### Existing Users

1. **Grandfather Period** (Optional):
   - Existing users get 30-day grace period
   - Allows time to subscribe without losing cloud access
   - Communicate clearly via in-app notification

2. **Data Preservation**:
   - All existing cloud data remains accessible
   - No data deletion for non-subscribers
   - Download capability for users who don't subscribe

### Rollout Plan

1. **Phase 1**: Deploy subscription checking (monitoring only)
   - Log subscription status checks
   - Don't enforce gating yet
   - Monitor for issues

2. **Phase 2**: Enable gating for new users
   - New users require subscription for cloud sync
   - Existing users continue with full access
   - Monitor adoption and issues

3. **Phase 3**: Full enforcement
   - All users require subscription for cloud sync
   - Grace period ends
   - Full monitoring and support

## Future Enhancements

1. **Tiered Subscriptions**:
   - Basic: Limited cloud storage
   - Premium: Unlimited cloud storage
   - Family: Multiple user accounts

2. **Offline Subscription Verification**:
   - Cache subscription proof for offline use
   - Periodic online verification required

3. **Subscription Analytics**:
   - Track conversion rates
   - Monitor churn
   - A/B test pricing and messaging

4. **Promotional Features**:
   - Free trial period
   - Promotional codes
   - Referral bonuses
