import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/liked_outfits_service.dart';

class MyOutfitsScreen extends StatefulWidget {
  const MyOutfitsScreen({super.key});

  @override
  State<MyOutfitsScreen> createState() => _MyOutfitsScreenState();
}

class _MyOutfitsScreenState extends State<MyOutfitsScreen> {
  String _filter = 'all';

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
                  .collection('likedOutfits')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Could not load your saved outfits.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final outfits = snapshot.data!.docs.where((document) {
                  return _filter == 'all' ||
                      document.data()['source'] == _filter;
                }).toList();
                return Column(
                  children: [
                    _filters(),
                    Expanded(
                      child: outfits.isEmpty
                          ? _emptyState(snapshot.data!.docs.isEmpty)
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    childAspectRatio: .63,
                                  ),
                              itemCount: outfits.length,
                              itemBuilder: (_, index) =>
                                  _outfitTile(outfits[index]),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _filters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
    child: Row(
      children: [
        _filterChip('all', 'All Outfits'),
        const SizedBox(width: 8),
        _filterChip(OutfitSource.tryOn, 'VTON'),
        const SizedBox(width: 8),
        _filterChip(OutfitSource.inspoMirror, 'AI Inspo Mirror'),
      ],
    ),
  );

  Widget _filterChip(String value, String label) => ChoiceChip(
    label: Text(label),
    selected: _filter == value,
    selectedColor: Colors.black,
    labelStyle: TextStyle(
      color: _filter == value ? Colors.white : Colors.black87,
      fontWeight: FontWeight.w600,
    ),
    onSelected: (_) => setState(() => _filter = value),
  );

  Widget _emptyState(bool noOutfitsAtAll) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 58,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            noOutfitsAtAll
                ? 'No saved outfits yet. Generate a Virtual Try-On, then tap Save Outfit to keep it here.'
                : 'No outfits match this filter.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  Widget _outfitTile(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final source = data['source'] == OutfitSource.inspoMirror
        ? 'AI Inspo Mirror'
        : 'VTON';
    final createdAt = data['createdAt'] as Timestamp?;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _details(document),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ColoredBox(
                color: Colors.grey.shade100,
                child: Image.network(
                  data['imageUrl']?.toString() ?? '',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                  loadingBuilder: (_, child, loading) => loading == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['title']?.toString().trim().isNotEmpty == true
                ? data['title'].toString()
                : '$source Outfit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '${_date(createdAt)} · $source',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _date(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  void _details(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();
    final source = data['source'] == OutfitSource.inspoMirror
        ? 'AI Inspo Mirror'
        : 'VTON';
    Get.dialog(
      Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  data['imageUrl']?.toString() ?? '',
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 180,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data['title']?.toString().trim().isNotEmpty == true
                    ? data['title'].toString()
                    : '$source Outfit',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text('${_date(data['createdAt'] as Timestamp?)} · $source'),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _confirmDelete(document.reference, data),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data,
  ) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete outfit?'),
        content: const Text(
          'This saved outfit and its image will be permanently removed.',
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              Get.back();
              try {
                await LikedOutfitsService.unlike(reference, data);
                Get.snackbar(
                  'Outfit deleted',
                  'It was removed from My Outfits.',
                );
              } catch (_) {
                Get.snackbar('Could not delete outfit', 'Please try again.');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
