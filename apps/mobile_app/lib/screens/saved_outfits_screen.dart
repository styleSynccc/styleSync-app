import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/liked_outfits_service.dart';
import '../services/notification_service.dart';
import '../models/outfit_plan.dart';
import '../widgets/outfit_preview.dart';

class _GalleryOutfit {
  _GalleryOutfit(
    QueryDocumentSnapshot<Map<String, dynamic>> document, {
    bool planner = false,
  }) : reference = document.reference,
       _data = planner ? plannerGalleryData(document.data()) : document.data();

  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic> _data;
  String get id => reference.path;
  Map<String, dynamic> data() => _data;
}

class MyOutfitsScreen extends StatefulWidget {
  const MyOutfitsScreen({super.key});

  @override
  State<MyOutfitsScreen> createState() => _MyOutfitsScreenState();
}

class _MyOutfitsScreenState extends State<MyOutfitsScreen> {
  String _filter = 'all';
  late final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _saved = _uid == null
      ? null
      : FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('likedOutfits')
            .snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _planned =
      _uid == null
      ? null
      : FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('outfitPlans')
            .snapshots();

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
              stream: _saved,
              builder: (context, saved) =>
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _planned,
                    builder: (context, planned) => _gallery(saved, planned),
                  ),
            ),
    );
  }

  Widget _gallery(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> saved,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> planned,
  ) {
    if ((!saved.hasData && !saved.hasError) ||
        (!planned.hasData && !planned.hasError)) {
      return const Center(child: CircularProgressIndicator());
    }
    final all =
        [
          for (final document
              in saved.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            _GalleryOutfit(document),
          for (final document
              in planned.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[])
            _GalleryOutfit(document, planner: true),
        ]..sort((a, b) {
          final first = a.data()['createdAt'];
          final second = b.data()['createdAt'];
          final comparison =
              (second is Timestamp ? second.millisecondsSinceEpoch : 0)
                  .compareTo(
                    first is Timestamp ? first.millisecondsSinceEpoch : 0,
                  );
          return comparison == 0 ? a.id.compareTo(b.id) : comparison;
        });
    final outfits = all
        .where((entry) => _filter == 'all' || entry.data()['source'] == _filter)
        .toList();
    return Column(
      children: [
        _filters(),
        if (saved.hasError || planned.hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              saved.hasError && planned.hasError
                  ? 'Could not load your outfits. Check your connection and reopen this page.'
                  : saved.hasError
                  ? 'Could not load generated outfits. Your planner outfits are shown below.'
                  : 'Could not load planner outfits. Your generated outfits are shown below.',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        Expanded(
          child: outfits.isEmpty
              ? (saved.hasError || planned.hasError)
                    ? const Center(
                        child: Text('Some outfits could not be loaded.'),
                      )
                    : _emptyState(all.isEmpty)
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
        const SizedBox(width: 8),
        _filterChip(OutfitSource.planner, 'Outfit Planner'),
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
                ? 'No saved outfits yet. Save a look from Virtual Try-On or AI Inspo Mirror, or create an outfit in Outfit Planner.'
                : 'No outfits match this filter.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ),
  );

  Widget _outfitTile(_GalleryOutfit document, {required VoidCallback onTap}) {
    final data = document.data();
    final source = outfitSourceLabel(data['source']);
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
                child: OutfitPreview(data: data),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
    List<_GalleryOutfit> documents,
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
            final source = outfitSourceLabel(data['source']);
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
                              child: OutfitPreview(
                                data: photo,
                                fit: BoxFit.contain,
                                detailed: true,
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
        content: Text(
          data['source'] == OutfitSource.planner
              ? 'This will delete the outfit from My Outfits and Outfit Planner and cancel its reminder. Your closet items will be kept.'
              : 'This saved outfit and its image will be permanently removed.',
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              Get.back();
              try {
                if (data['source'] == OutfitSource.planner) {
                  await reference.delete();
                  final notificationId = data['notificationId'];
                  if (notificationId is int) {
                    try {
                      await NotificationService.instance.cancel(notificationId);
                    } catch (_) {
                      Get.snackbar(
                        'Reminder could not be cancelled',
                        'The outfit was deleted. Check your phone reminders.',
                      );
                      return;
                    }
                  }
                } else {
                  await LikedOutfitsService.unlike(reference, data);
                }
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
