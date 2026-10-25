import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Where a liked outfit came from.
class OutfitSource {
  static const tryOn = 'vton';
  static const inspoMirror = 'inspo';
  static const planner = 'planner';
}

/// Stores outfits the user liked from Virtual Try-On or AI Inspo-Mirror.
class LikedOutfitsService {
  static CollectionReference<Map<String, dynamic>>? get collection {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('likedOutfits');
  }

  /// Uploads [imageBytes] and records it as a liked outfit.
  static Future<void> like({
    required Uint8List imageBytes,
    required String source,
    required String ownerUid,
    String? title,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final outfits = collection;
    if (user == null || outfits == null) {
      throw StateError('Please sign in to like outfits.');
    }
    if (user.uid != ownerUid) {
      throw StateError('Your sign-in changed. Reopen this page before saving.');
    }
    final isPng =
        imageBytes.length > 3 && imageBytes[0] == 0x89 && imageBytes[1] == 0x50;
    final ext = isPng ? 'png' : 'jpg';
    final document = outfits.doc();
    final path = 'users/${user.uid}/liked_outfits/${document.id}.$ext';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putData(
      imageBytes,
      SettableMetadata(contentType: isPng ? 'image/png' : 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    if (FirebaseAuth.instance.currentUser?.uid != ownerUid) {
      throw StateError('Your sign-in changed. Reopen this page before saving.');
    }
    await document.set({
      'imageUrl': url,
      'storagePath': path,
      'source': source,
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes a liked outfit and its stored image.
  static Future<void> unlike(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data,
  ) async {
    final path = data['storagePath'] as String?;
    await reference.delete();
    if (path != null && path.isNotEmpty) {
      try {
        await FirebaseStorage.instance.ref(path).delete();
      } catch (_) {
        // The document is already gone; a missing file is not a problem.
      }
    }
  }
}
