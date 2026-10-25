import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/screens/outfit_creator_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUpTestApp();
  late TestEnvironment env;

  setUp(() async {
    env = TestEnvironment();
    await env.seedProfile();
    await env.registerCloset();
  });

  Future<void> openHome(WidgetTester tester) async {
    await pumpTestApp(
      tester,
      HomeScreen(auth: env.auth, firestore: env.firestore),
      pages: [
        for (final route in ['/profile', '/try-on', '/inspo', '/planner'])
          destinationPage(route),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('TC003 Home Page', () {
    testAppWidgets('welcomes the saved user and shows an empty closet', (
      tester,
    ) async {
      await openHome(tester);
      expect(find.text('Welcome,'), findsOneWidget);
      expect(find.text('Alex!'), findsOneWidget);
      expect(find.text('My Closet'), findsOneWidget);
      expect(find.text('0 Items'), findsOneWidget);
      expect(find.textContaining('Your closet is empty.'), findsOneWidget);
    });

    testAppWidgets('missing profile uses the default greeting', (tester) async {
      await env.profile.delete();
      await openHome(tester);
      expect(find.text('User!'), findsOneWidget);
    });

    final navigation = {
      Icons.person: '/profile',
      Icons.face_retouching_natural: '/try-on',
      Icons.auto_awesome: '/inspo',
      Icons.calendar_month: '/planner',
    };
    for (final entry in navigation.entries) {
      testAppWidgets('${entry.value} navigation opens the correct route', (
        tester,
      ) async {
        await openHome(tester);
        await tapVisible(tester, find.byIcon(entry.key));
        expect(find.text('Destination: ${entry.value}'), findsOneWidget);
      });
    }

    testAppWidgets('home tab keeps the home screen visible', (tester) async {
      await openHome(tester);
      await tapVisible(tester, find.byIcon(Icons.home));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Alex!'), findsOneWidget);
    });

    testAppWidgets('center button opens the real Outfit Creator', (
      tester,
    ) async {
      await openHome(tester);
      await tapVisible(tester, find.byType(FloatingActionButton));
      expect(find.byType(OutfitCreatorScreen), findsOneWidget);
      expect(
        find.text('Choose items below to build an outfit'),
        findsOneWidget,
      );
    });
  });
}
