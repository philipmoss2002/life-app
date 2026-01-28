import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  NotificationService._init();

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(settings);

    // Request permissions for Android 13+
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> scheduleRenewalReminder(
      String syncId, String title, DateTime renewalDate) async {
    final reminderDate = renewalDate.subtract(const Duration(days: 7));

    if (reminderDate.isAfter(DateTime.now())) {
      // Use syncId hashCode to generate a consistent integer ID for the notification
      final notificationId = syncId.hashCode;

      await _notifications.zonedSchedule(
        notificationId,
        'Renewal Reminder',
        '$title renewal is due in 7 days',
        tz.TZDateTime.from(reminderDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'renewal_channel',
            'Renewal Reminders',
            channelDescription: 'Notifications for policy renewals',
            importance: Importance.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelReminder(String syncId) async {
    // Use syncId hashCode to generate the same integer ID used for scheduling
    final notificationId = syncId.hashCode;
    await _notifications.cancel(notificationId);
  }

  /// Show a notification for a sync conflict
  Future<void> showConflictNotification(
    String documentId,
    String documentTitle,
  ) async {
    // Use a unique ID based on document ID hash
    final notificationId = documentId.hashCode;

    await _notifications.show(
      notificationId,
      'Sync Conflict Detected',
      'Document "$documentTitle" has conflicting changes. Tap to resolve.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'conflict_channel',
          'Sync Conflicts',
          channelDescription: 'Notifications for synchronization conflicts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Cancel a conflict notification
  Future<void> cancelConflictNotification(String documentId) async {
    final notificationId = documentId.hashCode;
    await _notifications.cancel(notificationId);
  }

  /// Show a notification when conflicts are resolved
  Future<void> showConflictResolvedNotification(String documentTitle) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Conflict Resolved',
      'Document "$documentTitle" conflict has been resolved.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'conflict_channel',
          'Sync Conflicts',
          channelDescription: 'Notifications for synchronization conflicts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Show a notification when subscription expires
  Future<void> showSubscriptionExpiredNotification() async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Subscription Expired',
      'Your premium subscription has expired. Cloud sync is now disabled. Local documents remain accessible.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'subscription_channel',
          'Subscription Status',
          channelDescription: 'Notifications for subscription status changes',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Show a notification when subscription is renewed
  Future<void> showSubscriptionRenewedNotification(int documentCount) async {
    final message = documentCount > 0
        ? 'Your premium subscription has been renewed. Cloud sync is now enabled. Syncing $documentCount pending document${documentCount == 1 ? '' : 's'}.'
        : 'Your premium subscription has been renewed. Cloud sync is now enabled.';

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Subscription Renewed',
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'subscription_channel',
          'Subscription Status',
          channelDescription: 'Notifications for subscription status changes',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
