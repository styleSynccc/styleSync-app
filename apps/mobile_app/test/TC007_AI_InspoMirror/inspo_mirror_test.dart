import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mobile_app/screens/inspo_mirror_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUpTestApp();

  group('TC007 AI Inspo-Mirror', () {
    testAppWidgets(
      'shows the inspiration upload, generate action, and result area',
      (tester) async {
        await pumpTestApp(tester, const InspoMirrorScreen());
        expect(find.text('AI Inspo-Mirror'), findsOneWidget);
        expect(find.text('Upload Inspiration Photo'), findsOneWidget);
        expect(find.text('e.g., from Instagram or Pinterest'), findsOneWidget);
        expect(find.text('Generate Style on Digital Twin'), findsOneWidget);
        expect(find.text('Result will appear here'), findsOneWidget);
      },
    );

    testAppWidgets('upload explains that image upload is under construction', (
      tester,
    ) async {
      await pumpTestApp(tester, const InspoMirrorScreen());
      await tapVisible(tester, find.text('Upload Inspiration Photo'));
      expect(find.text('Coming Soon'), findsOneWidget);
      expect(find.text('Image upload is under construction'), findsOneWidget);
      expect(find.text('Result will appear here'), findsOneWidget);
    });

    testAppWidgets(
      'generate explains that AI style extraction is under construction',
      (tester) async {
        await pumpTestApp(tester, const InspoMirrorScreen());
        await tapVisible(tester, find.text('Generate Style on Digital Twin'));
        expect(
          find.text('AI Style extraction is under construction'),
          findsOneWidget,
        );
        expect(find.text('Result will appear here'), findsOneWidget);
      },
    );

    testAppWidgets('back arrow returns to the previous screen', (tester) async {
      await pumpTestApp(
        tester,
        Scaffold(
          body: TextButton(
            onPressed: () => Get.to(() => const InspoMirrorScreen()),
            child: const Text('Open inspiration'),
          ),
        ),
      );
      await tapVisible(tester, find.text('Open inspiration'));
      expect(find.byType(InspoMirrorScreen), findsOneWidget);
      await tapVisible(tester, find.byIcon(Icons.arrow_back));
      expect(find.byType(InspoMirrorScreen), findsNothing);
      expect(find.text('Open inspiration'), findsOneWidget);
    });
  });
}
