import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/closet_controller.dart';

class OutfitCreatorScreen extends StatefulWidget {
  const OutfitCreatorScreen({super.key, this.auth, this.firestore});

  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  @override
  State<OutfitCreatorScreen> createState() => _OutfitCreatorScreenState();
}

class _OutfitCreatorScreenState extends State<OutfitCreatorScreen> {
  final closet = Get.find<ClosetController>();
  final selected = <String, ClothingItem>{};
  final categories = const ['Tops', 'Pants', 'Shoes', 'Accessories'];

  CollectionReference<Map<String, dynamic>>? get outfits {
    final user = (widget.auth ?? FirebaseAuth.instance).currentUser;
    return user == null
        ? null
        : (widget.firestore ?? FirebaseFirestore.instance)
              .collection('users')
              .doc(user.uid)
              .collection('outfits');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text('Outfit Creator'), backgroundColor: Colors.white),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Container(
        constraints: const BoxConstraints(minHeight: 170),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
        child: selected.isEmpty
            ? const Center(child: Text('Choose items below to build an outfit', style: TextStyle(color: Colors.grey)))
            : Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: selected.values.map((item) => SizedBox(width: 105, height: 140, child: _itemImage(item))).toList()),
      ),
      const SizedBox(height: 14),
      ElevatedButton(onPressed: selected.isEmpty ? null : _nameAndSave, child: const Text('Save Outfit')),
      const SizedBox(height: 22),
      ...categories.map(_categorySection),
      const SizedBox(height: 20),
      const Text('Saved Outfits', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      if (outfits != null) StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: outfits!.orderBy('createdAt', descending: true).snapshots(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Text('No saved outfits yet.', style: TextStyle(color: Colors.grey));
          return Column(children: snapshot.data!.docs.map(_savedOutfit).toList());
        },
      ),
    ]),
  );

  Widget _categorySection(String category) {
    final items = closet.clothes.where((item) => item.category == category).toList();
    return Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(category, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        if (selected.containsKey(category)) TextButton(onPressed: () => setState(() => selected.remove(category)), child: const Text('Clear')),
      ]),
      if (items.isEmpty) const Text('No items in this category', style: TextStyle(color: Colors.grey))
      else SizedBox(height: 125, child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: items.length, separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final item = items[index]; final active = selected[category]?.id == item.id;
          return InkWell(onTap: () => setState(() => selected[category] = item), child: Container(
            width: 95, padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14), border: Border.all(color: active ? Colors.green : Colors.transparent, width: 3)),
            child: Stack(children: [Positioned.fill(child: _itemImage(item)), if (active) const Align(alignment: Alignment.topRight, child: Icon(Icons.check_circle, color: Colors.green))]),
          ));
        },
      )),
    ]));
  }

  Widget _itemImage(ClothingItem item) {
    final dynamic value = item;
    final String? asset = value.assetPath as String?;
    return asset != null && asset.isNotEmpty
        ? Image.asset(asset, fit: BoxFit.contain)
        : Image.network(item.imageUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image));
  }

  Widget _savedOutfit(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final items = (data['items'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    return Card(child: ListTile(
      title: Text(data['name'] ?? 'Outfit', style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${items.length} items'),
      leading: const Icon(Icons.checkroom),
      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => doc.reference.delete()),
      onTap: () => Get.dialog(Dialog(child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(data['name'] ?? 'Outfit', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Wrap(spacing: 8, runSpacing: 8, children: items.map((item) => SizedBox(width: 100, height: 130, child: _storedImage(item))).toList()),
      ])))),
    ));
  }

  Widget _storedImage(Map<String, dynamic> item) {
    final asset = item['assetPath'] as String?;
    return asset != null ? Image.asset(asset, fit: BoxFit.contain) : Image.network(item['imageUrl'] ?? '', fit: BoxFit.contain);
  }

  Future<void> _nameAndSave() async {
    final outfitCollection = outfits;
    if (outfitCollection == null) {
      Get.snackbar('Sign in required', 'Please sign in before saving an outfit.');
      return;
    }

    final controller = TextEditingController();
    final name = await Get.dialog<String>(AlertDialog(
      title: const Text('Name your outfit'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. Casual Friday')),
      actions: [TextButton(onPressed: () => Get.back(), child: const Text('Cancel')), ElevatedButton(onPressed: () => Get.back(result: controller.text.trim()), child: const Text('Save'))],
    ));
    // GetX may still be animating the dialog closed, so the text controller
    // must not be disposed immediately after the result is returned.
    if (name == null || name.isEmpty) return;
    final items = selected.values.map((item) {
      final dynamic value = item; final String? asset = value.assetPath as String?;
      return {'id': item.id, 'category': item.category, 'imageUrl': item.imageUrl, if (asset != null) 'assetPath': asset};
    }).toList();
    try {
      await outfitCollection.add({
        'name': name,
        'items': items,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => selected.clear());
      Get.snackbar('Saved', '$name was added to your outfits.');
    } catch (error) {
      Get.snackbar('Could not save outfit', error.toString());
    }
  }
}
