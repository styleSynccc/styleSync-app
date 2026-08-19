import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SavedOutfitsScreen extends StatelessWidget {
  const SavedOutfitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Outfits'),
        backgroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to see your outfits.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('outfits')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Could not load your outfits.'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final outfits = snapshot.data!.docs;
                if (outfits.isEmpty) {
                  return const Center(
                    child: Text(
                      'No saved outfits yet.\nCreate one from the home screen!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: outfits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, index) => _outfitCard(outfits[index]),
                );
              },
            ),
    );
  }

  Widget _outfitCard(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final items = (data['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                data['name'] ?? 'Outfit',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(document.reference),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) => Container(
                width: 105,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _image(items[index]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _image(Map<String, dynamic> item) {
    final asset = item['assetPath'] as String?;
    return asset != null && asset.isNotEmpty
        ? Image.asset(asset, fit: BoxFit.contain)
        : Image.network(
            item['imageUrl'] ?? '',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
          );
  }

  void _confirmDelete(DocumentReference<Map<String, dynamic>> reference) {
    Get.dialog(AlertDialog(
      title: const Text('Delete outfit?'),
      content: const Text('This saved outfit will be removed.'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            Get.back();
            await reference.delete();
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }
}
