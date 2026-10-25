import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/widgets/outfit_preview.dart';

Widget preview(Map<String, dynamic> data, {bool detailed = false}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 160,
            height: 220,
            child: OutfitPreview(data: data, detailed: detailed),
          ),
        ),
      ),
    );

void main() {
  testWidgets('planner thumbnail fits all six clothing pieces', (tester) async {
    final assets = [
      'assets/images/tops/tshirt_black.png',
      'assets/images/pants/jeans_blue.png',
      'assets/images/shoes/converse_black.png',
      'assets/images/accessories/blackbelt.png',
      'assets/images/accessories/bracelet_silver.png',
      'assets/images/accessories/rolex.jpg',
    ];
    await tester.pumpWidget(
      preview({
        'source': 'planner',
        'items': [
          for (final asset in assets) {'assetPath': asset},
        ],
      }),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(6));
    final bounds = tester.getRect(find.byType(OutfitPreview));
    for (final image in find.byType(Image).evaluate()) {
      final rect = tester.getRect(find.byWidget(image.widget));
      expect(rect.top, greaterThanOrEqualTo(bounds.top));
      expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + 1));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('planner detail shows categories and can scroll', (tester) async {
    await tester.pumpWidget(
      preview({
        'source': 'planner',
        'items': [
          for (var i = 0; i < 8; i++)
            {
              'assetPath': 'assets/images/tops/tshirt_black.png',
              'category': 'Item $i',
            },
        ],
      }, detailed: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Item 0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Item 7'), 120);
    await tester.pumpAndSettle();
    expect(find.text('Item 7').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty planner outfit has a friendly preview', (tester) async {
    await tester.pumpWidget(preview({'source': 'planner', 'items': []}));
    expect(find.text('No clothing images available.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery upload uses its actual network URL', (tester) async {
    await tester.pumpWidget(
      preview({
        'source': 'planner',
        'items': [
          {'imageUrl': 'https://example.com/actual-shirt.jpg'},
        ],
      }),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'https://example.com/actual-shirt.jpg',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
