import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'ai_service.dart';
import '../config/profile_validation.dart';

class UserController extends GetxController {
  UserController({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    AiService? aiService,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _aiService = aiService ?? AiService();

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final AiService _aiService;

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

  Future<void> saveUserData(
    String height,
    String weight,
    List<String> stylePreferences,
  ) async {
    if (isLoading.value) return;
    if (!isValidBodyMetric(height) ||
        !isValidBodyMetric(weight) ||
        stylePreferences.isEmpty ||
        selectedImage.value == null) {
      Get.snackbar(
        'Complete your profile',
        'Choose a full-body photo, valid height and weight, and at least one style preference.',
      );
      return;
    }
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
      String? twinId;
      bool? wearsHijab;

      // 1. Safely get the image file
      final File? imageToUpload = selectedImage.value;

      if (imageToUpload != null) {
        try {
          loadingMessage.value = 'Checking your photo...';
          final bytes = await imageToUpload.readAsBytes();
          final filename = imageToUpload.path
              .split(Platform.pathSeparator)
              .last;
          final result = await _aiService.createDigitalTwin(bytes, filename);

          final metadata = result['metadata'] as Map<String, dynamic>;
          twinId = result['twinId'] as String?;
          wearsHijab = metadata['wearsHijab'] as bool?;

          loadingMessage.value = 'Uploading your photo...';
          final processedBytes = base64Decode(
            result['personImageB64'] as String,
          );
          final ref = _storage.ref().child(
            'users/$uid/digital_twin_processed.jpg',
          );
          await ref.putData(
            processedBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          photoUrl = await ref.getDownloadURL();
        } on AiServiceException catch (aiError) {
          Get.snackbar('Could not create your digital twin', aiError.message);
          return;
        } catch (uploadError) {
          Get.snackbar('Could not upload photo', uploadError.toString());
          return;
        }
      }

      // Save body metrics, style preferences, and the processed twin reference.
      await _db.collection('users').doc(uid).set({
        'height': height,
        'weight': weight,
        'stylePreferences': stylePreferences,
        'bodyType': FieldValue.delete(),
        'digitalTwinPhotoUrl': photoUrl,
        'twinId': ?twinId,
        'wearsHijab': ?wearsHijab,
        'isProfileComplete': true,
      }, SetOptions(merge: true));

      Get.snackbar("Success", "Digital Twin created successfully!");
      Get.offAllNamed('/home');
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
      loadingMessage.value = '';
    }
  }
}
