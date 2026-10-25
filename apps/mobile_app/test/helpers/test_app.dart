import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_app/services/auth_controller.dart';
import 'package:mobile_app/services/closet_controller.dart';

const testUserId = 'stylesync-test-user';
const testEmail = 'alex@example.com';
const topAsset = 'assets/images/tops/tshirt_black.png';
const secondTopAsset = 'assets/images/tops/polo_grey.png';
const pantsAsset = 'assets/images/pants/jeans_blue.png';

/// Records calls at the Firebase boundary while keeping real controller logic.
class RecordingFirebaseAuth extends MockFirebaseAuth {
  RecordingFirebaseAuth({super.signedIn, super.mockUser});

  final loginCalls = <({String email, String password})>[];
  final registrationCalls = <({String email, String password})>[];
  final resetEmails = <String>[];
  FirebaseAuthException? loginError;
  FirebaseAuthException? registrationError;
  FirebaseAuthException? resetError;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    loginCalls.add((email: email, password: password));
    if (loginError != null) throw loginError!;
    return super.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    registrationCalls.add((email: email, password: password));
    if (registrationError != null) throw registrationError!;
    return super.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resetEmails.add(email);
    if (resetError != null) throw resetError!;
    return super.sendPasswordResetEmail(email: email);
  }
}

/// The native Google account picker cannot run in a Flutter widget test.
class TestAuthController extends AuthController {
  TestAuthController({required super.auth, required super.firestore});

  int googleSignInCalls = 0;

  @override
  Future<void> signInWithGoogle() async => googleSignInCalls++;
}

/// Fails if a test unexpectedly tries to use native Firebase Storage.
class UnusedFirebaseStorage extends Fake implements FirebaseStorage {}

class TestEnvironment {
  TestEnvironment({bool signedIn = true})
    : auth = RecordingFirebaseAuth(
        signedIn: signedIn,
        mockUser: MockUser(
          uid: testUserId,
          email: testEmail,
          displayName: 'Alex',
        ),
      );

  final RecordingFirebaseAuth auth;
  final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();

  DocumentReference<Map<String, dynamic>> get profile =>
      firestore.collection('users').doc(testUserId);

  CollectionReference<Map<String, dynamic>> get clothes =>
      profile.collection('clothes');

  CollectionReference<Map<String, dynamic>> get outfits =>
      profile.collection('outfits');

  Future<void> seedProfile() => profile.set({
    'name': 'Alex',
    'height': '170',
    'weight': '65',
    'bodyType': 'Rectangle',
    'gender': 'Prefer not to say',
    'isProfileComplete': true,
  });

  TestAuthController registerAuth() =>
      Get.put<AuthController>(
            TestAuthController(auth: auth, firestore: firestore),
            permanent: true,
          )
          as TestAuthController;

  Future<ClosetController> registerCloset() async {
    final controller = Get.put(
      ClosetController(
        auth: auth,
        firestore: firestore,
        storage: UnusedFirebaseStorage(),
      ),
      permanent: true,
    );
    await controller.fetchClothes();
    return controller;
  }

  Future<void> seedClothing({
    String id = 'top-1',
    String category = 'Tops',
    String asset = topAsset,
  }) => clothes.doc(id).set({
    'category': category,
    'assetPath': asset,
    'imageUrl': '',
  });
}

/// Each test gets fresh GetX state, in-memory data, and a phone-sized viewport.
void setUpTestApp() {
  setUp(() => Get.testMode = true);
  tearDown(() async => Get.reset());
}

/// Close GetX snackbars inside the widget-test body, before Flutter checks timers.
void testAppWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    try {
      await callback(tester);
    } finally {
      Get.closeAllSnackbars();
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

Future<void> pumpTestApp(
  WidgetTester tester,
  Widget screen, {
  List<GetPage<dynamic>> pages = const [],
}) async {
  tester.view.physicalSize = const Size(600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    GetMaterialApp(
      defaultTransition: Transition.noTransition,
      home: screen,
      getPages: pages,
    ),
  );
  await tester.pump();
}

GetPage<dynamic> destinationPage(String route) => GetPage(
  name: route,
  page: () => Scaffold(body: Center(child: Text('Destination: $route'))),
);

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pump();
  // Lazy lists may revise their scroll extent after the newly exposed layout.
  await tester.ensureVisible(target);
  await tester.pump();
}
