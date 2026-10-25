import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

enum ReminderScheduleStatus {
  exact,
  approximate,
  notificationsDisabled,
  timePassed,
}

class NotificationService {
  NotificationService._();

  @visibleForTesting
  NotificationService.forTesting();

  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz_data.initializeTimeZones();
    try {
      final deviceZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(deviceZone.identifier));
    } catch (_) {
      // Keep the requested instant even if the device reports an unknown zone.
      // scheduleOutfitReminder uses TZDateTime.from, not wall-clock rebuilding.
      tz.setLocalLocation(tz.UTC);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (kIsWeb) return false;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            true;
      case TargetPlatform.iOS:
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      default:
        return false;
    }
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'outfit_reminders',
      'Outfit reminders',
      channelDescription: 'Reminders for outfits planned in StyleSync',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  Future<bool> canSchedulePreciseReminders() async {
    await initialize();
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
  }

  Future<bool> requestPreciseReminderPermission() async {
    await initialize();
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission() ??
        false;
  }

  Future<bool> showTestNotification() async {
    if (!await requestPermission()) return false;
    await _plugin.show(
      id: 2147483000,
      title: 'StyleSync test reminder',
      body: 'If you can see this, StyleSync notifications are working.',
      notificationDetails: _details,
      payload: '/planner',
    );
    return true;
  }

  Future<ReminderScheduleStatus> scheduleOutfitReminder({
    required int id,
    required DateTime reminderAt,
    required int itemCount,
  }) async {
    if (!await requestPermission()) {
      return ReminderScheduleStatus.notificationsDisabled;
    }

    // Preserve the actual selected instant. Reconstructing its hour/minute in
    // UTC shifted Malaysian 10:11 PM reminders to 6:11 AM the following day.
    final scheduled = tz.TZDateTime.from(reminderAt, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      return ReminderScheduleStatus.timePassed;
    }
    final precise = await canSchedulePreciseReminders();

    await _plugin.zonedSchedule(
      id: id,
      title: 'Your planned outfit is ready',
      body:
          'You selected $itemCount ${itemCount == 1 ? 'item' : 'items'} for today.',
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: precise
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '/planner',
    );
    return precise
        ? ReminderScheduleStatus.exact
        : ReminderScheduleStatus.approximate;
  }

  Future<void> cancel(int id) async {
    await initialize();
    if (!kIsWeb) await _plugin.cancel(id: id);
  }
}
