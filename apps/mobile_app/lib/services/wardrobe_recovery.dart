/// A closet entry that may need its AI wardrobe link restored.
class WardrobeRecoveryItem {
  const WardrobeRecoveryItem({
    required this.id,
    required this.category,
    this.itemId,
    this.assetPath,
    this.imageUrl,
  });

  final String id;
  final String category;
  final String? itemId;
  final String? assetPath;
  final String? imageUrl;

  bool get hasImage =>
      (assetPath?.isNotEmpty ?? false) || (imageUrl?.isNotEmpty ?? false);
}

const _tryOnCategories = {'Tops', 'Pants', 'Skirts', 'Shoes', 'Accessories'};

/// Old uploads used `clothes/<uid>_<filename>`; current uploads are under the
/// user's own directory. Do not use a stored URL to fetch another user's data.
bool isOwnedWardrobeStoragePath(String uid, String path) {
  if (uid.isEmpty) return false;
  final currentPrefix = 'users/$uid/clothes/';
  if (path.startsWith(currentPrefix) && path.length > currentPrefix.length) {
    return true;
  }
  final legacyPrefix = 'clothes/${uid}_';
  return path.startsWith(legacyPrefix) &&
      path.length > legacyPrefix.length &&
      !path.substring(legacyPrefix.length).contains('/');
}

class WardrobeRecoveryResult {
  const WardrobeRecoveryResult({required this.recovered, required this.failed});

  final int recovered;
  final int failed;
}

/// Restores missing links without modifying already-linked or unsupported
/// entries. [saveLink] can return false if the record changed or was deleted
/// while the image was being processed.
Future<WardrobeRecoveryResult> recoverWardrobeLinks({
  required List<WardrobeRecoveryItem> items,
  required Set<String> backendIds,
  required Future<String> Function(WardrobeRecoveryItem item) upload,
  required Future<bool> Function(WardrobeRecoveryItem item, String id) saveLink,
  void Function(int current, int total)? onProgress,
}) async {
  final missing = items.where((item) {
    return _tryOnCategories.contains(item.category) &&
        (item.itemId == null || !backendIds.contains(item.itemId));
  }).toList();
  var recovered = 0;
  var failed = 0;
  for (var index = 0; index < missing.length; index++) {
    final item = missing[index];
    onProgress?.call(index + 1, missing.length);
    if (!item.hasImage) {
      failed++;
      continue;
    }
    try {
      final newId = await upload(item);
      if (newId.isEmpty) {
        throw StateError('The AI service returned no item ID.');
      }
      if (await saveLink(item, newId)) {
        backendIds.add(newId);
        recovered++;
      }
    } catch (_) {
      failed++;
    }
  }
  return WardrobeRecoveryResult(recovered: recovered, failed: failed);
}
