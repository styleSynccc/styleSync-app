import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_controller.dart';
import '../services/closet_controller.dart';
import 'outfit_creator_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Map<String, List<String>> _categoryAssets = {
    'Tops': [
      'assets/images/tops/tshirt_black.png',
      'assets/images/tops/polo_grey.png',
      'assets/images/tops/buttonup_beige.png',
    ],
    'Pants': [
      'assets/images/pants/jeans_blue.png',
      'assets/images/pants/jeans_black.png',
      'assets/images/pants/dark_jjeans.jpg',
    ],
    'Shoes': [
      'assets/images/shoes/timberland_black.png',
      'assets/images/shoes/converse_black.png',
    ],
    'Accessories': [
      'assets/images/accessories/bracelet_silver.png',
      'assets/images/accessories/blackbelt.png',
      'assets/images/accessories/brownbelt.png',
      'assets/images/accessories/brownbrownbelt.webp',
      'assets/images/accessories/rolex.jpg',
      'assets/images/accessories/watch-isolated-on-transparent-background-free-png.webp',
    ],
  };

  static const List<String> _categoryOrder = [
    'Tops',
    'Pants',
    'Shoes',
    'Accessories',
  ];

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find();
    final ClosetController closetController = Get.put(ClosetController());
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Instagram-style Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Invisible spacer to balance the row
                    const SizedBox(width: 40), 
                    // Centered Logo
                    Image.asset(
                      'assets/images/stylesync_letterings.png',
                      height: 40,
                      errorBuilder: (context, error, stackTrace) {
                        return const Text(
                          'StyleSync',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                    // Right Side: Profile Icon
                    IconButton(
                      icon: const Icon(Icons.person, color: Colors.black54),
                      onPressed: () => Get.toNamed('/profile'),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                
                // Welcome Text
                const Text('Welcome,', style: TextStyle(fontSize: 18, color: Colors.grey)),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Loading...', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
                    }
                    if (snapshot.hasData && snapshot.data!.exists) {
                      var data = snapshot.data!.data() as Map<String, dynamic>?;
                      return Text(
                        '${data?['name'] ?? 'User'}!',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      );
                    }
                    return const Text('User!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold));
                  },
                ),
                const SizedBox(height: 30),
                
                // My Closet Title & Single Plus Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('My Closet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        Obx(() => Text(
                          '${closetController.clothes.length} Items',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        )),
                        const SizedBox(width: 8),
                        // The Single Plus Button
                        Obx(() => IconButton(
                          icon: Icon(
                            closetController.isAddExpanded.value ? Icons.close : Icons.add,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            closetController.isAddExpanded.value = !closetController.isAddExpanded.value;
                          },
                        )),
                      ],
                    ),
                  ],
                ),
                
                // EXPANDABLE CATEGORY BUTTONS
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Obx(() => closetController.isAddExpanded.value
                    ? Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildAddCategoryButton('Tops', closetController),
                          _buildAddCategoryButton('Pants', closetController),
                          _buildAddCategoryButton('Shoes', closetController),
                          _buildAddCategoryButton('Accessories', closetController),
                        ],
                      )
                    : const SizedBox.shrink() // Hides when collapsed
                  ),
                ),
                const SizedBox(height: 20),
                
                // Closet Grid
                Obx(() {
                  if (closetController.isLoading.value && closetController.clothes.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (closetController.clothes.isEmpty) {
                    return Container(
                      height: 300,
                      alignment: Alignment.center,
                      child: const Text('Your closet is empty.\nTap the + button above to add clothes!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    );
                  }

                  final sortedClothes = closetController.clothes.toList()
                    ..sort((first, second) {
                      final firstIndex = _categoryOrder.indexOf(first.category);
                      final secondIndex = _categoryOrder.indexOf(second.category);
                      final safeFirst = firstIndex == -1
                          ? _categoryOrder.length
                          : firstIndex;
                      final safeSecond = secondIndex == -1
                          ? _categoryOrder.length
                          : secondIndex;
                      return safeFirst.compareTo(safeSecond);
                    });
                  
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: sortedClothes.length,
                    itemBuilder: (context, index) {
                      var item = sortedClothes[index];
                      final dynamic closetItem = item;
                      final String? assetPath = closetItem.assetPath as String?;
                      final image = assetPath != null && assetPath.isNotEmpty
                          ? AssetImage(assetPath) as ImageProvider
                          : NetworkImage(item.imageUrl);
                      return GestureDetector(
                        onTap: () => _showImageGallery(
                          sortedClothes,
                          index,
                        ),
                        onLongPress: () =>
                            _confirmDelete(item, closetController),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            image: DecorationImage(
                              image: image,
                              fit: BoxFit.contain,
                            ),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: Text(item.category,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left Side
              IconButton(
                icon: const Icon(Icons.home, size: 28, color: Colors.black),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.face_retouching_natural, size: 28, color: Colors.black54),
                onPressed: () {
                  Get.toNamed('/try-on');
                },
              ),
              
              // Space for the FAB
              const SizedBox(width: 40), 
              
              // Right Side
              IconButton(
                icon: const Icon(Icons.auto_awesome, size: 28, color: Colors.black54),
                onPressed: () {
                  Get.toNamed('/inspo');
                },
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month, size: 28, color: Colors.black54),
                onPressed: () {
                  Get.toNamed('/planner');
                },
              ),
            ],
          ),
        ),
      ),
      
      // Floating Add Button for Outfits
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const OutfitCreatorScreen()),
        backgroundColor: Colors.black,
        elevation: 4,
        child: const Icon(Icons.checkroom, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // Helper widget for the small add buttons
  Widget _buildAddCategoryButton(String category, ClosetController controller) {
    return ActionChip(
      label: Text(category),
      avatar: const Icon(Icons.add, size: 18),
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: Colors.grey.shade300),
      onPressed: () {
        controller.isAddExpanded.value = false; // Close the menu after tapping
        _showCategoryPicker(category, controller);
      },
    );
  }

  void _showCategoryPicker(String category, ClosetController controller) {
    final assets = _categoryAssets[category] ?? const <String>[];

    Get.bottomSheet(
      SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: Get.height * 0.72),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose $category', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Pick one below or add a picture from your gallery.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 18),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: assets.length + 1,
                  itemBuilder: (context, index) {
                    if (index == assets.length) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Get.back();
                          _showClothingPhotoSource(category, controller);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 34),
                              SizedBox(height: 8),
                              Text('Your photo', textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      );
                    }

                    final assetPath = assets[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Get.back();
                        final dynamic closetController = controller;
                        closetController.addAssetClothingItem(
                          category,
                          assetPath,
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ColoredBox(
                          color: Colors.grey.shade100,
                          child: Image.asset(assetPath, fit: BoxFit.contain),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _confirmDelete(ClothingItem item, ClosetController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('Remove item?'),
        content: Text(
          'Do you want to remove this ${item.category.toLowerCase()} item from your closet?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              final dynamic closetController = controller;
              closetController.deleteClothingItem(item);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClothingPhotoSource(
    String category,
    ClosetController controller,
  ) {
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
              Text(
                'Add Your $category Photo',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a photo'),
                onTap: () {
                  Get.back();
                  final dynamic closetController = controller;
                  closetController.uploadClothingItem(
                    category,
                    source: ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Get.back();
                  final dynamic closetController = controller;
                  closetController.uploadClothingItem(
                    category,
                    source: ImageSource.gallery,
                  );
                },
              ),
            ],
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  void _showImageGallery(List<ClothingItem> items, int initialIndex) {
    final pageController = PageController(initialPage: initialIndex);
    var currentIndex = initialIndex;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setDialogState) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  controller: pageController,
                  itemCount: items.length,
                  onPageChanged: (index) {
                    setDialogState(() => currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final dynamic closetItem = item;
                    final String? assetPath =
                        closetItem.assetPath as String?;

                    return InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: assetPath != null && assetPath.isNotEmpty
                            ? Image.asset(
                                assetPath,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              )
                            : Image.network(
                                item.imageUrl,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (context, child, progress) =>
                                    progress == null
                                        ? child
                                        : const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white,
                                  size: 60,
                                ),
                              ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 70,
                  right: 70,
                  child: Text(
                    '${items[currentIndex].category}  •  ${currentIndex + 1}/${items.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (items.length > 1)
                  const Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Text(
                      'Swipe to see more',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      barrierColor: Colors.black,
    ).whenComplete(pageController.dispose);
  }
}
