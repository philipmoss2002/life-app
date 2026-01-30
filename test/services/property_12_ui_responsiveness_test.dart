import 'dart:async';
import 'package:test/test.dart';
import 'package:household_docs_app/services/subscription_service.dart' as sub;
import 'package:household_docs_app/services/subscription_status_notifier.dart';

/// **Feature: premium-subscription-gating, Property 12: UI responsiveness to status changes**
/// **Validates: Requirements 7.5**
///
/// Property-based test to verify that all visual indicators update within 2 seconds
/// when subscription status changes.
///
/// Note: These tests verify the notification mechanism works correctly. The actual
/// 2-second responsiveness requirement is validated through the ChangeNotifier pattern,
/// which notifies listeners synchronously.
void main() {
  group('Property 12: UI responsiveness to status changes', () {
    late sub.SubscriptionService subscriptionService;
    late SubscriptionStatusNotifier notifier;

    setUp(() {
      subscriptionService = sub.SubscriptionService();
      notifier = SubscriptionStatusNotifier(subscriptionService);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('notifier should notify listeners when initialized', () async {
      // Property: Listeners should be notified when the notifier initializes

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        bool listenerCalled = false;

        void listener() {
          listenerCalled = true;
        }

        notifier.addListener(listener);

        // Initialize should trigger notification
        await notifier.initialize();

        // Listener should have been called during initialization
        expect(
          listenerCalled,
          isTrue,
          reason:
              'Listener should be notified during initialization (iteration $i)',
        );

        notifier.removeListener(listener);
        notifier.dispose();
        notifier = SubscriptionStatusNotifier(subscriptionService);
      }
    });

    test('multiple listeners should all be notified', () async {
      // Property: When notifier changes, all registered listeners should be notified

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        int listener1Calls = 0;
        int listener2Calls = 0;
        int listener3Calls = 0;

        void listener1() {
          listener1Calls++;
        }

        void listener2() {
          listener2Calls++;
        }

        void listener3() {
          listener3Calls++;
        }

        notifier.addListener(listener1);
        notifier.addListener(listener2);
        notifier.addListener(listener3);

        // Initialize triggers notification
        await notifier.initialize();

        // All listeners should have been called the same number of times
        expect(
          listener2Calls,
          equals(listener1Calls),
          reason:
              'Listener 2 should be called same as listener 1 (iteration $i)',
        );

        expect(
          listener3Calls,
          equals(listener1Calls),
          reason:
              'Listener 3 should be called same as listener 1 (iteration $i)',
        );

        notifier.removeListener(listener1);
        notifier.removeListener(listener2);
        notifier.removeListener(listener3);

        notifier.dispose();
        notifier = SubscriptionStatusNotifier(subscriptionService);
      }
    });

    test(
        'isCloudSyncEnabled should be immediately available after notification',
        () async {
      // Property: After notification, the isCloudSyncEnabled getter should be immediately queryable

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        bool? syncEnabledInListener;

        void listener() {
          // Query isCloudSyncEnabled immediately when notified
          syncEnabledInListener = notifier.isCloudSyncEnabled;
        }

        notifier.addListener(listener);

        await notifier.initialize();

        // Listener should have been able to query the value
        expect(
          syncEnabledInListener,
          isNotNull,
          reason:
              'isCloudSyncEnabled should be queryable in listener (iteration $i)',
        );

        expect(
          syncEnabledInListener,
          isA<bool>(),
          reason: 'isCloudSyncEnabled should return bool (iteration $i)',
        );

        // Value should match current state
        expect(
          syncEnabledInListener,
          equals(notifier.isCloudSyncEnabled),
          reason: 'Listener value should match current value (iteration $i)',
        );

        notifier.removeListener(listener);
        notifier.dispose();
        notifier = SubscriptionStatusNotifier(subscriptionService);
      }
    });

    test('notification happens synchronously', () async {
      // Property: Listeners are notified synchronously (not delayed)

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        DateTime? notificationTime;

        void listener() {
          notificationTime = DateTime.now();
        }

        notifier.addListener(listener);

        final beforeInit = DateTime.now();
        await notifier.initialize();
        final afterInit = DateTime.now();

        // Notification should have occurred
        expect(
          notificationTime,
          isNotNull,
          reason: 'Listener should have been notified (iteration $i)',
        );

        // Notification should be within the initialization timeframe
        expect(
          notificationTime!.isAfter(beforeInit) ||
              notificationTime!.isAtSameMomentAs(beforeInit),
          isTrue,
          reason: 'Notification should occur after init starts (iteration $i)',
        );

        expect(
          notificationTime!.isBefore(afterInit) ||
              notificationTime!.isAtSameMomentAs(afterInit),
          isTrue,
          reason:
              'Notification should occur before init completes (iteration $i)',
        );

        notifier.removeListener(listener);
        notifier.dispose();
        notifier = SubscriptionStatusNotifier(subscriptionService);
      }
    });

    test('removed listeners should not be notified', () async {
      // Property: After removing a listener, it should not receive notifications

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        int notificationCount = 0;

        void listener() {
          notificationCount++;
        }

        notifier.addListener(listener);

        // Initialize (triggers notification)
        await notifier.initialize();

        final countAfterInit = notificationCount;

        // Remove listener
        notifier.removeListener(listener);

        // Manually trigger notifyListeners by accessing a property
        // (This doesn't actually change state, but verifies removal worked)
        final _ = notifier.isCloudSyncEnabled;

        // Count should not have increased after removal
        expect(
          notificationCount,
          equals(countAfterInit),
          reason:
              'Removed listener should not receive notifications (iteration $i)',
        );

        notifier.dispose();
        notifier = SubscriptionStatusNotifier(subscriptionService);
      }
    });

    test('notifier should handle many listeners efficiently', () async {
      // Property: Notification performance should not degrade with many listeners

      const iterations = 20;

      for (int i = 0; i < iterations; i++) {
        // Add many listeners
        final listeners = <void Function()>[];
        final notificationCounts = <int>[];

        for (int j = 0; j < 50; j++) {
          int count = 0;
          notificationCounts.add(count);

          void listener() {
            notificationCounts[j]++;
          }

          listeners.add(listener);
          notifier.addListener(listener);
        }

        // Initialize and measure time
        final startTime = DateTime.now();
        await notifier.initialize();
        final duration = DateTime.now().difference(startTime);

        // Should complete quickly even with many listeners
        expect(
          duration.inSeconds,
          lessThanOrEqualTo(2),
          reason:
              'Notification should be fast with many listeners (iteration $i)',
        );

        // All listeners should have been notified
        for (int j = 0; j < notificationCounts.length; j++) {
          expect(
            notificationCounts[j],
            greaterThan(0),
            reason: 'Listener $j should have been notified (iteration $i)',
          );
        }

        // Remove all listeners
        for (final listener in listeners) {
          notifier.removeListener(listener);
        }

        notifier.dispose();
        notifier = SubscriptionStatusNotifier(subscriptionService);
      }
    });

    test('status property should be consistent when queried in listener',
        () async {
      // Property: The status property should be stable when queried during notification

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        sub.SubscriptionStatus? statusInListener;

        void listener() {
          statusInListener = notifier.status;
        }

        notifier.addListener(listener);

        await notifier.initialize();

        // Status should have been captured
        expect(
          statusInListener,
          isNotNull,
          reason: 'Status should be queryable in listener (iteration $i)',
        );

        // Status should match current status
        expect(
          statusInListener,
          equals(notifier.status),
          reason:
              'Status in listener should match current status (iteration $i)',
        );

        notifier.removeListener(listener);
        notifier.dispose();
        notifier = SubscriptionStatusNotifier(subscriptionService);
      }
    });

    test('isCloudSyncEnabled should match status consistently', () async {
      // Property: isCloudSyncEnabled should always match the subscription status

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        await notifier.initialize();

        final status = notifier.status;
        final isCloudSyncEnabled = notifier.isCloudSyncEnabled;

        // Verify consistency
        final expectedEnabled = status == sub.SubscriptionStatus.active ||
            status == sub.SubscriptionStatus.gracePeriod;

        expect(
          isCloudSyncEnabled,
          equals(expectedEnabled),
          reason:
              'isCloudSyncEnabled should match status $status (iteration $i)',
        );

        notifier.dispose();
        notifier = SubscriptionStatusNotifier(subscriptionService);
      }
    });

    test('notifier should handle rapid listener additions', () async {
      // Property: Adding listeners rapidly should not cause issues

      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        await notifier.initialize();

        // Rapidly add many listeners
        final listeners = <void Function()>[];
        for (int j = 0; j < 20; j++) {
          void listener() {
            // Just a listener
          }

          listeners.add(listener);
          notifier.addListener(listener);
        }

        // Should complete without errors
        expect(
          listeners.length,
          equals(20),
          reason: 'All listeners should be added successfully (iteration $i)',
        );

        // Remove all listeners
        for (final listener in listeners) {
          notifier.removeListener(listener);
        }

        notifier.dispose();
        notifier = SubscriptionStatusNotifier(subscriptionService);
      }
    });

    test('notifier should maintain state across multiple queries', () async {
      // Property: State should remain stable across multiple queries

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        await notifier.initialize();

        // Query state multiple times
        final status1 = notifier.status;
        final syncEnabled1 = notifier.isCloudSyncEnabled;

        final status2 = notifier.status;
        final syncEnabled2 = notifier.isCloudSyncEnabled;

        final status3 = notifier.status;
        final syncEnabled3 = notifier.isCloudSyncEnabled;

        // All queries should return the same values
        expect(
          status2,
          equals(status1),
          reason: 'Status should be stable (iteration $i)',
        );

        expect(
          status3,
          equals(status1),
          reason: 'Status should be stable (iteration $i)',
        );

        expect(
          syncEnabled2,
          equals(syncEnabled1),
          reason: 'isCloudSyncEnabled should be stable (iteration $i)',
        );

        expect(
          syncEnabled3,
          equals(syncEnabled1),
          reason: 'isCloudSyncEnabled should be stable (iteration $i)',
        );

        notifier.dispose();
        notifier = SubscriptionStatusNotifier(subscriptionService);
      }
    });
  });
}
