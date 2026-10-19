import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/inspo_mirror_screen.dart';
import 'package:mobile_app/services/ai_service.dart';

class _TwinsApi extends AiService {
  bool unavailable = false;
  @override
  Future<List<dynamic>> listTwins() async {
    if (unavailable) {
      throw AiServiceException('NETWORK_ERROR', 'API is unavailable.');
    }
    return [];
  }
}

void main() {
  testWidgets(
    'empty twin list explains setup and cannot submit a paid request',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: InspoMirrorScreen(aiService: _TwinsApi())),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Create or edit twin'), 150);
      expect(find.text('Create or edit twin'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Generate on my twin'), 200);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Generate on my twin'),
      );
      expect(button.onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('API error can be recovered by refreshing twins', (tester) async {
    final api = _TwinsApi()..unavailable = true;
    await tester.pumpWidget(
      MaterialApp(home: InspoMirrorScreen(aiService: api)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('API is unavailable.'), 200);
    expect(find.text('API is unavailable.'), findsOneWidget);
    api.unavailable = false;
    await tester.tap(find.byTooltip('Refresh twins'));
    await tester.pumpAndSettle();
    expect(find.text('API is unavailable.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
