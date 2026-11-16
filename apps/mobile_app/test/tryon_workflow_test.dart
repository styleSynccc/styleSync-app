import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/screens/virtual_tryon_screen.dart';
import 'package:mobile_app/screens/saved_outfits_screen.dart';
import 'package:mobile_app/services/ai_service.dart';
import 'package:mobile_app/services/closet_controller.dart';
import 'support/functional_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FunctionalHarness h;
  late List<http.Request> generations;
  late AiService api;
  var twinsAvailable = true;
  setUp(() async {
    h = FunctionalHarness();
    await h.install();
    twinsAvailable = true;
    generations = [];
    final items = [
      for (final id in ['top-a', 'top-b'])
        {
          'itemId': id,
          'itemImageB64': base64Encode(pixel),
          'metadata': {'category': 'Tops'},
        },
    ];
    for (final item in items) {
      h.db.documents['users/$testUid/clothes/${item['itemId']}'] = {
        'itemId': item['itemId'],
        'category': 'Tops',
        'assetPath': garmentAsset,
      };
    }
    h.http.responses['/v1/wardrobe'] = {'success': true, 'items': items};
    api = AiService(
      tokenProvider: () async => 'test-token',
      client: MockClient((request) async {
        if (request.url.path == '/v1/twins') {
          return http.Response(
            jsonEncode({
              'success': true,
              'twins': twinsAvailable
                  ? [
                      {'twinId': 'twin', 'personImageB64': base64Encode(pixel)},
                    ]
                  : [],
            }),
            200,
          );
        }
        if (request.url.path == '/v1/wardrobe') {
          return http.Response(
            jsonEncode({'success': true, 'items': items}),
            200,
          );
        }
        expect(request.url.path, '/v1/tryon');
        generations.add(request);
        return http.Response(
          jsonEncode({'success': true, 'resultImageB64': base64Encode(pixel)}),
          201,
        );
      }),
    );
  });
  tearDown(() async {
    await h.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    Get.put(ClosetController());
    await h.show(tester, VirtualTryOnScreen(aiService: api));
  }

  Future<void> findGenerate(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Generate Virtual Try-On'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) async {
    await findGenerate(tester);
    await tester.tap(find.text('Generate Virtual Try-On'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Generate'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'TC-017 changing top before confirmation sends only final selection once',
    (tester) async {
      await h.network(() async {
        await open(tester);
        await tester.scrollUntilVisible(
          find.text('2. Choose a Top'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tops').last);
        await tester.pumpAndSettle();
        expect(generations, isEmpty);
        await generate(tester);
        expect(generations, hasLength(1));
        final body = jsonDecode(generations.single.body) as Map;
        expect(body['garmentItemIds'], ['top-b']);
        expect(body['twinId'], 'twin');
        expect(h.db.writes, isEmpty);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'TC-018 try-on without twin disables Generate and shows setup guidance',
    (tester) async {
      await h.network(() async {
        twinsAvailable = false;
        await open(tester);
        await tester.scrollUntilVisible(
          find.text('Create digital twin'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text(
            'Create a digital twin from your profile before trying on clothes.',
          ),
          findsOneWidget,
        );
        await findGenerate(tester);
        final button = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Generate Virtual Try-On'),
        );
        expect(button.onPressed, isNull);
        expect(generations, isEmpty);
        expect(h.db.writes, isEmpty);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'TC-019 TC-021 TC-034 generated result saves once and reopens in full viewer',
    (tester) async {
      await h.network(() async {
        await open(tester);
        await generate(tester);
        expect(find.text('Save Outfit'), findsOneWidget);
        final image = tester.widget<Image>(find.byType(Image).first);
        expect((image.image as MemoryImage).bytes, pixel);
        await tester.tap(find.text('Save Outfit'));
        await tester.pumpAndSettle();
        expect(find.text('Saved'), findsOneWidget);
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Saved'),
        );
        expect(button.onPressed, isNull);
        expect(h.storage.uploads, hasLength(1));
        expect(h.db.writes, hasLength(1));
        final saved = h.db.documents[h.db.writes.single]!;
        expect(saved['source'], 'vton');
        expect(saved['title'], 'Virtual Try-On');
        final storagePath = saved['storagePath'] as String;
        expect(h.storage.uploads[storagePath], pixel);
        h.http.responses['/$storagePath'] = pixel;
        Get.closeAllSnackbars();
        await tester.pumpAndSettle();
        await h.show(tester, const MyOutfitsScreen());
        await tester.tap(find.text('Virtual Try-On'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close photo'), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(h.db.writes, hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'TC-020 revised leave-generated-result-unsaved creates no liked outfit',
    (tester) async {
      await h.network(() async {
        await open(tester);
        await generate(tester);
        expect(find.text('Save Outfit'), findsOneWidget);
        await h.show(tester, const MyOutfitsScreen());
        expect(h.db.writes, isEmpty);
        expect(h.storage.uploads, isEmpty);
        expect(find.textContaining('No saved outfits yet.'), findsOneWidget);
        expect(generations, hasLength(1));
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets(
    'TC-036 unavailable remote outfit image keeps full gallery viewer usable',
    (tester) async {
      await h.network(() async {
        h.db.documents['users/$testUid/likedOutfits/missing'] = {
          'title': 'Unavailable test outfit',
          'source': 'vton',
          'createdAt': Timestamp.now(),
          'imageUrl': 'https://qa-only.invalid/missing.jpg',
        };
        h.http.responses['/missing.jpg'] = const SocketException(
          'simulated offline',
        );
        await h.show(tester, const MyOutfitsScreen());
        expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
        expect(
          h.http.requests.any((request) => request.uri.path == '/missing.jpg'),
          isTrue,
        );
        await tester.tap(find.text('Unavailable test outfit'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Could not load this clothing image. Check your connection and open it again.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Close photo'));
        await tester.pumpAndSettle();
        expect(find.text('My Outfits'), findsOneWidget);
        expect(h.db.writes, isEmpty);
        expect(tester.takeException(), isNull);
      });
    },
  );
}
