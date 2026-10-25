import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/config/generation_config.dart';
import 'package:mobile_app/services/ai_service.dart';
import 'package:mobile_app/widgets/generation_confirmation.dart';

void main() {
  test('maximum-quality quote counts every item including accessories', () {
    expect(maxQualityCreditCost(0), 0);
    expect(maxQualityCreditCost(1), 3);
    expect(maxQualityCreditCost(2), 6);
    expect(maxQualityCreditCost(3), 9);
    expect(maxQualityCreditCost(8), 24);
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
                approved = await confirmMaxQualityGeneration(
                  context,
                  itemCount: 3,
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
                approved = await confirmMaxQualityGeneration(
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
              onPressed: () =>
                  confirmMaxQualityGeneration(context, itemCount: 8),
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
}
