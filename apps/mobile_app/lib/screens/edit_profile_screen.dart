import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final nameController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final bodyTypes = const ['Rectangle', 'Pear', 'Apple', 'Hourglass'];
  String bodyType = 'Rectangle';
  String currentPhotoUrl = '';
  File? selectedPhoto;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final document = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = document.data() ?? {};
    nameController.text = data['name']?.toString() ?? user.displayName ?? '';
    heightController.text = data['height']?.toString() ?? '';
    weightController.text = data['weight']?.toString() ?? '';
    final storedBodyType = data['bodyType']?.toString();
    if (storedBodyType != null && bodyTypes.contains(storedBodyType)) bodyType = storedBodyType;
    currentPhotoUrl = data['digitalTwinPhotoUrl']?.toString() ?? '';
    if (mounted) setState(() => loading = false);
  }

  @override
  void dispose() {
    nameController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('Edit Profile'), backgroundColor: Colors.white),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              GestureDetector(
                onTap: _pickPhoto,
                child: Stack(alignment: Alignment.bottomRight, children: [
                  CircleAvatar(
                    radius: 65,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: selectedPhoto != null
                        ? FileImage(selectedPhoto!)
                        : currentPhotoUrl.isNotEmpty
                            ? NetworkImage(currentPhotoUrl) as ImageProvider
                            : null,
                    child: selectedPhoto == null && currentPhotoUrl.isEmpty
                        ? const Icon(Icons.person, size: 65, color: Colors.grey)
                        : null,
                  ),
                  const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black,
                    child: Icon(Icons.camera_alt, color: Colors.white, size: 19),
                  ),
                ]),
              ),
              const SizedBox(height: 30),
              TextField(controller: nameController, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 16),
              TextField(controller: heightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Height (cm)')),
              const SizedBox(height: 16),
              TextField(controller: weightController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Weight (kg)')),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: bodyType,
                decoration: const InputDecoration(labelText: 'Body Type'),
                items: bodyTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setState(() => bodyType = value ?? bodyType),
              ),
              const SizedBox(height: 32),
              saving
                  ? const CircularProgressIndicator()
                  : ElevatedButton(onPressed: _save, child: const Text('Save Changes')),
            ]),
          ),
  );

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null && mounted) setState(() => selectedPhoto = File(image.path));
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    final name = nameController.text.trim();
    final height = double.tryParse(heightController.text.trim());
    final weight = double.tryParse(weightController.text.trim());
    if (user == null) return;
    if (name.isEmpty || height == null || weight == null || height <= 0 || weight <= 0) {
      Get.snackbar('Invalid details', 'Enter a name and valid height and weight.');
      return;
    }
    setState(() => saving = true);
    try {
      var photoUrl = currentPhotoUrl;
      String? twinId;
      bool? wearsHijab;
      if (selectedPhoto != null) {
        final bytes = await selectedPhoto!.readAsBytes();
        final filename = selectedPhoto!.path.split(Platform.pathSeparator).last;
        final result = await AiService().createDigitalTwin(bytes, filename);

        final metadata = result['metadata'] as Map<String, dynamic>;
        twinId = result['twinId'] as String?;
        wearsHijab = metadata['wearsHijab'] as bool?;

        final processedBytes = base64Decode(result['personImageB64'] as String);
        final reference = FirebaseStorage.instance.ref('users/${user.uid}/digital_twin_processed.jpg');
        await reference.putData(processedBytes, SettableMetadata(contentType: 'image/jpeg'));
        photoUrl = await reference.getDownloadURL();
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'height': heightController.text.trim(),
        'weight': weightController.text.trim(),
        'bodyType': bodyType,
        'digitalTwinPhotoUrl': photoUrl,
        if (twinId != null) 'twinId': twinId,
        if (wearsHijab != null) 'wearsHijab': wearsHijab,
        'isProfileComplete': true,
      }, SetOptions(merge: true));
      if (mounted) Get.back();
      Get.snackbar('Profile updated', 'Your changes were saved.');
    } on AiServiceException catch (aiError) {
      Get.snackbar('Could not process your new photo', aiError.message);
      if (mounted) setState(() => saving = false);
    } catch (error) {
      Get.snackbar('Could not update profile', error.toString());
      if (mounted) setState(() => saving = false);
    }
  }
}
