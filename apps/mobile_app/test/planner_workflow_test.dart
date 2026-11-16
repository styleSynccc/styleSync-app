import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_app/screens/outfit_planner_screen.dart';
import 'package:mobile_app/services/closet_controller.dart';
import 'support/functional_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FunctionalHarness h;
  late DateTime date;
  setUp(() async {
    h = FunctionalHarness();
    await h.install();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    date = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 2));
    h.db.documents['users/$testUid/clothes/closet-top'] = {
      'category': 'Tops',
      'assetPath': garmentAsset,
      'itemId': 'top',
    };
    Get.put(ClosetController());
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await h.dispose();
  });
  String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String input(DateTime d) => '${d.month}/${d.day}/${d.year}';

  Future<void> dateInput(WidgetTester tester) async {
    await tester.tap(find.text('Select a date to plan an outfit'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
  }

  Future<void> acceptDate(WidgetTester tester) async {
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
  }

  Future<void> chooseItems(WidgetTester tester) async {
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Save Outfit (0)'), findsOneWidget);
  }

  Future<void> selectAndSave(WidgetTester tester) async {
    await tester.tap(find.byType(Image).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Outfit (1)'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'TC-028 TC-031 selected future date stores plan and displays items with reminder',
    (tester) async {
      await h.show(tester, const OutfitPlannerScreen());
      await dateInput(tester);
      await tester.enterText(find.byType(TextField).last, input(date));
      await acceptDate(tester);
      await chooseItems(tester);
      await selectAndSave(tester);
      expect(h.db.writes, ['users/$testUid/outfitPlans/${key(date)}']);
      final plan = h.db.documents[h.db.writes.single]!;
      expect((plan['date'] as Timestamp).toDate(), date);
      expect(
        (plan['reminderAt'] as Timestamp).toDate(),
        DateTime(date.year, date.month, date.day, 8),
      );
      expect((plan['items'] as List).single['id'], 'closet-top');
      expect(find.byType(Card), findsOneWidget);
      expect(
        find.textContaining('${date.day}/${date.month}\n${date.year}'),
        findsOneWidget,
      );
      final alarm = h.notificationCalls.singleWhere(
        (call) => call.method == 'zonedSchedule',
      );
      expect(
        (alarm.arguments as Map)['scheduledDateTime'],
        startsWith('${key(date)}T08:00:00'),
      );
      await close(tester);
    },
  );

  testWidgets(
    'TC-029 changing selected date before commit writes only final date',
    (tester) async {
      await h.show(tester, const OutfitPlannerScreen());
      await dateInput(tester);
      await tester.enterText(find.byType(TextField).last, input(date));
      final finalDate = date.add(const Duration(days: 1));
      await tester.enterText(find.byType(TextField).last, input(finalDate));
      await acceptDate(tester);
      await chooseItems(tester);
      await selectAndSave(tester);
      expect(
        h.db.documents.containsKey('users/$testUid/outfitPlans/${key(date)}'),
        isFalse,
      );
      expect(h.db.writes, ['users/$testUid/outfitPlans/${key(finalDate)}']);
      expect(
        find.textContaining(
          '${finalDate.day}/${finalDate.month}\n${finalDate.year}',
        ),
        findsOneWidget,
      );
      await close(tester);
    },
  );

  for (final stage in ['date', 'time', 'items']) {
    testWidgets('TC-030 cancelling $stage selection creates no plan or alarm', (
      tester,
    ) async {
      await h.show(tester, const OutfitPlannerScreen());
      await dateInput(tester);
      if (stage != 'date') {
        await tester.enterText(find.byType(TextField).last, input(date));
        await acceptDate(tester);
      }
      if (stage == 'items') {
        await chooseItems(tester);
        await tester.tap(find.byType(Image).last);
        await tester.pumpAndSettle();
        Get.back();
      } else {
        await tester.tap(find.text('Cancel'));
      }
      await tester.pumpAndSettle();
      expect(h.db.writes, isEmpty);
      expect(
        h.notificationCalls.where((call) => call.method == 'zonedSchedule'),
        isEmpty,
      );
      expect(find.text('Upcoming Outfits'), findsOneWidget);
      expect(find.textContaining('No upcoming outfits.'), findsOneWidget);
      await close(tester);
    });
  }

  testWidgets(
    'TC-032 revised empty upcoming list explains how to create a plan',
    (tester) async {
      await h.show(tester, const OutfitPlannerScreen());
      expect(
        find.text(
          'No upcoming outfits.\nCreate a new plan above. Past plans are saved in My Outfits.',
        ),
        findsOneWidget,
      );
      expect(find.byType(Card), findsNothing);
      expect(h.db.writes, isEmpty);
      await close(tester);
    },
  );

  testWidgets(
    'TC-033 revised multiple dated cards preserve chronological date and item pairing',
    (tester) async {
      final later = date.add(const Duration(days: 1));
      for (final d in [later, date]) {
        h.db.documents['users/$testUid/outfitPlans/${key(d)}'] = {
          'date': Timestamp.fromDate(d),
          'reminderAt': Timestamp.fromDate(DateTime(d.year, d.month, d.day, 8)),
          'items': [
            {'id': key(d), 'category': 'Tops', 'assetPath': garmentAsset},
          ],
        };
      }
      await h.show(tester, const OutfitPlannerScreen());
      final cards = find.byType(Card);
      expect(cards, findsNWidgets(2));
      expect(
        find.descendant(
          of: cards.at(0),
          matching: find.textContaining(
            '${date.day}/${date.month}\n${date.year}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cards.at(1),
          matching: find.textContaining(
            '${later.day}/${later.month}\n${later.year}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cards.at(0), matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cards.at(1), matching: find.byType(Image)),
        findsOneWidget,
      );
      expect(h.db.writes, isEmpty);
      await close(tester);
    },
  );
}
