import 'dart:io';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UserController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  var isLoading = false.obs;
  var loadingMessage = ''.obs;
  var selectedImage = Rxn<File>();

  Future<void> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    
    if (image != null) {
      selectedImage.value = File(image.path);
    }
  }

  Future<void> saveUserData(String height, String weight, String bodyType) async {
    try {
      isLoading.value = true;
      
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        Get.snackbar("Error", "Your session expired. Please log in again.");
        Get.offAllNamed('/login');
        return;
      }
      
      String uid = currentUser.uid;
      String photoUrl = '';

      // 1. Safely get the image file
      final File? imageToUpload = selectedImage.value;
      
      if (imageToUpload != null) {
        try {
          loadingMessage.value = 'Uploading your photo...';
          var extension = imageToUpload.path.split('.').last.toLowerCase();
          if (!['png', 'jpg', 'jpeg', 'webp'].contains(extension)) {
            extension = 'jpg';
          }
          final ref = _storage.ref().child(
            'users/$uid/digital_twin_original.$extension',
          );
          await ref.putFile(imageToUpload);
          photoUrl = await ref.getDownloadURL();
        } catch (uploadError) {
          Get.snackbar('Could not upload photo', uploadError.toString());
          return;
        }
      }

      // 2. Save body metrics and photo URL to Firestore safely
      await _db.collection('users').doc(uid).set({
        'height': height,
        'weight': weight,
        'bodyType': bodyType,
        'digitalTwinPhotoUrl': photoUrl,
        'isProfileComplete': true, 
      }, SetOptions(merge: true));

      Get.snackbar("Success", "Digital Twin created successfully!");
      Get.offAllNamed('/home');
      
    } catch (e) {
      print("----- SAVE USER DATA ERROR -----");
      print(e.toString());
      print("--------------------------------");
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
      loadingMessage.value = '';
    }
  }
}
