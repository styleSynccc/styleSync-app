import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/config/generation_config.dart';
import 'package:mobile_app/services/ai_service.dart';
import 'package:mobile_app/widgets/generation_confirmation.dart';
import 'package:mobile_app/widgets/generation_mode_selector.dart';

void main() {
  test('maximum-quality quote counts every item including accessories', () {
    expect(GenerationMode.quality.creditCost(0), 0);
    expect(GenerationMode.quality.creditCost(1), 3);
    expect(GenerationMode.quality.creditCost(2), 6);
    expect(GenerationMode.quality.creditCost(3), 9);
    expect(GenerationMode.quality.creditCost(8), 24);
  });

  testWidgets('VTON shows the total and cancellation declines generation', (
    tester,
  ) async {
    bool? approved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                approved = await confirmGeneration(context, itemCount: 3);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Generate for 9 credits?'), findsOneWidget);
    expect(
      find.textContaining('Earlier steps may still use credits'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(approved, isFalse);
  });

  testWidgets('Inspo confirms exactly one three-credit generation', (
    tester,
  ) async {
    bool? approved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                approved = await confirmGeneration(
                  context,
                  itemCount: 1,
                  inspiration: true,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Generate for 3 credits?'), findsOneWidget);
    expect(find.textContaining('Quality · 1K'), findsOneWidget);
    await tester.tap(find.text('Generate · 3 credits'));
    await tester.pumpAndSettle();
    expect(approved, isTrue);
  });

  test('VTON sends its confirmed total once', () async {
    var calls = 0;
    final api = AiService(
      tokenProvider: () async => 'test-token',
      client: MockClient((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['confirmedCredits'], 9);
        expect(body['garmentItemIds'], ['top', 'pants', 'shoes']);
        return http.Response('{"success": true}', 201);
      }),
    );
    await api.tryOn(twinId: 'twin', garmentItemIds: ['top', 'pants', 'shoes']);
    expect(calls, 1);
  });

  testWidgets('cost confirmation remains usable in landscape', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => confirmGeneration(context, itemCount: 8),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Generate for 24 credits?'), findsOneWidget);
    expect(find.text('Cancel').hitTestable(), findsOneWidget);
    expect(find.text('Generate · 24 credits').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  test(
    'Inspo sends the three-credit confirmation in its multipart request',
    () async {
      var calls = 0;
      final api = AiService(
        tokenProvider: () async => 'test-token',
        client: MockClient((request) async {
          calls++;
          expect(request.body, contains('name="confirmedCredits"\r\n\r\n3'));
          return http.Response('{"success": true}', 201);
        }),
      );
      await api.createInspoMirror(
        twinId: 'twin',
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'ref.jpg',
      );
      expect(calls, 1);
    },
  );

  for (final mode in GenerationMode.values) {
    test(
      '${mode.label} sends matching mode and cost to both endpoints',
      () async {
        final requests = <http.Request>[];
        final api = AiService(
          tokenProvider: () async => 'test-token',
          client: MockClient((request) async {
            requests.add(request);
            return http.Response('{"success":true}', 201);
          }),
        );
        await api.tryOn(
          twinId: 'twin',
          garmentItemIds: ['top', 'pants', 'shoes'],
          mode: mode,
        );
        final body = jsonDecode(requests.first.body) as Map<String, dynamic>;
        expect(body['generationMode'], mode.name);
        expect(body['confirmedCredits'], mode.creditsPerImage * 3);
        await api.createInspoMirror(
          twinId: 'twin',
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'ref.jpg',
          mode: mode,
        );
        expect(
          requests.last.body,
          contains('name="generationMode"\r\n\r\n${mode.name}'),
        );
        expect(
          requests.last.body,
          contains('name="confirmedCredits"\r\n\r\n${mode.creditsPerImage}'),
        );
        expect(requests, hasLength(2));
      },
    );

    testWidgets('${mode.label} confirmation shows its own total', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    confirmGeneration(context, itemCount: 3, mode: mode),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.text('Generate for ${mode.creditCost(3)} credits?'),
        findsOneWidget,
      );
      expect(find.textContaining(mode.resolutionLabel), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('mode selector switches choices and wraps on small screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = GenerationMode.quality;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => GenerationModeSelector(
              mode: selected,
              onChanged: (mode) => setState(() => selected = mode),
            ),
          ),
        ),
      ),
    );
    for (final mode in GenerationMode.values) {
      await tester.tap(find.text(mode.label));
      await tester.pumpAndSettle();
      expect(selected, mode);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, mode.label))
            .selected,
        isTrue,
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenerationModeSelector(
            mode: GenerationMode.fast,
            onChanged: null,
          ),
        ),
      ),
    );
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.onSelected, isNull);
    }
  });
}
