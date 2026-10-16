import 'dart:convert';
import 'dart:io';
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
  final String category;
  // The AI service's id for this item. Only uploaded photos have one; the
  // bundled sample items were never sent to the AI service.
  final String? itemId;
  ClothingItem({
    required this.id,
    required this.imageUrl,
    required this.category,
    this.assetPath,
    this.itemId,
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
      final snapshot = await _db.collection('users').doc(uid).collection('clothes').get();
      clothes.value = snapshot.docs.map((doc) {
        return ClothingItem(
          id: doc.id,
          imageUrl: doc.data().containsKey('imageUrl') ? doc['imageUrl'] : '',
          assetPath: doc.data().containsKey('assetPath') ? doc['assetPath'] : null,
          category: doc['category'],
          itemId: doc.data()['itemId'] as String?,
        );
      }).toList();
    } catch (e) {
      print("Error fetching clothes: $e");
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
      final clothesCollection =
          _db.collection('users').doc(user.uid).collection('clothes');
      final existingItem = await clothesCollection
          .where('assetPath', isEqualTo: assetPath)
          .limit(1)
          .get();

      if (existingItem.docs.isNotEmpty) {
        Get.snackbar(
          'Already in your closet',
          'You have already added this item.',
        );
        return;
      }

      await clothesCollection.add({
        'assetPath': assetPath,
        'imageUrl': '',
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await fetchClothes();
      Get.snackbar('Success', '$category added to your closet!');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
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
      final result = await _aiService.uploadWardrobeItem(bytes, filename, category: category);

      final String itemId = result['itemId'] as String;
      final processedBytes = base64Decode(result['itemImageB64'] as String);
      final fileName = 'users/$uid/clothes/$itemId.jpg';

      // Upload the AI-processed (background-removed, enhanced) image.
      Reference ref = _storage.ref().child(fileName);
      await ref.putData(processedBytes, SettableMetadata(contentType: 'image/jpeg'));
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
