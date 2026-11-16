import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_app/services/auth_controller.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/screens/signup_screen.dart';
import 'support/functional_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FunctionalHarness h;
  setUp(() async {
    h = FunctionalHarness();
    await h.install();
  });
  tearDown(() async {
    await h.dispose();
  });

  testWidgets(
    'TC-001 registration persists profile for returned uid and routes to setup',
    (tester) async {
      h.auth.user = null;
      final controller = AuthController(
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
      );
      await h.show(tester, const Scaffold(body: Text('Register marker')));
      await controller.register(
        'QA Student',
        'qa@example.invalid',
        'Synthetic!7',
        'Prefer not to say',
      );
      await tester.pumpAndSettle();
      expect(h.auth.registrations, 1);
      expect(h.db.writes, ['users/$testUid']);
      expect(
        h.db.documents['users/$testUid'],
        containsPair('name', 'QA Student'),
      );
      expect(
        h.db.documents['users/$testUid'],
        containsPair('email', 'qa@example.invalid'),
      );
      expect(
        h.db.documents['users/$testUid'],
        containsPair('gender', 'Prefer not to say'),
      );
      expect(
        h.db.documents['users/$testUid']!.containsKey('password'),
        isFalse,
      );
      expect(find.text('Destination /user-setup'), findsOneWidget);
      expect(controller.isLoading.value, isFalse);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final state in ['complete', 'incomplete', 'missing']) {
    testWidgets('TC-004 login routes $state profile after credential success', (
      tester,
    ) async {
      if (state != 'missing') {
        h.db.documents['users/$testUid'] = {
          'isProfileComplete': state == 'complete',
        };
      }
      final controller = AuthController(
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
      );
      await h.show(tester, const Scaffold(body: Text('Login marker')));
      await controller.login('qa@example.invalid', 'Synthetic!7');
      await tester.pumpAndSettle();
      expect(h.auth.logins, 1);
      expect(h.db.reads, ['users/$testUid']);
      expect(h.db.writes, isEmpty);
      expect(
        find.text(
          'Destination ${state == 'complete' ? '/home' : '/user-setup'}',
        ),
        findsOneWidget,
      );
      expect(controller.isLoading.value, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final signup in [true, false]) {
    testWidgets(
      '${signup ? 'TC-002' : 'TC-006'} malformed email cannot reach Firebase',
      (tester) async {
        Get.put(
          AuthController(
            auth: FirebaseAuth.instance,
            firestore: FirebaseFirestore.instance,
          ),
        );
        await h.show(
          tester,
          signup ? const SignUpScreen() : const LoginScreen(),
        );
        final fields = find.byType(TextFormField);
        if (signup) await tester.enterText(fields.at(0), 'QA Student');
        await tester.enterText(fields.at(signup ? 1 : 0), 'not-an-email');
        await tester.enterText(fields.at(signup ? 2 : 1), 'Synthetic!7');
        await tester.ensureVisible(
          find.widgetWithText(ElevatedButton, signup ? 'Sign Up' : 'Login'),
        );
        await tester.tap(
          find.widgetWithText(ElevatedButton, signup ? 'Sign Up' : 'Login'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Please enter a valid email address'), findsOneWidget);
        expect(h.auth.registrations, 0);
        expect(h.auth.logins, 0);
        expect(h.db.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final entry in {
    'short': ('A!1', 'Password must be at least 6 characters'),
    'no_uppercase': (
      'lower!7',
      'Password must contain at least 1 uppercase letter',
    ),
    'no_special': (
      'Uppercase7',
      'Password must contain at least 1 special character',
    ),
  }.entries) {
    testWidgets('TC-002 ${entry.key} password cannot reach Firebase', (
      tester,
    ) async {
      Get.put(
        AuthController(
          auth: FirebaseAuth.instance,
          firestore: FirebaseFirestore.instance,
        ),
      );
      await h.show(tester, const SignUpScreen());
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'QA Student');
      await tester.enterText(fields.at(1), 'qa@example.invalid');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prefer not to say').last);
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(2), entry.value.$1);
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Sign Up'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();
      expect(find.text(entry.value.$2), findsOneWidget);
      expect(h.auth.registrations, 0);
      expect(h.db.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
