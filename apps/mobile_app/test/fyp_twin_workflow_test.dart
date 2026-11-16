import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/screens/virtual_twin_screen.dart';
import 'package:mobile_app/services/ai_service.dart';
import 'package:mobile_app/services/user_controller.dart';
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
    'TC-007 accepted twin photo persists processed image and completed merged profile',
    (tester) async {
      var calls = 0;
      final api = AiService(
        tokenProvider: () async => 'test-token',
        client: MockClient((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(request.url.path, '/v1/twins');
          return http.Response(
            jsonEncode({
              'twinId': 'new-twin',
              'personImageB64': base64Encode(pixel),
              'metadata': {'wearsHijab': false},
            }),
            201,
          );
        }),
      );
      h.db.documents['users/$testUid'] = {
        'name': 'QA Student',
        'bodyType': 'legacy',
      };
      final controller = UserController(
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
        aiService: api,
      );
      controller.selectedImage.value = await h.imageFile(tester);
      await h.show(tester, const Scaffold(body: Text('Setup marker')));
      await tester.runAsync(
        () => controller.saveUserData('170', '65.5', ['Casual']),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        h.storage.uploads['users/$testUid/digital_twin_processed.jpg'],
        pixel,
      );
      expect(h.db.writes, ['users/$testUid']);
      final profile = h.db.documents['users/$testUid']!;
      expect(profile['name'], 'QA Student');
      expect(profile['height'], '170');
      expect(profile['weight'], '65.5');
      expect(profile['stylePreferences'], ['Casual']);
      expect(profile['twinId'], 'new-twin');
      expect(profile['isProfileComplete'], isTrue);
      expect(profile.containsKey('bodyType'), isFalse);
      expect(
        profile['digitalTwinPhotoUrl'],
        'https://qa-only.invalid/users/$testUid/digital_twin_processed.jpg',
      );
      expect(find.text('Destination /home'), findsOneWidget);
      expect(controller.isLoading.value, isFalse);
      Get.closeAllSnackbars();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final missing in ['weight', 'styles']) {
    testWidgets(
      'TC-008 missing $missing blocks profile creation before API and storage',
      (tester) async {
        var calls = 0;
        final controller = UserController(
          auth: FirebaseAuth.instance,
          firestore: FirebaseFirestore.instance,
          storage: FirebaseStorage.instance,
          aiService: AiService(
            tokenProvider: () async => 'test-token',
            client: MockClient((_) async {
              calls++;
              throw StateError('Unexpected API');
            }),
          ),
        );
        controller.selectedImage.value = File(
          'not-read-for-invalid-profile.png',
        );
        await h.show(tester, const Scaffold(body: Text('Setup marker')));
        await controller.saveUserData(
          '170',
          missing == 'weight' ? '' : '65',
          missing == 'styles' ? [] : ['Casual'],
        );
        await tester.pumpAndSettle();
        expect(find.text('Complete your profile'), findsOneWidget);
        expect(calls, 0);
        expect(h.storage.uploads, isEmpty);
        expect(h.db.writes, isEmpty);
        expect(controller.isLoading.value, isFalse);
        Get.closeAllSnackbars();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'TC-009 twin screen retrieves processed saved twin rather than fallback URL',
    (tester) async {
      await h.network(() async {
        h.db.documents['users/$testUid'] = {
          'digitalTwinPhotoUrl': 'https://qa-only.invalid/fallback.png',
        };
        h.http.responses['/v1/twins'] = {
          'success': true,
          'twins': [
            {'twinId': 'saved', 'personImageB64': base64Encode(pixel)},
          ],
        };
        await h.show(tester, const VirtualTwinScreen());
        expect(h.db.reads, ['users/$testUid']);
        expect(h.http.requests.single.uri.path, '/v1/twins');
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.image, isA<MemoryImage>());
        expect((image.image as MemoryImage).bytes, pixel);
        expect(find.text('Rotate view'), findsOneWidget);
        expect(find.text('No virtual twin yet.'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'TC-035 missing twin screen offers Create Twin without a broken image',
    (tester) async {
      await h.network(() async {
        h.http.responses['/v1/twins'] = {'success': true, 'twins': []};
        await h.show(tester, const VirtualTwinScreen());
        expect(find.text('No virtual twin yet.'), findsOneWidget);
        expect(find.text('Create Twin'), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        expect(h.db.writes, isEmpty);
        expect(tester.takeException(), isNull);
      });
    },
  );
}
