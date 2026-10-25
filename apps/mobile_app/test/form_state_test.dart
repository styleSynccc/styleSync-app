import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/screens/signup_screen.dart';
import 'package:mobile_app/screens/user_setup_screen.dart';
import 'package:mobile_app/services/auth_controller.dart';
import 'package:mobile_app/services/user_controller.dart';

class FakeAuth extends Fake implements FirebaseAuth {}

class FakeFirestore extends Fake implements FirebaseFirestore {}

class FakeStorage extends Fake implements FirebaseStorage {}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(AuthController(auth: FakeAuth(), firestore: FakeFirestore()));
  });
  tearDown(() => Get.reset());

  for (final signup in [false, true]) {
    testWidgets(
      '${signup ? 'sign-up' : 'login'} keeps typed fields after parent rebuild',
      (tester) async {
        late StateSetter update;
        await tester.pumpWidget(
          GetMaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return signup ? SignUpScreen() : LoginScreen();
              },
            ),
          ),
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(
          fields.at(0),
          signup ? 'Test name' : 'test@example.com',
        );
        await tester.enterText(
          fields.at(1),
          signup ? 'test@example.com' : 'test-password',
        );
        update(() {});
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextFormField>(fields.at(0)).controller!.text,
          signup ? 'Test name' : 'test@example.com',
        );
        expect(
          tester.widget<TextFormField>(fields.at(1)).controller!.text,
          signup ? 'test@example.com' : 'test-password',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('twin setup keeps height, weight and preferences after rebuild', (
    tester,
  ) async {
    final controller = UserController(
      auth: FakeAuth(),
      firestore: FakeFirestore(),
      storage: FakeStorage(),
    );
    late StateSetter update;
    await tester.pumpWidget(
      GetMaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return UserSetupScreen(controller: controller);
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), '170');
    await tester.enterText(find.byType(TextField).at(1), '65.5');
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Casual'));
    await tester.tap(find.widgetWithText(FilterChip, 'Casual'));
    update(() {});
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
      '170',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
      '65.5',
    );
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Casual'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
