import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezone = MethodChannel('flutter_timezone');
  late List<MethodCall> calls;
  late bool precise;
  late bool allowed;
  late String zone;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    precise = true;
    allowed = true;
    zone = 'Asia/Kuala_Lumpur';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      timezone,
      (_) async => {'identifier': zone},
    );
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      return switch (call.method) {
        'initialize' => true,
        'requestNotificationsPermission' => allowed,
        'canScheduleExactNotifications' => precise,
        'requestExactAlarmsPermission' => precise,
        _ => null,
      };
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notifications, null);
    messenger.setMockMethodCallHandler(timezone, null);
  });

  test(
    'Malaysian 10:11 PM is scheduled at 10:11 PM, with exact timing',
    () async {
      final service = NotificationService.forTesting();
      await service.initialize();
      final selected = tz.TZDateTime(
        tz.getLocation('Asia/Kuala_Lumpur'),
        2030,
        10,
        25,
        22,
        11,
      );
      final status = await service.scheduleOutfitReminder(
        id: 1,
        reminderAt: selected,
        itemCount: 2,
      );
      final payload =
          calls.singleWhere((call) => call.method == 'zonedSchedule').arguments
              as Map;
      expect(status, ReminderScheduleStatus.exact);
      expect(payload['timeZoneName'], 'Asia/Kuala_Lumpur');
      expect(payload['scheduledDateTime'], startsWith('2030-10-25T22:11:00'));
      expect(
        (payload['platformSpecifics'] as Map)['scheduleMode'],
        'exactAllowWhileIdle',
      );
    },
  );

  test(
    'unknown timezone fallback preserves the instant instead of shifting eight hours',
    () async {
      zone = 'Unknown/Device';
      final service = NotificationService.forTesting();
      await service.initialize();
      final selected = tz.TZDateTime(
        tz.getLocation('Asia/Kuala_Lumpur'),
        2030,
        10,
        25,
        22,
        11,
      );
      await service.scheduleOutfitReminder(
        id: 2,
        reminderAt: selected,
        itemCount: 1,
      );
      final payload =
          calls.singleWhere((call) => call.method == 'zonedSchedule').arguments
              as Map;
      expect(payload['timeZoneName'], 'Etc/UTC');
      expect(payload['scheduledDateTime'], startsWith('2030-10-25T14:11:00'));
    },
  );

  test('denied exact access uses approximate timing and reports it', () async {
    precise = false;
    final status = await NotificationService.forTesting()
        .scheduleOutfitReminder(
          id: 3,
          reminderAt: DateTime.utc(2030),
          itemCount: 1,
        );
    expect(status, ReminderScheduleStatus.approximate);
    final payload =
        calls.singleWhere((call) => call.method == 'zonedSchedule').arguments
            as Map;
    expect(
      (payload['platformSpecifics'] as Map)['scheduleMode'],
      'inexactAllowWhileIdle',
    );
  });

  test('disabled notifications and past times do not create alarms', () async {
    allowed = false;
    final service = NotificationService.forTesting();
    expect(
      await service.scheduleOutfitReminder(
        id: 4,
        reminderAt: DateTime.utc(2030),
        itemCount: 1,
      ),
      ReminderScheduleStatus.notificationsDisabled,
    );
    allowed = true;
    expect(
      await service.scheduleOutfitReminder(
        id: 4,
        reminderAt: DateTime.utc(2000),
        itemCount: 1,
      ),
      ReminderScheduleStatus.timePassed,
    );
    expect(calls.where((call) => call.method == 'zonedSchedule'), isEmpty);
  });
}
