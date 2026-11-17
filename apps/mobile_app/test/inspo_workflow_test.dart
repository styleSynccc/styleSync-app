import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/screens/inspo_mirror_screen.dart';
import 'package:mobile_app/services/ai_service.dart';
import 'support/functional_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FunctionalHarness h;
  late AiService api;
  late List<http.Request> generations;
  var twinsAvailable = true, rejectGeneration = false;
  setUp(() async {
    h = FunctionalHarness();
    await h.install();
    generations = [];
    twinsAvailable = true;
    rejectGeneration = false;
    api = AiService(
      tokenProvider: () async => 'test-token',
      client: MockClient((request) async {
        if (request.url.path == '/v1/twins') {
          return http.Response(
            jsonEncode({
              'twins': twinsAvailable
                  ? [
                      for (final id in ['twin-a', 'twin-b'])
                        {'twinId': id, 'personImageB64': base64Encode(pixel)},
                    ]
                  : [],
            }),
            200,
          );
        }
        expect(request.url.path, '/v1/inspo');
        generations.add(request);
        if (rejectGeneration) {
          return http.Response(
            jsonEncode({
              'error_type': 'TRY_ON_UNAVAILABLE',
              'message':
                  'Reference could not be processed. Choose another photo.',
            }),
            503,
          );
        }
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

  Future<void> openAndPick(WidgetTester tester) async {
    h.pickedPath = (await h.imageFile(tester)).path;
    await h.show(tester, InspoMirrorScreen(aiService: api));
    await tester.tap(find.text('Upload inspiration photo'));
    // Wait on the observable preview, allowing real local file IO to complete.
    for (
      var i = 0;
      i < 100 && find.text('Change inspiration photo').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Change inspiration photo'), findsOneWidget);
  }

  Future<void> findGenerate(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Generate on my twin'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> generate(WidgetTester tester) async {
    await findGenerate(tester);
    await tester.tap(find.text('Generate on my twin'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Generate'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'TC-022 selecting reference previews locally without uploading or generating',
    (tester) async {
      await openAndPick(tester);
      final previews = tester
          .widgetList<Image>(find.byType(Image))
          .where((i) => i.image is MemoryImage);
      expect(
        previews.any(
          (i) => (i.image as MemoryImage).bytes.length == pixel.length,
        ),
        isTrue,
      );
      expect(h.pickerCalls, hasLength(1));
      expect(generations, isEmpty);
      expect(h.db.writes, isEmpty);
      expect(h.storage.uploads, isEmpty);
      await findGenerate(tester);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Generate on my twin'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TC-024 cancelling replacement picker preserves previously selected reference',
    (tester) async {
      await openAndPick(tester);
      final previous =
          tester.widgetList<Image>(find.byType(Image)).first.image
              as MemoryImage;
      h.pickedPath = null;
      await tester.tap(find.text('Change inspiration photo'));
      await tester.pumpAndSettle();
      expect(h.pickerCalls, hasLength(2));
      expect(find.text('Change inspiration photo'), findsOneWidget);
      final current =
          tester.widgetList<Image>(find.byType(Image)).first.image
              as MemoryImage;
      expect(current.bytes, previous.bytes);
      expect(generations, isEmpty);
      expect(h.db.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TC-025 selected twin and reference generate one visible inspired result',
    (tester) async {
      await openAndPick(tester);
      await tester.scrollUntilVisible(
        find.text('Twin 2'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Twin 2'));
      await tester.pumpAndSettle();
      expect(generations, isEmpty);
      await generate(tester);
      expect(generations, hasLength(1));
      // Multipart includes binary PNG bytes; decode one-to-one for ASCII fields.
      final multipart = latin1.decode(generations.single.bodyBytes);
      expect(multipart, contains('name="twinId"\r\n\r\ntwin-b'));
      expect(multipart, contains('filename="synthetic.png"'));
      await tester.scrollUntilVisible(
        find.text('Your inspired look'),
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Your inspired look'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(h.storage.uploads, isEmpty);
      expect(h.db.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('TC-026 selected reference without twin cannot generate', (
    tester,
  ) async {
    twinsAvailable = false;
    await openAndPick(tester);
    await findGenerate(tester);
    expect(find.text('Create or edit twin'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Generate on my twin'),
          )
          .onPressed,
      isNull,
    );
    expect(generations, isEmpty);
    expect(h.db.writes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TC-027 mocked processing rejection is readable and retains reference for retry',
    (tester) async {
      rejectGeneration = true;
      await openAndPick(tester);
      await generate(tester);
      expect(generations, hasLength(1));
      expect(
        find.text('Reference could not be processed. Choose another photo.'),
        findsOneWidget,
      );
      expect(find.text('Your inspired look'), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Generate on my twin'),
            )
            .onPressed,
        isNotNull,
      );
      expect(h.db.writes, isEmpty);
      expect(h.storage.uploads, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
