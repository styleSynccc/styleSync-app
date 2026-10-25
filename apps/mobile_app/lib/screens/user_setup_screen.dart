import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/user_controller.dart';
import '../widgets/style_preference_selector.dart';
import '../config/profile_validation.dart';

class UserSetupScreen extends StatefulWidget {
  const UserSetupScreen({super.key, this.controller});
  final UserController? controller;

  @override
  State<UserSetupScreen> createState() => _UserSetupScreenState();
}

class _UserSetupScreenState extends State<UserSetupScreen> {
  late final UserController userController =
      widget.controller ??
      (Get.isRegistered<UserController>()
          ? Get.find<UserController>()
          : Get.put(UserController()));
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final RxList<String> selectedStylePreferences = <String>[].obs;

  @override
  void dispose() {
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Digital Twin'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading:
            false, // User can't go back to login after this
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Enter your details to get the best virtual try-on experience.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Photo Upload Area
              GestureDetector(
                onTap: () => _showPhotoSource(userController),
                child: Obx(
                  () => Container(
                    height: 180,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade400),
                      image: userController.selectedImage.value != null
                          ? DecorationImage(
                              image: FileImage(
                                userController.selectedImage.value!,
                              ),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: userController.selectedImage.value == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 40,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Upload Photo',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Height Input
              TextField(
                controller: heightController,
                decoration: const InputDecoration(labelText: 'Height (cm)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              // Weight Input
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              Obx(
                () => StylePreferenceSelector(
                  selected: selectedStylePreferences.toList(),
                  onChanged: (preferences) =>
                      selectedStylePreferences.assignAll(preferences),
                ),
              ),
              const SizedBox(height: 40),

              // Save Button
              Obx(
                () => userController.isLoading.value
                    ? Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            userController.loadingMessage.value.isEmpty
                                ? 'Saving your profile...'
                                : userController.loadingMessage.value,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                    : ElevatedButton(
                        onPressed: () {
                          if (userController.selectedImage.value == null) {
                            Get.snackbar(
                              'Photo required',
                              'Choose a clear full-body photo first.',
                            );
                          } else if (isValidBodyMetric(heightController.text) &&
                              isValidBodyMetric(weightController.text) &&
                              selectedStylePreferences.isNotEmpty) {
                            userController.saveUserData(
                              heightController.text.trim(),
                              weightController.text.trim(),
                              selectedStylePreferences.toList(),
                            );
                          } else {
                            Get.snackbar(
                              'Complete your profile',
                              'Enter valid positive height and weight, and select at least one style preference.',
                            );
                          }
                        },
                        child: const Text('Save & Continue'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoSource(UserController controller) {
    Get.bottomSheet(
      SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Twin Photo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () {
                  Get.back();
                  final dynamic userController = controller;
                  userController.pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Get.back();
                  final dynamic userController = controller;
                  userController.pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }
}
