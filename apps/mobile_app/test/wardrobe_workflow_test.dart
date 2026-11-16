import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/services/closet_controller.dart';
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

  for (final source in [ImageSource.gallery, ImageSource.camera]) {
    testWidgets(
      '${source == ImageSource.gallery ? 'TC-010 TC-013' : 'TC-011 TC-013'} ${source.name} clothing upload stores processed bytes and category',
      (tester) async {
        await h.network(() async {
          h.pickedPath = (await h.imageFile(tester)).path;
          h.http.responses['/v1/wardrobe'] = {
            'success': true,
            'itemId': 'processed-top',
            'itemImageB64': base64Encode(pixel),
          };
          final controller = ClosetController();
          await h.show(tester, const Scaffold(body: Text('Closet marker')));
          await tester.runAsync(
            () => controller.uploadClothingItem('Tops', source: source),
          );
          await tester.pumpAndSettle();
          expect(h.pickerCalls.single.method, 'pickImage');
          expect(
            (h.pickerCalls.single.arguments as Map)['source'],
            source.index,
          );
          expect(h.http.requests, hasLength(1));
          expect(h.http.requests.single.method, 'POST');
          expect(h.http.requests.single.uri.path, '/v1/wardrobe');
          expect(
            h.http.requests.single.body,
            contains('name="category"\r\n\r\nTops'),
          );
          expect(h.storage.uploads.keys, [
            'users/$testUid/clothes/processed-top.jpg',
          ]);
          expect(h.storage.uploads.values.single, pixel);
          expect(h.storage.contentTypes.values.single, 'image/jpeg');
          final record = h.db.documents[h.db.writes.single]!;
          expect(record['category'], 'Tops');
          expect(record['itemId'], 'processed-top');
          expect(controller.clothes.single.tryOnItemId, 'processed-top');
          expect(controller.isLoading.value, isFalse);
          Get.closeAllSnackbars();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  for (final source in [ImageSource.gallery, ImageSource.camera]) {
    testWidgets(
      'TC-012 cancelling ${source.name} clothing picker performs no IO writes',
      (tester) async {
        await h.network(() async {
          final controller = ClosetController();
          await h.show(tester, const Scaffold(body: Text('Closet marker')));
          await controller.uploadClothingItem('Tops', source: source);
          await tester.pumpAndSettle();
          expect(h.pickerCalls, hasLength(1));
          expect(
            (h.pickerCalls.single.arguments as Map)['source'],
            source.index,
          );
          expect(h.http.requests, isEmpty);
          expect(h.db.writes, isEmpty);
          expect(h.storage.uploads, isEmpty);
          expect(controller.clothes, isEmpty);
          expect(controller.isLoading.value, isFalse);
          expect(tester.takeException(), isNull);
        });
      },
    );
  }

  testWidgets(
    'TC-015 dismissing category sheet leaves closet and services unchanged',
    (tester) async {
      await h.network(() async {
        await h.show(tester, const HomeScreen());
        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ActionChip, 'Tops'));
        await tester.pumpAndSettle();
        expect(find.text('Choose Tops'), findsOneWidget);
        Get.back();
        await tester.pumpAndSettle();
        expect(find.text('Choose Tops'), findsNothing);
        expect(h.db.writes, isEmpty);
        expect(h.storage.uploads, isEmpty);
        expect(h.http.requests, isEmpty);
        expect(h.pickerCalls, isEmpty);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'TC-014 revised pre-upload category choice uses the newly selected category',
    (tester) async {
      await h.network(() async {
        await h.show(tester, const HomeScreen());
        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ActionChip, 'Tops'));
        await tester.pumpAndSettle();
        Get.back();
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ActionChip, 'Pants'));
        await tester.pumpAndSettle();
        expect(find.text('Choose Pants'), findsOneWidget);
        expect(find.text('Choose Tops'), findsNothing);
        expect(h.db.writes, isEmpty);
        expect(h.http.requests, isEmpty);
        expect(tester.takeException(), isNull);
      });
    },
  );
}
