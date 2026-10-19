import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/wardrobe_recovery.dart';

void main() {
  group('owned closet image paths', () {
    test('accepts current and legacy paths only for this user', () {
      expect(
        isOwnedWardrobeStoragePath('abc', 'users/abc/clothes/top.jpg'),
        isTrue,
      );
      expect(isOwnedWardrobeStoragePath('abc', 'clothes/abc_123.jpg'), isTrue);
      expect(
        isOwnedWardrobeStoragePath('abc', 'users/other/clothes/top.jpg'),
        isFalse,
      );
      expect(
        isOwnedWardrobeStoragePath('abc', 'clothes/abcd_123.jpg'),
        isFalse,
      );
      expect(
        isOwnedWardrobeStoragePath('abc', 'clothes/abc_nested/file.jpg'),
        isFalse,
      );
      expect(
        isOwnedWardrobeStoragePath('abc', 'users/abc/digital_twin.jpg'),
        isFalse,
      );
    });
  });

  test(
    'recovers missing gallery and bundled items without duplicating linked items',
    () async {
      const items = [
        WardrobeRecoveryItem(id: 'gallery', category: 'Tops', imageUrl: 'url'),
        WardrobeRecoveryItem(
          id: 'stale',
          category: 'Pants',
          itemId: 'old',
          imageUrl: 'url',
        ),
        WardrobeRecoveryItem(
          id: 'bundled',
          category: 'Skirts',
          assetPath: 'asset',
        ),
        WardrobeRecoveryItem(
          id: 'linked',
          category: 'Shoes',
          itemId: 'existing',
          imageUrl: 'url',
        ),
        WardrobeRecoveryItem(
          id: 'accessory',
          category: 'Accessories',
          imageUrl: 'url',
        ),
        WardrobeRecoveryItem(
          id: 'unsupported',
          category: 'Hijab',
          imageUrl: 'url',
        ),
      ];
      final ids = {'existing'};
      final uploaded = <String>[];
      final saved = <String, String>{};
      final progress = <String>[];
      final result = await recoverWardrobeLinks(
        items: items,
        backendIds: ids,
        onProgress: (current, total) => progress.add('$current/$total'),
        upload: (item) async {
          uploaded.add(item.id);
          return 'new-${item.id}';
        },
        saveLink: (item, id) async {
          saved[item.id] = id;
          return true;
        },
      );
      expect(uploaded, ['gallery', 'stale', 'bundled', 'accessory']);
      expect(saved, {
        'gallery': 'new-gallery',
        'stale': 'new-stale',
        'bundled': 'new-bundled',
        'accessory': 'new-accessory',
      });
      expect(
        ids,
        containsAll([
          'existing',
          'new-gallery',
          'new-stale',
          'new-bundled',
          'new-accessory',
        ]),
      );
      expect(progress, ['1/4', '2/4', '3/4', '4/4']);
      expect(result.recovered, 4);
      expect(result.failed, 0);
    },
  );

  test(
    'continues after missing images or failed uploads and leaves changed records alone',
    () async {
      const items = [
        WardrobeRecoveryItem(id: 'missing', category: 'Tops'),
        WardrobeRecoveryItem(id: 'failure', category: 'Pants', imageUrl: 'url'),
        WardrobeRecoveryItem(id: 'changed', category: 'Tops', imageUrl: 'url'),
        WardrobeRecoveryItem(id: 'success', category: 'Tops', imageUrl: 'url'),
      ];
      final ids = <String>{};
      final result = await recoverWardrobeLinks(
        items: items,
        backendIds: ids,
        upload: (item) async {
          if (item.id == 'failure') throw StateError('offline');
          return 'new-${item.id}';
        },
        saveLink: (item, id) async => item.id != 'changed',
      );
      expect(result.failed, 2);
      expect(result.recovered, 1);
      expect(ids, {'new-success'});
    },
  );
}
