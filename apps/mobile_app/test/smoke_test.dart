import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/screens/profile_screen.dart';
import 'package:mobile_app/screens/signup_screen.dart';

import 'helpers/test_app.dart';

void main() {
  setUpTestApp();

  testAppWidgets('login, home, profile, and logout work together', (
    tester,
  ) async {
    final env = TestEnvironment(signedIn: false);
    await env.seedProfile();
    env.registerAuth();
    // Keep this controller available across the offAllNamed login transition.
    await env.registerCloset();
    await pumpTestApp(
      tester,
      const LoginScreen(),
      pages: [
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(
          name: '/home',
          page: () => HomeScreen(auth: env.auth, firestore: env.firestore),
        ),
        GetPage(
          name: '/profile',
          page: () => ProfileScreen(auth: env.auth, firestore: env.firestore),
        ),
      ],
    );
    await tester.enterText(field('Email'), testEmail);
    await tester.enterText(field('Password'), 'Secret!1');
    await tapVisible(tester, find.text('Login'));
    expect(find.text('Alex!'), findsOneWidget);
    await tapVisible(tester, find.byIcon(Icons.person));
    expect(find.text(testEmail), findsOneWidget);
    await tapVisible(tester, find.text('Log Out'));
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(env.auth.currentUser, isNull);
  });

  testAppWidgets(
    'login opens registration and the back arrow returns to login',
    (tester) async {
      final env = TestEnvironment(signedIn: false);
      env.registerAuth();
      await pumpTestApp(
        tester,
        const LoginScreen(),
        pages: [GetPage(name: '/signup', page: () => const SignUpScreen())],
      );
      await tapVisible(tester, find.text('Sign Up'));
      expect(find.text('Create Account'), findsOneWidget);
      await tapVisible(tester, find.byIcon(Icons.arrow_back));
      expect(find.text('Welcome Back'), findsOneWidget);
    },
  );
}
