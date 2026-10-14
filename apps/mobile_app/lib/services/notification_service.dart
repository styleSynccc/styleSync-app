import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

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
      // UTC is a safe fallback if a platform reports an unknown zone.
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

  Future<bool> scheduleOutfitReminder({
    required int id,
    required DateTime reminderAt,
    required int itemCount,
  }) async {
    if (!await requestPermission()) return false;

    final scheduled = tz.TZDateTime(
      tz.local,
      reminderAt.year,
      reminderAt.month,
      reminderAt.day,
      reminderAt.hour,
      reminderAt.minute,
    );
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return false;

    await _plugin.zonedSchedule(
      id: id,
      title: 'Your planned outfit is ready',
      body:
          'You selected $itemCount ${itemCount == 1 ? 'item' : 'items'} for today.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
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
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '/planner',
    );
    return true;
  }

  Future<void> cancel(int id) async {
    await initialize();
    if (!kIsWeb) await _plugin.cancel(id: id);
  }
}
