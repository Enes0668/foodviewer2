import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  // ---------------------------------------------------------------------------
  // INITIALIZE
  // ---------------------------------------------------------------------------
  static Future<void> initializeNotification({
    bool requestPermissions = true,
  }) async {
    // Timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    // Android init
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
    );

    await notifications.initialize(initSettings);

    // ❗ WEB'de izin isteme → ÇÖKÜYOR
    if (!kIsWeb && Platform.isAndroid && requestPermissions) {
      await requestPermissionsAsync();
    }

    // Android Notification Channel
    if (!kIsWeb && Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'daily_channel',
        'Daily Notifications',
        description: 'Daily scheduled reminders',
        importance: Importance.max,
      );

      await notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    print("📢 NotificationService initialized");
  }

  // ---------------------------------------------------------------------------
  // PERMISSION (Only Android)
  // ---------------------------------------------------------------------------
  static Future<void> requestPermissionsAsync() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
  }

  // ---------------------------------------------------------------------------
  // IMMEDIATE NOTIFICATION (Test)
  // ---------------------------------------------------------------------------
  static Future<void> showTestNotification() async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'daily_channel',
      'Daily Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    await notifications.show(
      1,
      "Test Bildirimi",
      "Bu bildirim başarıyla çalışıyor!",
      platformDetails,
    );
  }

  // ---------------------------------------------------------------------------
  // IMMEDIATE NOTIFICATION
  // ---------------------------------------------------------------------------
  static Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'daily_channel',
      'Daily Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const platformDetails = NotificationDetails(android: androidDetails);

    await notifications.show(id, title, body, platformDetails);
  }

  // ---------------------------------------------------------------------------
  // DAILY NOTIFICATION (HER GÜN SABİT SAATTE)
  // ---------------------------------------------------------------------------
  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required int id,
  }) async {
    if (kIsWeb) return;

    final istanbul = tz.getLocation('Europe/Istanbul');
    final now = tz.TZDateTime.now(istanbul);

    tz.TZDateTime scheduleDate = tz.TZDateTime(
      istanbul,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduleDate.isBefore(now)) {
      scheduleDate = scheduleDate.add(const Duration(days: 1));
    }

    const android = AndroidNotificationDetails(
      'daily_channel',
      'Daily Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const platform = NotificationDetails(android: android);

    await notifications.zonedSchedule(
      id,
      title,
      body,
      scheduleDate,
      platform,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.wallClockTime,
    );

    print("📅 Günlük bildirim ayarlandı → $scheduleDate");
  }

  // ---------------------------------------------------------------------------
  // CANCEL ALL
  // ---------------------------------------------------------------------------
  static Future<void> cancelAll() async {
    if (kIsWeb) return;
    await notifications.cancelAll();
    print("🧹 Tüm bildirimler iptal edildi");
  }
}
