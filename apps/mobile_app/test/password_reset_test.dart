import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_app/services/auth_controller.dart';

class ResetAuth extends Fake implements FirebaseAuth {
  int calls = 0;
  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    calls++;
  }
}

class FakeFirestore extends Fake implements FirebaseFirestore {}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  testWidgets('reset from profile does not pop the profile page', (
    tester,
  ) async {
    final auth = ResetAuth();
    final controller = AuthController(auth: auth, firestore: FakeFirestore());
    await tester.pumpWidget(
      GetMaterialApp(home: const Scaffold(body: Text('Home marker'))),
    );
    Get.to(() => const Scaffold(body: Text('Profile marker')));
    await tester.pumpAndSettle();
    await controller.resetPassword('test@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Profile marker'), findsOneWidget);
    expect(auth.calls, 1);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });

  testWidgets('login reset closes its dialog, not the underlying page', (
    tester,
  ) async {
    final controller = AuthController(
      auth: ResetAuth(),
      firestore: FakeFirestore(),
    );
    await tester.pumpWidget(
      GetMaterialApp(home: const Scaffold(body: Text('Login marker'))),
    );
    Get.dialog(const AlertDialog(content: Text('Reset dialog')));
    await tester.pumpAndSettle();
    await controller.resetPassword('test@example.com', closeDialog: true);
    await tester.pumpAndSettle();
    expect(find.text('Reset dialog'), findsNothing);
    expect(find.text('Login marker'), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });
}
