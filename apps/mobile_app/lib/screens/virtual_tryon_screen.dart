import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/ai_service.dart';
import '../services/closet_controller.dart';
import 'edit_profile_screen.dart';

/// Wardrobe categories FastFit can put on (apps/ai_service TRYON_CATEGORIES).
const List<String> tryOnCategories = ['Tops', 'Pants', 'Shoes'];

/// One item put on the twin, and the image of the twin wearing everything
/// up to and including it.
class _TryOnStep {
  final ClothingItem item;
  final String resultId;
  final Uint8List image;
  _TryOnStep(this.item, this.resultId, this.image);
}

/// Dresses the digital twin one item at a time (docs/virtual-tryon/README.md):
/// pick a cloth -> generate -> show -> add more or delete. Each new item is
/// generated on top of the previous result, so earlier items stay on.
class VirtualTryOnScreen extends StatefulWidget {
  const VirtualTryOnScreen({super.key});

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  final AiService _ai = AiService();
  final ClosetController _closet = Get.isRegistered<ClosetController>()
      ? Get.find<ClosetController>()
      : Get.put(ClosetController());

  bool _loadingProfile = true;
  String? _twinId;
  String _twinPhotoUrl = '';
  List<_TryOnStep> _steps = [];
  String? _busyMessage;
  bool _showBefore = false;

  bool get _busy => _busyMessage != null;

  @override
  void initState() {
    super.initState();
    _loadTwin();
  }

  Future<void> _loadTwin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      _twinId = data['twinId'] as String?;
      _twinPhotoUrl = data['digitalTwinPhotoUrl']?.toString() ?? '';
    }
    if (mounted) setState(() => _loadingProfile = false);
  }

  // --- Add / replace / delete -------------------------------------------

  void _addItem(ClothingItem item) {
    final items = _steps.map((s) => s.item).toList();
    final sameCategory = items.indexWhere((i) => i.category == item.category);
    if (sameCategory >= 0) {
      // A second top replaces the first; items put on after it are redone.
      items[sameCategory] = item;
      _rebuildFrom(sameCategory, items);
    } else {
      _rebuildFrom(items.length, [...items, item]);
    }
  }

  void _removeAt(int index) {
    if (index == _steps.length - 1) {
      // Last item: the previous image is already here, no AI call needed.
      setState(() => _steps = _steps.sublist(0, index));
      return;
    }
    final items = _steps.map((s) => s.item).toList()..removeAt(index);
    _rebuildFrom(index, items);
  }

  /// Keeps steps before [start] and regenerates [items] from [start] on.
  Future<void> _rebuildFrom(int start, List<ClothingItem> items) async {
    final kept = _steps.sublist(0, start);
    final isSimpleAdd = start == _steps.length && items.length == start + 1;
    setState(() {
      _showBefore = false;
      _busyMessage = isSimpleAdd ? 'Dressing your twin...' : 'Updating your look...';
    });
    try {
      for (var i = start; i < items.length; i++) {
        if (!isSimpleAdd) {
          setState(() => _busyMessage = 'Putting on ${items[i].category} (${i - start + 1}/${items.length - start})...');
        }
        final result = await _ai.tryOn(
          twinId: _twinId!,
          garmentItemId: items[i].itemId!,
          startFromResultId: kept.isEmpty ? null : kept.last.resultId,
        );
        kept.add(_TryOnStep(
          items[i],
          result['resultId'] as String,
          base64Decode(result['resultImageB64'] as String),
        ));
      }
    } on AiServiceException catch (e) {
      Get.snackbar('Try-on failed', e.message, duration: const Duration(seconds: 5));
    } finally {
      // On failure this keeps whatever finished, which is still a valid look.
      if (mounted) {
        setState(() {
          _steps = kept;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _confirmReset() async {
    final ok = await Get.dialog<bool>(AlertDialog(
      title: const Text('Remove all clothes?'),
      content: const Text('Your twin goes back to the original photo.'),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('Reset')),
      ],
    ));
    if (ok == true) setState(() => _steps = []);
  }

  // --- Save Look ----------------------------------------------------------

  Future<void> _saveLook() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _steps.isEmpty) return;
    final controller = TextEditingController();
    final name = await Get.dialog<String>(AlertDialog(
      title: const Text('Name your look'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'e.g. Casual Friday'),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Get.back(result: controller.text.trim()), child: const Text('Save')),
      ],
    ));
    if (name == null || name.isEmpty) return;

    setState(() => _busyMessage = 'Saving your look...');
    try {
      final last = _steps.last;
      final ref = FirebaseStorage.instance.ref().child('users/${user.uid}/looks/${last.resultId}.jpg');
      await ref.putData(last.image, SettableMetadata(contentType: 'image/jpeg'));
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('outfits').add({
        'name': name,
        'source': 'tryon',
        'resultImageUrl': await ref.getDownloadURL(),
        'items': _steps
            .map((s) => {
                  'id': s.item.id,
                  'category': s.item.category,
                  'imageUrl': s.item.imageUrl,
                  'itemId': s.item.itemId,
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      Get.snackbar('Saved', '$name was added to your saved outfits.');
    } catch (e) {
      Get.snackbar('Could not save look', e.toString());
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  // --- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: const Text('Virtual Try-On', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          if (_steps.isNotEmpty)
            TextButton(onPressed: _busy ? null : _confirmReset, child: const Text('Reset')),
        ],
      ),
      body: SafeArea(
        child: _loadingProfile
            ? const Center(child: CircularProgressIndicator())
            : _twinId == null
                ? _noTwin()
                : _tryOnBody(),
      ),
    );
  }

  Widget _noTwin() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.accessibility_new, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Create your digital twin first',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a full-body photo in your profile, then come back to try clothes on.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await Get.to(() => const EditProfileScreen());
                setState(() => _loadingProfile = true);
                _loadTwin();
              },
              child: const Text('Go to Profile'),
            ),
          ]),
        ),
      );

  Widget _tryOnBody() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(children: [
          Expanded(child: _imageArea()),
          if (_steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Before')),
                ButtonSegment(value: false, label: Text('After')),
              ],
              selected: {_showBefore},
              onSelectionChanged: _busy ? null : (v) => setState(() => _showBefore = v.first),
            ),
          ],
          const SizedBox(height: 10),
          _wearingList(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _openPicker,
                icon: const Icon(Icons.add),
                label: const Text('Add cloth'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _busy || _steps.isEmpty ? null : _saveLook,
                child: const Text('Save Look'),
              ),
            ),
          ]),
        ]),
      );

  Widget _imageArea() {
    final Widget image = _steps.isEmpty || _showBefore
        ? (_twinPhotoUrl.isEmpty
            ? const Icon(Icons.accessibility_new, size: 80, color: Colors.grey)
            : Image.network(_twinPhotoUrl, fit: BoxFit.contain))
        : Image.memory(_steps.last.image, fit: BoxFit.contain, gaplessPlayback: true);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        image,
        if (_busy)
          Container(
            color: Colors.white.withValues(alpha: 0.75),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(_busyMessage!, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('This can take up to a minute.', style: TextStyle(color: Colors.grey)),
            ]),
          ),
      ]),
    );
  }

  Widget _wearingList() {
    if (_steps.isEmpty) {
      return const Text('Tap "Add cloth" to try something on.', style: TextStyle(color: Colors.grey));
    }
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _steps.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final item = _steps[index].item;
          return Container(
            width: 150,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              SizedBox(width: 50, height: 62, child: _itemImage(item)),
              const SizedBox(width: 6),
              Expanded(child: Text(item.category, style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Remove',
                onPressed: _busy ? null : () => _removeAt(index),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _itemImage(ClothingItem item) => item.isAsset
      ? Image.asset(item.assetPath!, fit: BoxFit.contain)
      : Image.network(item.imageUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image));

  void _openPicker() {
    final worn = {for (final s in _steps) s.item.category: s.item};
    Get.bottomSheet(
      DefaultTabController(
        length: tryOnCategories.length,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 14),
            const Text('Choose a cloth', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TabBar(tabs: [for (final c in tryOnCategories) Tab(text: c)]),
            Expanded(
              child: TabBarView(children: [
                for (final category in tryOnCategories) _pickerGrid(category, worn[category]),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                'Only photos you uploaded can be tried on. Sample items and accessories are not supported yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ]),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _pickerGrid(String category, ClothingItem? wornItem) {
    final inCategory = _closet.clothes.where((i) => i.category == category).toList();
    final items = inCategory.where((i) => i.itemId != null).toList();
    if (items.isEmpty) {
      // Sample items and photos added before the AI service was connected
      // have no itemId, so the AI service can't find them.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            inCategory.isEmpty
                ? 'No $category in your closet yet.\nAdd a photo in your closet first.'
                : 'Your ${inCategory.length} $category in the closet are sample items or were added '
                    'before AI processing, so they can\'t be tried on.\n\n'
                    'Add the photo again from your closet to use it here.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return Column(children: [
      if (wornItem != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('Picking one replaces your current ${category.toLowerCase()}.',
              style: const TextStyle(color: Colors.orange, fontSize: 12)),
        ),
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(14),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3 / 4,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) {
            final item = items[index];
            final isWorn = wornItem?.id == item.id;
            return InkWell(
              onTap: isWorn
                  ? null
                  : () {
                      Get.back();
                      _addItem(item);
                    },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isWorn ? Colors.green : Colors.transparent, width: 3),
                ),
                child: _itemImage(item),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
