import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'ai_service.dart';

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

  /// Ensure bundled asset entries created by older app builds also exist in
  /// the Python wardrobe store used by Virtual Try-On. Returns a warning for
  /// the screen to display without hiding other usable garments.
  Future<String?> syncAssetItemsForTryOn() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
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

      String? firstWarning;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final assetPath = data['assetPath'];
        final category = data['category'];
        final itemId = data['itemId'];
        if (assetPath is! String ||
            assetPath.isEmpty ||
            category is! String ||
            !const {'Tops', 'Pants', 'Shoes'}.contains(category) ||
            (itemId is String && backendIds.contains(itemId))) {
          continue;
        }

        try {
          final syncedItemId = await _uploadAssetForTryOn(category, assetPath);
          backendIds.add(syncedItemId);
          await doc.reference.set({
            'itemId': syncedItemId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } on AiServiceException catch (error) {
          firstWarning ??= error.message;
        } catch (_) {
          firstWarning ??=
              'One bundled closet item could not be prepared for Virtual Try-On.';
        }
      }
      if (snapshot.docs.isNotEmpty) await fetchClothes();
      return firstWarning;
    } on AiServiceException catch (error) {
      return error.message;
    } catch (_) {
      return 'Bundled closet items could not be checked for Virtual Try-On.';
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
