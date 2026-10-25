import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/outfit_creator_screen.dart';

import '../helpers/test_app.dart';

void main() {
  setUpTestApp();
  late TestEnvironment env;

  setUp(() async {
    env = TestEnvironment();
    await env.seedClothing();
    await env.seedClothing(id: 'top-2', asset: secondTopAsset);
    await env.seedClothing(id: 'pants-1', category: 'Pants', asset: pantsAsset);
    await env.registerCloset();
  });

  Future<void> openCreator(WidgetTester tester) async {
    await pumpTestApp(
      tester,
      OutfitCreatorScreen(auth: env.auth, firestore: env.firestore),
    );
    await tester.pumpAndSettle();
  }

  Finder itemTile(String asset) => find
      .ancestor(
        of: find.image(AssetImage(asset)),
        matching: find.byType(InkWell),
      )
      .first;

  group('TC006 Outfit Creator', () {
    testAppWidgets(
      'shows categories and disables Save until an item is selected',
      (tester) async {
        await openCreator(tester);
        expect(find.text('Outfit Creator'), findsOneWidget);
        expect(
          find.text('Choose items below to build an outfit'),
          findsOneWidget,
        );
        for (final category in ['Tops', 'Pants', 'Shoes', 'Accessories']) {
          expect(find.text(category), findsOneWidget);
        }
        expect(find.text('No items in this category'), findsNWidgets(2));
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Save Outfit'),
              )
              .onPressed,
          isNull,
        );
        await reveal(tester, find.text('No saved outfits yet.'));
        expect(find.text('No saved outfits yet.'), findsOneWidget);
      },
    );

    testAppWidgets(
      'selecting and clearing an item updates the preview and Save button',
      (tester) async {
        await openCreator(tester);
        await tapVisible(tester, itemTile(topAsset));
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        expect(
          find.text('Choose items below to build an outfit'),
          findsNothing,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Save Outfit'),
              )
              .onPressed,
          isNotNull,
        );
        await tapVisible(tester, find.text('Clear'));
        expect(find.byIcon(Icons.check_circle), findsNothing);
        expect(
          find.text('Choose items below to build an outfit'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Save Outfit'),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testAppWidgets('only one item per category is saved', (tester) async {
      await openCreator(tester);
      await tapVisible(tester, itemTile(topAsset));
      await tapVisible(tester, itemTile(secondTopAsset));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tapVisible(tester, find.text('Save Outfit'));
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '  Friday  ',
      );
      await tapVisible(tester, find.widgetWithText(ElevatedButton, 'Save'));
      final saved = (await env.outfits.get()).docs.single.data();
      expect(saved['name'], 'Friday');
      final items = saved['items'] as List;
      expect(items, hasLength(1));
      expect(items.single['id'], 'top-2');
      expect(items.single['assetPath'], secondTopAsset);
      expect(saved['createdAt'], isA<Timestamp>());
      expect(
        find.text('Choose items below to build an outfit'),
        findsOneWidget,
      );
    });

    testAppWidgets(
      'saving multiple categories persists all selected item details',
      (tester) async {
        await openCreator(tester);
        await tapVisible(tester, itemTile(topAsset));
        await tapVisible(tester, itemTile(pantsAsset));
        await tapVisible(tester, find.text('Save Outfit'));
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'Weekend',
        );
        await tapVisible(tester, find.widgetWithText(ElevatedButton, 'Save'));
        final saved = (await env.outfits.get()).docs.single.data();
        expect(
          saved['items'],
          unorderedEquals([
            {
              'id': 'top-1',
              'category': 'Tops',
              'imageUrl': '',
              'assetPath': topAsset,
            },
            {
              'id': 'pants-1',
              'category': 'Pants',
              'imageUrl': '',
              'assetPath': pantsAsset,
            },
          ]),
        );
        await reveal(tester, find.text('Weekend'));
        expect(find.text('Weekend'), findsOneWidget);
        expect(find.text('2 items'), findsOneWidget);
      },
    );

    for (final cancel in [true, false]) {
      testAppWidgets(
        '${cancel ? 'cancelling' : 'blank name'} does not save or clear the selection',
        (tester) async {
          await openCreator(tester);
          await tapVisible(tester, itemTile(topAsset));
          await tapVisible(tester, find.text('Save Outfit'));
          if (cancel) {
            await tapVisible(tester, find.text('Cancel'));
          } else {
            await tester.enterText(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextField),
              ),
              '   ',
            );
            await tapVisible(
              tester,
              find.widgetWithText(ElevatedButton, 'Save'),
            );
          }
          expect((await env.outfits.get()).docs, isEmpty);
          expect(find.byIcon(Icons.check_circle), findsOneWidget);
        },
      );
    }

    testAppWidgets('saved outfit can be deleted from the creator list', (
      tester,
    ) async {
      await env.outfits.doc('saved-1').set({
        'name': 'Old outfit',
        'items': [],
        'createdAt': Timestamp.now(),
      });
      await openCreator(tester);
      await reveal(tester, find.text('Old outfit'));
      await tapVisible(tester, find.byIcon(Icons.delete_outline));
      expect((await env.outfits.get()).docs, isEmpty);
      expect(find.text('No saved outfits yet.'), findsOneWidget);
    });

    testAppWidgets('signed-out user cannot save an outfit', (tester) async {
      await env.auth.signOut();
      await openCreator(tester);
      await tapVisible(tester, itemTile(topAsset));
      await tapVisible(tester, find.text('Save Outfit'));
      expect(
        find.text('Please sign in before saving an outfit.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect((await env.outfits.get()).docs, isEmpty);
    });
  });
}
