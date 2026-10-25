import 'dart:typed_data';

/// An unsaved generation belongs to the account that created it. Concurrent
/// Save taps share this state so they cannot upload duplicate outfit records.
class OutfitDraft {
  OutfitDraft({required this.image, required this.ownerUid});

  final Uint8List image;
  final String ownerUid;
  bool saving = false;
  bool saved = false;

  Future<bool> save({
    required String? currentUid,
    required Future<void> Function() persist,
  }) async {
    if (currentUid == null || currentUid != ownerUid) {
      throw StateError(
        'Your sign-in changed. Reopen Virtual Try-On before saving.',
      );
    }
    if (saving || saved) return false;
    saving = true;
    try {
      await persist();
      saved = true;
      return true;
    } finally {
      saving = false;
    }
  }
}
