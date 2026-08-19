import 'dart:io';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ClothingItem {
  final String id;
  final String imageUrl;
  final String? assetPath;
  final String category;
  ClothingItem({
    required this.id,
    required this.imageUrl,
    required this.category,
    this.assetPath,
  });

  bool get isAsset => assetPath != null && assetPath!.isNotEmpty;
}

class ClosetController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
      
      // NEW: Get the actual file extension (.png, .jpg, .webp)
      String originalExtension = image.path.split('.').last.toLowerCase();
      // If it's an unknown format, default to jpg
      if (!['png', 'jpg', 'jpeg', 'webp'].contains(originalExtension)) {
        originalExtension = 'jpg';
      }
      
      final String fileName = 'clothes/${uid}_${DateTime.now().millisecondsSinceEpoch}.$originalExtension';
      
      // Upload to Firebase Storage
      Reference ref = _storage.ref().child(fileName);
      await ref.putFile(File(image.path));
      String imageUrl = await ref.getDownloadURL();

      // Save to Firestore
      await _db.collection('users').doc(uid).collection('clothes').add({
        'imageUrl': imageUrl,
        'category': category,
        'createdAt': DateTime.now().toIso8601String(),
      });

      await fetchClothes(); // Refresh the grid
      Get.snackbar("Success", "$category added to your closet!");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}
