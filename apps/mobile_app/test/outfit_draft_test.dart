import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/outfit_draft.dart';

void main() {
  OutfitDraft draft() =>
      OutfitDraft(image: Uint8List.fromList([1, 2]), ownerUid: 'owner');

  test(
    'double tapping save uploads once and successful saves stay saved',
    () async {
      final result = draft();
      final pending = Completer<void>();
      var calls = 0;
      Future<void> upload() {
        calls++;
        return pending.future;
      }

      final first = result.save(currentUid: 'owner', persist: upload);
      expect(result.saving, isTrue);
      expect(await result.save(currentUid: 'owner', persist: upload), isFalse);
      pending.complete();
      expect(await first, isTrue);
      expect(result.saved, isTrue);
      expect(result.saving, isFalse);
      expect(await result.save(currentUid: 'owner', persist: upload), isFalse);
      expect(calls, 1);
    },
  );

  test('a failed upload unlocks save for a retry', () async {
    final result = draft();
    await expectLater(
      result.save(
        currentUid: 'owner',
        persist: () async {
          throw StateError('offline');
        },
      ),
      throwsStateError,
    );
    expect(result.saving, isFalse);
    expect(result.saved, isFalse);
    expect(
      await result.save(currentUid: 'owner', persist: () async {}),
      isTrue,
    );
  });

  for (final uid in <String?>[null, 'another-user']) {
    test('result cannot be saved after account changes to $uid', () async {
      var called = false;
      await expectLater(
        draft().save(
          currentUid: uid,
          persist: () async {
            called = true;
          },
        ),
        throwsStateError,
      );
      expect(called, isFalse);
    });
  }
}
