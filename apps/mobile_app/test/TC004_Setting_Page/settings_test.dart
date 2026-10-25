import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/edit_profile_screen.dart';
import 'package:mobile_app/screens/profile_screen.dart';
import 'package:mobile_app/screens/saved_outfits_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUpTestApp();
  late TestEnvironment env;

  setUp(() async {
    env = TestEnvironment();
    await env.seedProfile();
    env.registerAuth();
  });

  Future<void> openProfile(WidgetTester tester) async {
    await pumpTestApp(
      tester,
      ProfileScreen(auth: env.auth, firestore: env.firestore),
      pages: [destinationPage('/login')],
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester) async {
    await openProfile(tester);
    await tapVisible(tester, find.text('Edit Profile'));
    expect(find.byType(EditProfileScreen), findsOneWidget);
  }

  group('TC004 Settings (Profile)', () {
    testAppWidgets('shows saved identity, body metrics, and settings', (
      tester,
    ) async {
      await openProfile(tester);
      for (final text in [
        'Alex',
        testEmail,
        '170 cm',
        '65 kg',
        'Rectangle',
        'My Outfits',
        'Edit Profile',
        'Change Password',
        'Theme',
        'Log Out',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
    });

    testAppWidgets('signed-out users are asked to log in again', (
      tester,
    ) async {
      await env.auth.signOut();
      await openProfile(tester);
      expect(find.text('Please log in again.'), findsOneWidget);
      expect(find.text('Log Out'), findsNothing);
    });

    testAppWidgets('missing profile fields show defaults', (tester) async {
      await env.profile.set({'name': 'Alex'});
      await openProfile(tester);
      expect(find.text('Not set cm'), findsOneWidget);
      expect(find.text('Not set kg'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
    });

    testAppWidgets('My Outfits opens saved outfits with the current user', (
      tester,
    ) async {
      await openProfile(tester);
      await tapVisible(tester, find.text('My Outfits'));
      expect(find.byType(SavedOutfitsScreen), findsOneWidget);
      expect(find.textContaining('No saved outfits yet.'), findsOneWidget);
    });

    testAppWidgets('change password sends reset email to the signed-in user', (
      tester,
    ) async {
      await openProfile(tester);
      await tapVisible(tester, find.text('Change Password'));
      expect(env.auth.resetEmails, [testEmail]);
      expect(
        find.text('Password reset link sent to your email.'),
        findsOneWidget,
      );
    });

    testAppWidgets('Theme explains its current Coming Soon status', (
      tester,
    ) async {
      await openProfile(tester);
      await tapVisible(tester, find.text('Theme'));
      expect(find.text('Dark mode is under construction'), findsOneWidget);
    });

    testAppWidgets('logout clears authentication and opens login', (
      tester,
    ) async {
      await openProfile(tester);
      await tapVisible(tester, find.text('Log Out'));
      expect(env.auth.currentUser, isNull);
      expect(find.text('Destination: /login'), findsOneWidget);
    });

    testAppWidgets('Edit Profile loads saved values', (tester) async {
      await openEditor(tester);
      expect(tester.widget<TextField>(field('Name')).controller!.text, 'Alex');
      expect(
        tester.widget<TextField>(field('Height (cm)')).controller!.text,
        '170',
      );
      expect(
        tester.widget<TextField>(field('Weight (kg)')).controller!.text,
        '65',
      );
      expect(find.text('Rectangle'), findsOneWidget);
    });

    for (final invalid in [
      (label: 'Name', value: '   '),
      (label: 'Height (cm)', value: 'not a number'),
      (label: 'Height (cm)', value: '0'),
      (label: 'Weight (kg)', value: '-1'),
    ]) {
      testAppWidgets(
        'invalid ${invalid.label}: ${invalid.value} is not saved',
        (tester) async {
          await openEditor(tester);
          final before = (await env.profile.get()).data();
          await tester.enterText(field(invalid.label), invalid.value);
          await tapVisible(tester, find.text('Save Changes'));
          expect(
            find.text('Enter a name and valid height and weight.'),
            findsOneWidget,
          );
          expect((await env.profile.get()).data(), before);
          expect(find.byType(EditProfileScreen), findsOneWidget);
        },
      );
    }

    testAppWidgets('valid profile edits persist and return to Profile', (
      tester,
    ) async {
      await openEditor(tester);
      await tester.enterText(field('Name'), '  Jamie  ');
      await tester.enterText(field('Height (cm)'), ' 175.5 ');
      await tester.enterText(field('Weight (kg)'), ' 70 ');
      await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
      await tapVisible(tester, find.text('Pear').last);
      await tapVisible(tester, find.text('Save Changes'));
      final data = (await env.profile.get()).data()!;
      expect(data['name'], 'Jamie');
      expect(data['height'], '175.5');
      expect(data['weight'], '70');
      expect(data['bodyType'], 'Pear');
      expect(data['isProfileComplete'], isTrue);
      expect(data['gender'], 'Prefer not to say');
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('Jamie'), findsOneWidget);
    });
  });
}
