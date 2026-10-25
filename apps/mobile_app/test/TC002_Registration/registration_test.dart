import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/signup_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUpTestApp();
  late TestEnvironment env;
  late TestAuthController controller;

  setUp(() {
    env = TestEnvironment(signedIn: false);
    controller = env.registerAuth();
  });

  Future<void> openRegistration(WidgetTester tester) => pumpTestApp(
    tester,
    const SignUpScreen(),
    pages: [destinationPage('/user-setup')],
  );

  Future<void> fillForm(
    WidgetTester tester, {
    String password = 'Secret!1',
    String? gender = 'Female',
  }) async {
    await tester.enterText(field('Username'), '  Alex  ');
    await tester.enterText(field('Email'), '  $testEmail  ');
    await tester.enterText(field('Password'), password);
    if (gender != null) {
      await tapVisible(tester, find.byType(DropdownButtonFormField<String>));
      await tapVisible(tester, find.text(gender).last);
    }
  }

  group('TC002 Registration', () {
    testAppWidgets('empty form reports all required fields', (tester) async {
      await openRegistration(tester);
      await tapVisible(tester, find.text('Sign Up'));
      for (final message in [
        'Please enter your name',
        'Please enter your email',
        'Please enter a password',
        'Please select a gender option',
      ]) {
        expect(find.text(message), findsOneWidget);
      }
      expect(env.auth.registrationCalls, isEmpty);
    });

    testAppWidgets('whitespace-only name and invalid email are rejected', (
      tester,
    ) async {
      await openRegistration(tester);
      await fillForm(tester);
      await tester.enterText(field('Username'), '   ');
      await tester.enterText(field('Email'), 'alex.example.com');
      await tapVisible(tester, find.text('Sign Up'));
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(env.auth.registrationCalls, isEmpty);
    });

    const invalidPasswords = {
      'Ab!1': 'Password must be at least 6 characters',
      'secret!1': 'Password must contain at least 1 uppercase letter',
      'Secret12': 'Password must contain at least 1 special character',
    };
    for (final entry in invalidPasswords.entries) {
      testAppWidgets('password rule: ${entry.value}', (tester) async {
        await openRegistration(tester);
        await fillForm(tester, password: entry.key);
        await tapVisible(tester, find.text('Sign Up'));
        expect(find.text(entry.value), findsOneWidget);
        expect(env.auth.registrationCalls, isEmpty);
      });
    }

    testAppWidgets('gender is required even when other inputs are valid', (
      tester,
    ) async {
      await openRegistration(tester);
      await fillForm(tester, gender: null);
      await tapVisible(tester, find.text('Sign Up'));
      expect(find.text('Please select a gender option'), findsOneWidget);
      expect(env.auth.registrationCalls, isEmpty);
    });

    for (final gender in ['Male', 'Female', 'Prefer not to say']) {
      testAppWidgets('valid registration saves profile with gender: $gender', (
        tester,
      ) async {
        await openRegistration(tester);
        await fillForm(tester, gender: gender);
        await tapVisible(tester, find.text('Sign Up'));
        expect(env.auth.registrationCalls, [
          (email: testEmail, password: 'Secret!1'),
        ]);
        final user = env.auth.currentUser!;
        final data =
            (await env.firestore.collection('users').doc(user.uid).get())
                .data()!;
        expect(data['name'], 'Alex');
        expect(data['email'], testEmail);
        expect(data['gender'], gender);
        expect(DateTime.tryParse(data['createdAt'] as String), isNotNull);
        expect(find.text('Destination: /user-setup'), findsOneWidget);
        expect(controller.isLoading.value, isFalse);
      });
    }

    testAppWidgets(
      'Firebase registration error preserves the form and creates no profile',
      (tester) async {
        env.auth.registrationError = FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'This email is already registered.',
        );
        await openRegistration(tester);
        await fillForm(tester);
        await tapVisible(tester, find.text('Sign Up'));
        expect(find.text('This email is already registered.'), findsOneWidget);
        expect(find.text('Create Account'), findsOneWidget);
        expect((await env.firestore.collection('users').get()).docs, isEmpty);
        expect(controller.isLoading.value, isFalse);
      },
    );

    testAppWidgets('loading hides registration and Google buttons', (
      tester,
    ) async {
      await openRegistration(tester);
      controller.isLoading.value = true;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign Up'), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testAppWidgets('Google registration button invokes authentication', (
      tester,
    ) async {
      await openRegistration(tester);
      await tapVisible(tester, find.text('Continue with Google'));
      expect(controller.googleSignInCalls, 1);
    });
  });
}
