import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/home_screen.dart';
import 'package:mobile_app/services/closet_controller.dart';

import '../helpers/test_app.dart';

void main() {
  setUpTestApp();
  late TestEnvironment env;
  late ClosetController closet;

  setUp(() async {
    env = TestEnvironment();
    await env.seedProfile();
  });

  Future<void> openWardrobe(WidgetTester tester) async {
    closet = await env.registerCloset();
    await pumpTestApp(
      tester,
      HomeScreen(auth: env.auth, firestore: env.firestore),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTopPicker(WidgetTester tester) async {
    await tapVisible(tester, find.byIcon(Icons.add));
    await tapVisible(tester, find.widgetWithText(ActionChip, 'Tops'));
  }

  group('TC008 Digital Wardrobe (My Closet)', () {
    testAppWidgets(
      'add button expands and collapses the four clothing categories',
      (tester) async {
        await openWardrobe(tester);
        expect(find.byType(ActionChip), findsNothing);
        await tapVisible(tester, find.byIcon(Icons.add));
        for (final category in ['Tops', 'Pants', 'Shoes', 'Accessories']) {
          expect(find.widgetWithText(ActionChip, category), findsOneWidget);
        }
        await tapVisible(tester, find.byIcon(Icons.close));
        expect(find.byType(ActionChip), findsNothing);
      },
    );

    testAppWidgets('empty closet shows a spinner while loading', (
      tester,
    ) async {
      await openWardrobe(tester);
      closet.isLoading.value = true;
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Your closet is empty.'), findsNothing);
      closet.isLoading.value = false;
      await tester.pump();
      expect(find.textContaining('Your closet is empty.'), findsOneWidget);
    });

    testAppWidgets(
      'choosing a sample item saves it and updates the closet count',
      (tester) async {
        await openWardrobe(tester);
        await openTopPicker(tester);
        expect(find.text('Choose Tops'), findsOneWidget);
        await tapVisible(tester, find.image(const AssetImage(topAsset)));
        final stored = (await env.clothes.get()).docs.single.data();
        expect(stored['category'], 'Tops');
        expect(stored['assetPath'], topAsset);
        expect(stored['imageUrl'], '');
        expect(closet.clothes.single.isAsset, isTrue);
        expect(closet.isLoading.value, isFalse);
        expect(find.text('1 Items'), findsOneWidget);
        expect(find.textContaining('Your closet is empty.'), findsNothing);
      },
    );

    testAppWidgets('adding the same sample twice does not duplicate it', (
      tester,
    ) async {
      await env.seedClothing();
      await openWardrobe(tester);
      await openTopPicker(tester);
      await tapVisible(tester, find.image(const AssetImage(topAsset)));
      expect((await env.clothes.get()).docs, hasLength(1));
      expect(closet.clothes, hasLength(1));
      expect(find.text('Already in your closet'), findsOneWidget);
      expect(closet.isLoading.value, isFalse);
    });

    testAppWidgets('personal photo picker offers camera and gallery', (
      tester,
    ) async {
      await openWardrobe(tester);
      await openTopPicker(tester);
      await tapVisible(tester, find.text('Your photo'));
      expect(find.text('Add Your Tops Photo'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
    });

    testAppWidgets('saved clothes are displayed in category order', (
      tester,
    ) async {
      await env.seedClothing(
        id: 'pants-1',
        category: 'Pants',
        asset: pantsAsset,
      );
      await env.seedClothing(id: 'top-1');
      await openWardrobe(tester);
      expect(find.text('2 Items'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Tops')).dx,
        lessThan(tester.getTopLeft(find.text('Pants')).dx),
      );
      expect(
        closet.clothes.map((item) => item.id),
        containsAll(['pants-1', 'top-1']),
      );
    });

    testAppWidgets('item opens a swipeable gallery that can be closed', (
      tester,
    ) async {
      await env.seedClothing();
      await env.seedClothing(
        id: 'pants-1',
        category: 'Pants',
        asset: pantsAsset,
      );
      await openWardrobe(tester);
      await tapVisible(tester, find.text('Tops'));
      expect(find.byType(InteractiveViewer), findsWidgets);
      expect(find.textContaining('1/2'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.textContaining('2/2'), findsOneWidget);
      await tapVisible(tester, find.byIcon(Icons.close));
      expect(find.byType(PageView), findsNothing);
      expect(find.text('My Closet'), findsOneWidget);
    });

    for (final confirm in [false, true]) {
      testAppWidgets(
        '${confirm ? 'confirming' : 'cancelling'} item deletion updates the correct data',
        (tester) async {
          await env.seedClothing();
          await openWardrobe(tester);
          await tester.longPress(find.text('Tops'));
          await tester.pumpAndSettle();
          expect(find.text('Remove item?'), findsOneWidget);
          await tapVisible(tester, find.text(confirm ? 'Delete' : 'Cancel'));
          expect((await env.clothes.get()).docs, hasLength(confirm ? 0 : 1));
          expect(closet.clothes, hasLength(confirm ? 0 : 1));
          expect(find.text(confirm ? '0 Items' : '1 Items'), findsOneWidget);
        },
      );
    }

    testAppWidgets('fetching clothes excludes another user\'s wardrobe', (
      tester,
    ) async {
      await env.seedClothing();
      await env.firestore
          .collection('users')
          .doc('other-user')
          .collection('clothes')
          .doc('private')
          .set({'category': 'Shoes', 'assetPath': topAsset});
      await openWardrobe(tester);
      expect(closet.clothes.map((item) => item.id), ['top-1']);
      expect(find.text('1 Items'), findsOneWidget);
    });

    testAppWidgets('adding after sign-out does not write clothes', (
      tester,
    ) async {
      await openWardrobe(tester);
      await env.auth.signOut();
      await closet.addAssetClothingItem('Tops', topAsset);
      await tester.pumpAndSettle();
      expect(
        find.text('Please sign in before adding clothes.'),
        findsOneWidget,
      );
      expect((await env.clothes.get()).docs, isEmpty);
    });

    testAppWidgets('deleting after sign-out preserves the item', (
      tester,
    ) async {
      await env.seedClothing();
      await openWardrobe(tester);
      await env.auth.signOut();
      await closet.deleteClothingItem(closet.clothes.single);
      await tester.pumpAndSettle();
      expect(
        find.text('Please sign in before deleting clothes.'),
        findsOneWidget,
      );
      expect((await env.clothes.get()).docs, hasLength(1));
      expect(closet.clothes, hasLength(1));
    });
  });

  group('ClothingItem image source', () {
    for (final asset in <String?>[null, '', topAsset]) {
      test('isAsset handles ${asset ?? 'null'}', () {
        final item = ClothingItem(
          id: 'item',
          imageUrl: '',
          category: 'Tops',
          assetPath: asset,
        );
        expect(item.isAsset, asset != null && asset.isNotEmpty);
      });
    }
  });
}
