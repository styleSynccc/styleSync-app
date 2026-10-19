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
                              itemBuilder: (_, index) => _outfitTile(
                                outfits[index],
                                onTap: () => _details(outfits, index),
                              ),
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
                ? 'No saved outfits yet. Generate a Virtual Try-On or AI Inspo Mirror look, then tap Save Outfit to keep it here.'
                : 'No outfits match this filter.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  Widget _outfitTile(
    QueryDocumentSnapshot<Map<String, dynamic>> document, {
    required VoidCallback onTap,
  }) {
    final data = document.data();
    final source = data['source'] == OutfitSource.inspoMirror
        ? 'AI Inspo Mirror'
        : 'VTON';
    final createdAt = data['createdAt'] as Timestamp?;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
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

  Future<void> _details(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    int initialIndex,
  ) async {
    final pages = PageController(initialPage: initialIndex);
    final zoomControllers = List.generate(
      documents.length,
      (_) => TransformationController(),
    );
    var currentIndex = initialIndex;
    var zoomed = false;
    try {
      await Get.dialog(
        StatefulBuilder(
          builder: (context, update) {
            final document = documents[currentIndex];
            final data = document.data();
            final source = data['source'] == OutfitSource.inspoMirror
                ? 'AI Inspo Mirror'
                : 'VTON';
            return Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Close photo',
                            onPressed: Get.back,
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                          Expanded(
                            child: Text(
                              data['title']?.toString().trim().isNotEmpty ==
                                      true
                                  ? data['title'].toString()
                                  : '$source Outfit',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete outfit',
                            onPressed: () =>
                                _confirmDelete(document.reference, data),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: pages,
                        itemCount: documents.length,
                        physics: zoomed
                            ? const NeverScrollableScrollPhysics()
                            : null,
                        onPageChanged: (index) {
                          zoomControllers[currentIndex].value =
                              Matrix4.identity();
                          zoomControllers[index].value = Matrix4.identity();
                          update(() {
                            currentIndex = index;
                            zoomed = false;
                          });
                        },
                        itemBuilder: (context, index) {
                          final photo = documents[index].data();
                          return InteractiveViewer(
                            key: ValueKey(documents[index].id),
                            transformationController: zoomControllers[index],
                            minScale: 1,
                            maxScale: 5,
                            panEnabled: zoomed && index == currentIndex,
                            onInteractionUpdate: (_) {
                              final isZoomed =
                                  zoomControllers[index].value
                                      .getMaxScaleOnAxis() >
                                  1.01;
                              if (index == currentIndex && zoomed != isZoomed) {
                                update(() => zoomed = isZoomed);
                              }
                            },
                            child: SizedBox.expand(
                              child: Image.network(
                                photo['imageUrl']?.toString() ?? '',
                                fit: BoxFit.contain,
                                semanticLabel:
                                    'Outfit photo ${index + 1} of ${documents.length}',
                                loadingBuilder: (_, child, loading) =>
                                    loading == null
                                    ? child
                                    : const Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                errorBuilder: (_, _, _) => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Could not load this outfit photo. Check your connection and open it again.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Column(
                        children: [
                          Text(
                            '${_date(data['createdAt'] as Timestamp?)} · $source',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Previous outfit',
                                onPressed: zoomed || currentIndex == 0
                                    ? null
                                    : () => pages.previousPage(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeOut,
                                      ),
                                color: Colors.white,
                                disabledColor: Colors.white24,
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Text(
                                '${currentIndex + 1} / ${documents.length}',
                                style: const TextStyle(color: Colors.white),
                              ),
                              IconButton(
                                tooltip: 'Next outfit',
                                onPressed:
                                    zoomed ||
                                        currentIndex == documents.length - 1
                                    ? null
                                    : () => pages.nextPage(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        curve: Curves.easeOut,
                                      ),
                                color: Colors.white,
                                disabledColor: Colors.white24,
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                          if (zoomed)
                            TextButton.icon(
                              onPressed: () {
                                zoomControllers[currentIndex].value =
                                    Matrix4.identity();
                                update(() => zoomed = false);
                              },
                              icon: const Icon(
                                Icons.zoom_out_map,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Reset zoom to browse outfits',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          else if (documents.length > 1)
                            const Text(
                              'Swipe left or right to browse outfits',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          const SizedBox(height: 6),
                          const Text(
                            'Pinch to zoom · Drag to explore',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      pages.dispose();
      for (final controller in zoomControllers) {
        controller.dispose();
      }
    }
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
