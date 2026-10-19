import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ai_service.dart';
import '../widgets/style_preference_selector.dart';

/// Edits the information used to personalise a user's digital twin.
/// The optional image is a twin source image, never a profile/avatar image.
class EditTwinScreen extends StatefulWidget {
  const EditTwinScreen({super.key});

  @override
  State<EditTwinScreen> createState() => _EditTwinScreenState();
}

class _EditTwinScreenState extends State<EditTwinScreen> {
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  List<String> _stylePreferences = [];
  File? _selectedTwinPhoto;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadTwin();
  }

  Future<void> _loadTwin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = document.data() ?? <String, dynamic>{};
      _nameController.text = data['name']?.toString() ?? user.displayName ?? '';
      _heightController.text = data['height']?.toString() ?? '';
      _weightController.text = data['weight']?.toString() ?? '';
      _stylePreferences = (data['stylePreferences'] as List? ?? const [])
          .map((value) => value.toString())
          .where(stylePreferenceOptions.contains)
          .toList();
    } catch (_) {
      Get.snackbar(
        'Could not load twin',
        'Please check your connection and try again.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: const Text('Edit Twin'),
      backgroundColor: Colors.white,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Update the details used to personalise your digital twin and recommendations.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickTwinPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(
                    _selectedTwinPhoto == null
                        ? 'Replace twin photo'
                        : 'Choose another photo',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Only use a clear, full-body photo. Changing it creates a new digital twin.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (_selectedTwinPhoto != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'New twin photo preview',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 360,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.file(
                      _selectedTwinPhoto!,
                      key: ValueKey(_selectedTwinPhoto!.path),
                      fit: BoxFit.contain,
                      cacheWidth: 900,
                      semanticLabel: 'Selected new twin photo',
                      frameBuilder: (context, child, frame, synchronous) =>
                          synchronous || frame != null
                          ? child
                          : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Could not preview this photo. Please choose another image.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This photo will be used when you save your twin changes.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _selectedTwinPhoto = null),
                    icon: const Icon(Icons.close),
                    label: const Text('Keep current twin photo'),
                  ),
                ],
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                ),
                const SizedBox(height: 22),
                StylePreferenceSelector(
                  selected: _stylePreferences,
                  onChanged: (preferences) =>
                      setState(() => _stylePreferences = preferences),
                ),
                const SizedBox(height: 32),
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save Twin Changes'),
                      ),
              ],
            ),
          ),
  );

  Future<void> _pickTwinPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      setState(() => _selectedTwinPhoto = File(image.path));
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    final name = _nameController.text.trim();
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    if (user == null) return;
    if (name.isEmpty ||
        height == null ||
        weight == null ||
        height <= 0 ||
        weight <= 0) {
      Get.snackbar(
        'Invalid details',
        'Enter a name and valid height and weight.',
      );
      return;
    }
    if (_stylePreferences.isEmpty) {
      Get.snackbar(
        'Style preferences needed',
        'Select at least one style preference.',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      String? twinId;
      bool? wearsHijab;
      String? photoUrl;
      if (_selectedTwinPhoto != null) {
        final bytes = await _selectedTwinPhoto!.readAsBytes();
        final filename = _selectedTwinPhoto!.path
            .split(Platform.pathSeparator)
            .last;
        final result = await AiService().createDigitalTwin(bytes, filename);
        final metadata = result['metadata'] as Map<String, dynamic>;
        twinId = result['twinId'] as String?;
        wearsHijab = metadata['wearsHijab'] as bool?;
        final processedBytes = base64Decode(result['personImageB64'] as String);
        final reference = FirebaseStorage.instance.ref(
          'users/${user.uid}/digital_twin_processed.jpg',
        );
        await reference.putData(
          processedBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        photoUrl = await reference.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': name,
        'height': _heightController.text.trim(),
        'weight': _weightController.text.trim(),
        'stylePreferences': _stylePreferences,
        'bodyType': FieldValue.delete(),
        'digitalTwinPhotoUrl': ?photoUrl,
        'twinId': ?twinId,
        'wearsHijab': ?wearsHijab,
        'isProfileComplete': true,
      }, SetOptions(merge: true));
      if (mounted) Get.back();
      Get.snackbar('Twin updated', 'Your changes were saved.');
    } on AiServiceException catch (error) {
      Get.snackbar('Could not update twin', error.message);
    } catch (error) {
      Get.snackbar('Could not update twin', error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
