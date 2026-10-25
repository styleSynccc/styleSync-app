import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/virtual_tryon_screen.dart';
import 'package:mobile_app/services/ai_service.dart';

import '../helpers/fake_ai_service.dart';
import '../helpers/test_app.dart';

void main() {
  setUpTestApp();
  late FakeAiService service;
  setUp(() => service = FakeAiService());

  Future<void> openTryOn(WidgetTester tester) async {
    await pumpTestApp(tester, VirtualTryOnScreen(aiService: service));
    await tester.pumpAndSettle();
  }

  Finder generateButton() =>
      find.byWidgetPredicate((widget) => widget is ElevatedButton);

  group('TC005 Virtual Try-On', () {
    testAppWidgets('shows loading while choices are being fetched', (
      tester,
    ) async {
      final pending = Completer<List<dynamic>>();
      service.pendingTwins = pending;
      await pumpTestApp(tester, VirtualTryOnScreen(aiService: service));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(service.twins);
      await tester.pumpAndSettle();
      expect(find.text('Your result will appear here'), findsOneWidget);
    });

    for (final missing in ['twins', 'garments', 'both']) {
      testAppWidgets(
        'missing $missing disables generation and explains next steps',
        (tester) async {
          if (missing != 'garments') service.twins = [];
          if (missing != 'twins') service.wardrobe = [];
          await openTryOn(tester);
          await reveal(tester, generateButton());
          expect(
            tester.widget<ElevatedButton>(generateButton()).onPressed,
            isNull,
          );
          if (service.twins.isEmpty) {
            expect(find.text('Create digital twin'), findsOneWidget);
          }
          if (service.wardrobe.isEmpty) {
            expect(find.text('Back to closet'), findsOneWidget);
          }
          expect(service.generationCalls, isEmpty);
        },
      );
    }

    testAppWidgets('only Tops and Pants can be selected for try-on', (
      tester,
    ) async {
      service.wardrobe = [
        garmentJson('shoes-1', 'Shoes'),
        garmentJson('top-1', 'Tops'),
        garmentJson('pants-1', 'Pants'),
        garmentJson('accessory-1', 'Accessories'),
        garmentJson('hijab-1', 'Hijab'),
      ];
      await openTryOn(tester);
      await reveal(tester, find.text('Tops'));
      expect(find.text('Tops'), findsOneWidget);
      expect(find.text('Pants'), findsOneWidget);
      expect(find.text('Shoes'), findsNothing);
      expect(find.text('Accessories'), findsNothing);
      expect(find.text('Hijab'), findsNothing);
    });

    testAppWidgets(
      'generation uses the first choices and displays the returned image',
      (tester) async {
        await openTryOn(tester);
        await tapVisible(tester, generateButton());
        expect(service.generationCalls, [
          (twinId: 'twin-1', garmentItemId: 'top-1'),
        ]);
        await tester.scrollUntilVisible(
          find.byType(AspectRatio),
          -500,
          scrollable: find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              )
              .first,
        );
        final resultImage = find.descendant(
          of: find.byType(AspectRatio).first,
          matching: find.byType(Image),
        );
        final provider = tester.widget<Image>(resultImage).image as MemoryImage;
        expect(provider.bytes, base64Decode(testImageBase64));
        expect(find.text('Your result will appear here'), findsNothing);
      },
    );

    testAppWidgets('selecting a different garment changes the submitted ID', (
      tester,
    ) async {
      service.wardrobe.add(garmentJson('pants-1', 'Pants'));
      await openTryOn(tester);
      await tapVisible(tester, find.text('Pants'));
      await tapVisible(tester, generateButton());
      expect(service.generationCalls.single.garmentItemId, 'pants-1');
    });

    testAppWidgets(
      'generation disables repeated requests and refresh until completion',
      (tester) async {
        final pending = Completer<Map<String, dynamic>>();
        service.pendingGeneration = pending;
        await openTryOn(tester);
        await reveal(tester, generateButton());
        await tester.tap(generateButton());
        await tester.pump();
        final button = tester.widget<ElevatedButton>(generateButton());
        expect(button.onPressed, isNull);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Refresh',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(service.generationCalls, hasLength(1));
        pending.complete(service.result);
        await tester.pumpAndSettle();
        expect(
          tester.widget<ElevatedButton>(generateButton()).onPressed,
          isNotNull,
        );
      },
    );

    testAppWidgets('service loading error is shown and Refresh recovers', (
      tester,
    ) async {
      service.loadError = AiServiceException(
        'NETWORK_ERROR',
        'AI service is unavailable.',
      );
      await openTryOn(tester);
      await reveal(tester, find.text('AI service is unavailable.'));
      expect(find.text('AI service is unavailable.'), findsOneWidget);
      service.loadError = null;
      await tapVisible(tester, find.byTooltip('Refresh'));
      expect(find.text('AI service is unavailable.'), findsNothing);
      expect(service.twinLoads, 2);
      expect(service.wardrobeLoads, 2);
    });

    testAppWidgets('unexpected loading failure shows a readable fallback', (
      tester,
    ) async {
      service.loadError = StateError('Unexpected response');
      await openTryOn(tester);
      await reveal(
        tester,
        find.text('Could not load your digital twins and wardrobe.'),
      );
      expect(
        find.text('Could not load your digital twins and wardrobe.'),
        findsOneWidget,
      );
    });

    testAppWidgets(
      'AI generation errors are shown and the button is re-enabled',
      (tester) async {
        service.generationError = AiServiceException(
          'UNSUPPORTED_GARMENT',
          'Choose a clearer garment photo.',
        );
        await openTryOn(tester);
        await tapVisible(tester, generateButton());
        expect(find.text('Choose a clearer garment photo.'), findsOneWidget);
        expect(
          tester.widget<ElevatedButton>(generateButton()).onPressed,
          isNotNull,
        );
      },
    );

    testAppWidgets('malformed result shows an error instead of crashing', (
      tester,
    ) async {
      service.result = {'resultImageB64': '%%%invalid base64%%%'};
      await openTryOn(tester);
      await tapVisible(tester, generateButton());
      expect(
        find.text('The try-on result could not be displayed.'),
        findsOneWidget,
      );
      expect(
        tester.widget<ElevatedButton>(generateButton()).onPressed,
        isNotNull,
      );
    });
  });
}
