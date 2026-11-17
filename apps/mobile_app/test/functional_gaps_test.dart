// Isolated functional checks. Firebase, the picker, and HTTP are faked; no live writes.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_app/config/generation_config.dart';
import 'package:mobile_app/screens/inspo_mirror_screen.dart';
import 'package:mobile_app/screens/login_screen.dart';
import 'package:mobile_app/screens/signup_screen.dart';
import 'package:mobile_app/screens/user_setup_screen.dart';
import 'package:mobile_app/services/ai_service.dart';
import 'package:mobile_app/services/auth_controller.dart';
import 'package:mobile_app/services/user_controller.dart';
import 'package:mobile_app/widgets/outfit_preview.dart';

class _Firestore extends Fake implements FirebaseFirestore {}

class _Storage extends Fake implements FirebaseStorage {}

class _Auth extends Fake implements FirebaseAuth {}

class _SubmissionController extends AuthController {
  _SubmissionController() : super(auth: _Auth(), firestore: _Firestore());
  List<String>? registration;
  List<String>? credentials;

  @override
  Future<void> register(
    String name,
    String email,
    String password,
    String gender,
  ) async {
    registration = [name, email, password, gender];
  }

  @override
  Future<void> login(String email, String password) async {
    credentials = [email, password];
  }
}

class _RejectingAuth extends Fake implements FirebaseAuth {
  int registrations = 0;
  int logins = 0;

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    registrations++;
    throw FirebaseAuthException(
      code: 'email-already-in-use',
      message: 'This test email is already registered.',
    );
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    logins++;
    throw FirebaseAuthException(
      code: 'wrong-password',
      message: 'The test password is incorrect.',
    );
  }
}

class _InspoApi extends AiService {
  int generations = 0;
  @override
  Future<List<dynamic>> listTwins() async => [];

  @override
  Future<Map<String, dynamic>> createInspoMirror({
    required String twinId,
    required Uint8List bytes,
    required String filename,
    // No invocation should occur in the cancellation test.
    GenerationMode mode = GenerationMode.quality,
  }) async {
    generations++;
    throw StateError('No generation is allowed in this test.');
  }
}

final _screenKey = GlobalKey();

Future<void> _show(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _screenKey,
      child: GetMaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _screenshot(WidgetTester tester, String relative) async {
  // This is an actual widget render, not an Android/device screenshot.
  final boundary =
      _screenKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../../testing_evidence/screenshots/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    // Flutter's default Ahem test font renders blocks. Load installed SDK fonts
    // only for evidence runs; ordinary test execution needs no extra assets.
    final fontDir = Platform.environment['STYLESYNC_QA_FONT_DIR'];
    if (fontDir != null) {
      for (final entry in {
        'Roboto': 'roboto-regular.ttf',
        'MaterialIcons': 'materialicons-regular.otf',
      }.entries) {
        final loader = FontLoader(entry.key);
        loader.addFont(
          File(
            '$fontDir/${entry.value}',
          ).readAsBytes().then(ByteData.sublistView),
        );
        await loader.load();
      }
    }
  });
  setUp(() => Get.testMode = true);
  tearDown(() => Get.reset());

  testWidgets(
    'TC-002 empty sign-up fields show all required errors without registration',
    (tester) async {
      final controller =
          Get.put<AuthController>(_SubmissionController())
              as _SubmissionController;
      await _show(tester, const SignUpScreen());
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Sign Up'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();
      for (final message in [
        'Please enter your name',
        'Please enter your email',
        'Please select a gender option',
        'Please enter a password',
      ]) {
        expect(find.text(message), findsOneWidget);
      }
      expect(controller.registration, isNull);
      await _screenshot(tester, 'UC-01/TC-002_empty_signup_widget.png');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TC-006 empty login fields prevent credential submission', (
    tester,
  ) async {
    final controller =
        Get.put<AuthController>(_SubmissionController())
            as _SubmissionController;
    await _show(tester, const LoginScreen());
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
    expect(controller.credentials, isNull);
    await _screenshot(tester, 'UC-02/TC-006_empty_login_widget.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TC-001 valid sign-up form forwards all details to an isolated controller',
    (tester) async {
      final controller =
          Get.put<AuthController>(_SubmissionController())
              as _SubmissionController;
      await _show(tester, const SignUpScreen());
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'QA Student');
      await tester.enterText(fields.at(1), 'qa@example.invalid');
      await tester.enterText(fields.at(2), 'Synthetic!7');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prefer not to say').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Sign Up'),
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle();
      expect(controller.registration, [
        'QA Student',
        'qa@example.invalid',
        'Synthetic!7',
        'Prefer not to say',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TC-004 valid login form forwards credentials to an isolated controller',
    (tester) async {
      final controller =
          Get.put<AuthController>(_SubmissionController())
              as _SubmissionController;
      await _show(tester, const LoginScreen());
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'qa@example.invalid',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Synthetic!7');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();
      expect(controller.credentials, ['qa@example.invalid', 'Synthetic!7']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final registration in [true, false]) {
    testWidgets(
      '${registration ? 'TC-003' : 'TC-005'} Firebase rejection is shown and loading stops (fake Auth)',
      (tester) async {
        final auth = _RejectingAuth();
        final controller = AuthController(auth: auth, firestore: _Firestore());
        await _show(tester, const Scaffold(body: Text('Original screen')));
        if (registration) {
          await controller.register(
            'QA Student',
            'qa@example.invalid',
            'Synthetic!7',
            'Prefer not to say',
          );
        } else {
          await controller.login('qa@example.invalid', 'Synthetic!7');
        }
        await tester.pumpAndSettle();
        expect(
          find.text(
            registration
                ? 'This test email is already registered.'
                : 'The test password is incorrect.',
          ),
          findsOneWidget,
        );
        expect(find.text('Original screen'), findsOneWidget);
        expect(controller.isLoading.value, isFalse);
        expect(registration ? auth.registrations : auth.logins, 1);
        Get.closeAllSnackbars();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('TC-008 setup cannot continue without a body photo', (
    tester,
  ) async {
    final controller = UserController(
      auth: _Auth(),
      firestore: _Firestore(),
      storage: _Storage(),
    );
    await _show(tester, UserSetupScreen(controller: controller));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save & Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Photo required'), findsOneWidget);
    expect(find.text('Choose a clear full-body photo first.'), findsOneWidget);
    expect(controller.isLoading.value, isFalse);
    await _screenshot(tester, 'UC-03/TC-008_missing_photo_widget.png');
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TC-008 controller rejects incomplete metrics before Firebase or file access',
    (tester) async {
      final controller = UserController(
        auth: _Auth(),
        firestore: _Firestore(),
        storage: _Storage(),
      );
      controller.selectedImage.value = File('never-read-invalid-profile.jpg');
      await _show(tester, const Scaffold(body: Text('Setup marker')));
      await controller.saveUserData('', '65', ['Casual']);
      await tester.pumpAndSettle();
      expect(find.text('Complete your profile'), findsOneWidget);
      expect(controller.isLoading.value, isFalse);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TC-024 cancelling inspiration picker leaves selection empty and sends no generation',
    (tester) async {
      const picker = MethodChannel('plugins.flutter.io/image_picker');
      var picks = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(picker, (call) async {
        expect(call.method, 'pickImage');
        picks++;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(picker, null));
      final api = _InspoApi();
      await _show(tester, InspoMirrorScreen(aiService: api));
      await tester.tap(find.text('Upload inspiration photo'));
      await tester.pumpAndSettle();
      expect(picks, 1);
      expect(find.text('Upload inspiration photo'), findsOneWidget);
      expect(find.text('Change inspiration photo'), findsNothing);
      await tester.scrollUntilVisible(find.text('Generate on my twin'), 200);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Generate on my twin'),
            )
            .onPressed,
        isNull,
      );
      expect(api.generations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final detailed in [false, true]) {
    testWidgets(
      'TC-036 missing saved outfit image has a ${detailed ? 'detail message' : 'thumbnail fallback'}',
      (tester) async {
        await _show(
          tester,
          Scaffold(
            body: SizedBox(
              width: 250,
              height: 300,
              child: OutfitPreview(
                data: const {'source': 'vton'},
                detailed: detailed,
              ),
            ),
          ),
        );
        if (detailed) {
          expect(
            find.text(
              'Could not load this clothing image. Check your connection and open it again.',
            ),
            findsOneWidget,
          );
        } else {
          expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
