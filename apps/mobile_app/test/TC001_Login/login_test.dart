import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_app/screens/login_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUpTestApp();
  late TestEnvironment env;
  late TestAuthController controller;

  setUp(() async {
    env = TestEnvironment(signedIn: false);
    await env.seedProfile();
    controller = env.registerAuth();
  });

  Future<void> openLogin(WidgetTester tester) => pumpTestApp(
    tester,
    const LoginScreen(),
    pages: [destinationPage('/home'), destinationPage('/user-setup')],
  );

  Future<void> enterCredentials(WidgetTester tester) async {
    await tester.enterText(field('Email'), '  $testEmail  ');
    await tester.enterText(field('Password'), '  Secret!1  ');
  }

  group('TC001 Login', () {
    testAppWidgets('shows login controls and obscures the password', (
      tester,
    ) async {
      await openLogin(tester);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(field('Email'), findsOneWidget);
      expect(tester.widget<TextField>(field('Password')).obscureText, isTrue);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testAppWidgets('empty credentials show errors without signing in', (
      tester,
    ) async {
      await openLogin(tester);
      await tapVisible(tester, find.text('Login'));
      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
      expect(env.auth.loginCalls, isEmpty);
    });

    for (final email in ['alex', 'alex@example', 'alex.example.com']) {
      testAppWidgets('rejects invalid email: $email', (tester) async {
        await openLogin(tester);
        await tester.enterText(field('Email'), email);
        await tester.enterText(field('Password'), 'Secret!1');
        await tapVisible(tester, find.text('Login'));
        expect(find.text('Please enter a valid email address'), findsOneWidget);
        expect(env.auth.loginCalls, isEmpty);
      });
    }

    testAppWidgets('valid credentials are trimmed and open the home page', (
      tester,
    ) async {
      await openLogin(tester);
      await enterCredentials(tester);
      await tapVisible(tester, find.text('Login'));
      expect(env.auth.loginCalls, [(email: testEmail, password: 'Secret!1')]);
      expect(find.text('Destination: /home'), findsOneWidget);
      expect(controller.isLoading.value, isFalse);
    });

    for (final missingProfile in [false, true]) {
      testAppWidgets(
        '${missingProfile ? 'missing' : 'incomplete'} profile opens setup',
        (tester) async {
          if (missingProfile) {
            await env.profile.delete();
          } else {
            await env.profile.update({'isProfileComplete': false});
          }
          await openLogin(tester);
          await enterCredentials(tester);
          await tapVisible(tester, find.text('Login'));
          expect(find.text('Destination: /user-setup'), findsOneWidget);
        },
      );
    }

    testAppWidgets(
      'authentication failure displays an error and allows retry',
      (tester) async {
        env.auth.loginError = FirebaseAuthException(
          code: 'wrong-password',
          message: 'Incorrect email or password.',
        );
        await openLogin(tester);
        await enterCredentials(tester);
        await tapVisible(tester, find.text('Login'));
        expect(find.text('Incorrect email or password.'), findsOneWidget);
        expect(controller.isLoading.value, isFalse);
        expect(find.text('Welcome Back'), findsOneWidget);
        Get.closeAllSnackbars();
        await tester.pumpAndSettle();
        env.auth.loginError = null;
        await tapVisible(tester, find.text('Login'));
        expect(find.text('Destination: /home'), findsOneWidget);
      },
    );

    testAppWidgets('loading hides sign-in buttons until the request finishes', (
      tester,
    ) async {
      await openLogin(tester);
      controller.isLoading.value = true;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Login'), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
      controller.isLoading.value = false;
      await tester.pump();
      expect(find.text('Login'), findsOneWidget);
    });

    testAppWidgets('Google button invokes Google authentication', (
      tester,
    ) async {
      await openLogin(tester);
      await tapVisible(tester, find.text('Continue with Google'));
      expect(controller.googleSignInCalls, 1);
    });

    testAppWidgets('password reset can be cancelled without sending email', (
      tester,
    ) async {
      await openLogin(tester);
      await tapVisible(tester, find.text('Forgot Password?'));
      expect(find.text('Reset Password'), findsOneWidget);
      await tapVisible(tester, find.text('Cancel'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(env.auth.resetEmails, isEmpty);
    });

    testAppWidgets('invalid reset email is blocked', (tester) async {
      await openLogin(tester);
      await tapVisible(tester, find.text('Forgot Password?'));
      await tester.enterText(field('Enter your email'), 'invalid');
      await tapVisible(tester, find.text('Send Link'));
      expect(find.text('Please enter a valid email'), findsOneWidget);
      expect(env.auth.resetEmails, isEmpty);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testAppWidgets('valid reset email is trimmed and the dialog closes', (
      tester,
    ) async {
      await openLogin(tester);
      await tapVisible(tester, find.text('Forgot Password?'));
      await tester.enterText(field('Enter your email'), '  $testEmail  ');
      await tapVisible(tester, find.text('Send Link'));
      expect(env.auth.resetEmails, [testEmail]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Password reset link sent to your email.'),
        findsOneWidget,
      );
      expect(controller.isLoading.value, isFalse);
    });
  });
}
