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
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notifications.initialize(settings);
  }

  Future<void> scheduleRenewalReminder(
      int id, String title, DateTime renewalDate) async {
    final reminderDate = renewalDate.subtract(const Duration(days: 7));

    if (reminderDate.isAfter(DateTime.now())) {
      await _notifications.zonedSchedule(
        id,
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

  Future<void> cancelReminder(int id) async {
    await _notifications.cancel(id);
  }
}
