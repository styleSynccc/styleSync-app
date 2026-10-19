import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'ai_service.dart';
import 'wardrobe_recovery.dart';

class ClothingItem {
  final String id;
  final String imageUrl;
  final String? assetPath;
  final String? tryOnItemId;
  final String category;
  ClothingItem({
    required this.id,
    required this.imageUrl,
    required this.category,
    this.assetPath,
    this.tryOnItemId,
  });

  bool get isAsset => assetPath != null && assetPath!.isNotEmpty;
}

class ClosetController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AiService _aiService = AiService();

  var clothes = <ClothingItem>[].obs;
  var isLoading = false.obs;
  var isAddExpanded = false.obs;
  final syncStatus = ''.obs;
  Future<String?>? _wardrobeSync;

  @override
  void onInit() {
    super.onInit();
    fetchClothes();
  }

  // Fetch uploaded clothes from Firestore
  Future<void> fetchClothes() async {
    try {
      final String uid = _auth.currentUser!.uid;
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('clothes')
          .get();
      clothes.value = snapshot.docs.map((doc) {
        return ClothingItem(
          id: doc.id,
          imageUrl: doc.data().containsKey('imageUrl') ? doc['imageUrl'] : '',
          assetPath: doc.data().containsKey('assetPath')
              ? doc['assetPath']
              : null,
          tryOnItemId: doc.data().containsKey('itemId') ? doc['itemId'] : null,
          category: doc['category'],
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching clothes: $e');
    }
  }

  // Add one of the clothing images bundled with the app.
  Future<void> addAssetClothingItem(String category, String assetPath) async {
    final user = _auth.currentUser;
    if (user == null) {
      Get.snackbar('Error', 'Please sign in before adding clothes.');
      return;
    }

    try {
      isLoading.value = true;
      final clothesCollection = _db
          .collection('users')
          .doc(user.uid)
          .collection('clothes');
      final existingItem = await clothesCollection
          .where('assetPath', isEqualTo: assetPath)
          .limit(1)
          .get();

      if (existingItem.docs.isNotEmpty) {
        final existing = existingItem.docs.first;
        final currentItemId = existing.data()['itemId'];
        if (currentItemId is String && currentItemId.isNotEmpty) {
          Get.snackbar(
            'Already in your closet',
            'You have already added this item.',
          );
          return;
        }

        // Older app versions saved bundled assets only in Firestore. Upgrade
        // that existing entry by processing it through the AI wardrobe API.
        final itemId = await _uploadAssetForTryOn(category, assetPath);
        await existing.reference.set({
          'itemId': itemId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await fetchClothes();
        Get.snackbar('Success', '$category is now ready for Virtual Try-On!');
        return;
      }

      final itemId = await _uploadAssetForTryOn(category, assetPath);
      await clothesCollection.add({
        'assetPath': assetPath,
        'imageUrl': '',
        'category': category,
        'itemId': itemId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await fetchClothes();
      Get.snackbar('Success', '$category added and ready for Virtual Try-On!');
    } on AiServiceException catch (aiError) {
      Get.snackbar('Could not add item', aiError.message);
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  /// Recover missing AI wardrobe links for both bundled and gallery items.
  /// Multiple screens opening at once share one recovery operation.
  Future<String?> syncWardrobeItemsForTryOn() {
    final active = _wardrobeSync;
    if (active != null) return active;
    final operation = _syncWardrobeItemsForTryOn();
    _wardrobeSync = operation;
    return operation.whenComplete(() {
      if (identical(_wardrobeSync, operation)) _wardrobeSync = null;
    });
  }

  Future<String?> _syncWardrobeItemsForTryOn() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      syncStatus.value = 'Checking your closet...';
      final backendItems = await _aiService.listWardrobe();
      final backendIds = backendItems
          .map((item) => (item as Map<String, dynamic>)['itemId'])
          .whereType<String>()
          .toSet();
      final snapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('clothes')
          .get();

      final docs = {for (final doc in snapshot.docs) doc.id: doc};
      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        return WardrobeRecoveryItem(
          id: doc.id,
          category: data['category'] is String
              ? data['category'] as String
              : '',
          itemId: data['itemId'] is String ? data['itemId'] as String : null,
          assetPath: data['assetPath'] is String
              ? data['assetPath'] as String
              : null,
          imageUrl: data['imageUrl'] is String
              ? data['imageUrl'] as String
              : null,
        );
      }).toList();
      final result = await recoverWardrobeLinks(
        items: items,
        backendIds: backendIds,
        onProgress: (current, total) =>
            syncStatus.value = 'Preparing closet item $current of $total...',
        upload: (item) async {
          if (_auth.currentUser?.uid != user.uid) {
            throw StateError('The signed-in account changed.');
          }
          final assetPath = item.assetPath;
          if (assetPath != null && assetPath.isNotEmpty) {
            return _uploadAssetForTryOn(item.category, assetPath);
          }
          final imageUrl = item.imageUrl!;
          final ref = _storage.refFromURL(imageUrl);
          if (ref.bucket != _storage.ref().bucket ||
              !isOwnedWardrobeStoragePath(user.uid, ref.fullPath)) {
            throw StateError('The saved image is not in your closet storage.');
          }
          final bytes = await _downloadClosetImage(imageUrl);
          if (_auth.currentUser?.uid != user.uid) {
            throw StateError('The signed-in account changed.');
          }
          final response = await _aiService.uploadWardrobeItem(
            bytes,
            ref.name,
            category: item.category,
          );
          return response['itemId'] as String;
        },
        saveLink: (item, itemId) async {
          if (_auth.currentUser?.uid != user.uid) return false;
          final reference = docs[item.id]!.reference;
          return _db.runTransaction((transaction) async {
            final current = await transaction.get(reference);
            final data = current.data();
            if (data == null ||
                data['category'] != item.category ||
                (data['itemId'] is String ? data['itemId'] : null) !=
                    item.itemId ||
                (data['assetPath'] is String ? data['assetPath'] : null) !=
                    item.assetPath ||
                (data['imageUrl'] is String ? data['imageUrl'] : null) !=
                    item.imageUrl) {
              return false;
            }
            transaction.update(reference, {
              'itemId': itemId,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return true;
          });
        },
      );
      if (snapshot.docs.isNotEmpty) await fetchClothes();
      if (result.failed > 0) {
        return '${result.failed} closet item(s) could not be prepared for Virtual Try-On. '
            'Your closet photos are unchanged. Check your connection and refresh to retry.';
      }
      return null;
    } on AiServiceException catch (error) {
      return error.message;
    } catch (_) {
      return 'Your closet items could not be checked for Virtual Try-On. Please try again.';
    } finally {
      syncStatus.value = '';
    }
  }

  /// Firebase download URLs also work for legacy items whose original Storage
  /// path predates the current per-user rules. Keep the URL private and bound
  /// both the download time and the maximum size.
  Future<Uint8List> _downloadClosetImage(String imageUrl) async {
    final uri = Uri.parse(imageUrl);
    if (uri.scheme != 'https' || uri.host != 'firebasestorage.googleapis.com') {
      throw StateError('Unsupported closet image URL.');
    }
    const maxBytes = 25 * 1024 * 1024;
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)..followRedirects = false;
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200 ||
          (response.contentLength != null &&
              response.contentLength! > maxBytes)) {
        throw StateError('Could not download the saved closet image.');
      }
      final output = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 45),
      )) {
        if (output.length + chunk.length > maxBytes) {
          throw StateError('The saved closet image is too large.');
        }
        output.add(chunk);
      }
      if (output.isEmpty) throw StateError('The saved closet image is empty.');
      return output.takeBytes();
    } finally {
      client.close();
    }
  }

  Future<String> _uploadAssetForTryOn(String category, String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final filename = assetPath.split('/').last;
    final result = await _aiService.uploadWardrobeItem(
      bytes,
      filename,
      category: category,
    );
    return result['itemId'] as String;
  }

  Future<void> deleteClothingItem(ClothingItem item) async {
    final user = _auth.currentUser;
    if (user == null) {
      Get.snackbar('Error', 'Please sign in before deleting clothes.');
      return;
    }

    try {
      isLoading.value = true;
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('clothes')
          .doc(item.id)
          .delete();

      clothes.removeWhere((clothing) => clothing.id == item.id);

      if (!item.isAsset && item.imageUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(item.imageUrl).delete();
        } catch (_) {
          // The closet entry is already deleted; an absent Storage file is safe.
        }
      }

      Get.snackbar('Deleted', '${item.category} removed from your closet.');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  // Pick image, upload to Storage, save to Firestore
  Future<void> uploadClothingItem(
    String category, {
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image == null) return; // User canceled

      isLoading.value = true;
      final String uid = _auth.currentUser!.uid;

      final bytes = await File(image.path).readAsBytes();
      final filename = image.path.split(Platform.pathSeparator).last;
      final result = await _aiService.uploadWardrobeItem(
        bytes,
        filename,
        category: category,
      );

      final String itemId = result['itemId'] as String;
      final processedBytes = base64Decode(result['itemImageB64'] as String);
      final fileName = 'users/$uid/clothes/$itemId.jpg';

      // Upload the AI-processed (background-removed, enhanced) image.
      Reference ref = _storage.ref().child(fileName);
      await ref.putData(
        processedBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      String imageUrl = await ref.getDownloadURL();

      // Save to Firestore
      await _db.collection('users').doc(uid).collection('clothes').add({
        'imageUrl': imageUrl,
        'category': category,
        'itemId': itemId,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await fetchClothes(); // Refresh the grid
      Get.snackbar("Success", "$category added to your closet!");
    } on AiServiceException catch (aiError) {
      Get.snackbar('Could not add item', aiError.message);
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
