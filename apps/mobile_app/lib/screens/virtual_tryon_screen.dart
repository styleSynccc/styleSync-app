import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/ai_service.dart';
import '../services/closet_controller.dart';
import '../services/liked_outfits_service.dart';
import '../widgets/generation_progress.dart';
import 'edit_profile_screen.dart';

class VirtualTryOnScreen extends StatefulWidget {
  const VirtualTryOnScreen({super.key, this.aiService});

  final AiService? aiService;

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  late final AiService _aiService = widget.aiService ?? AiService();
  late final ClosetController _closet = Get.isRegistered<ClosetController>()
      ? Get.find<ClosetController>()
      : Get.put(ClosetController());
  Worker? _closetWorker;

  Set<String> get _closetItemIds => _closet.clothes
      .map((item) => item.tryOnItemId)
      .whereType<String>()
      .toSet();

  List<_TryOnChoice> _twins = const [];
  List<_TryOnChoice> _tops = const [];
  List<_TryOnChoice> _bottoms = const [];
  List<_TryOnChoice> _shoes = const [];
  List<_TryOnChoice> _accessories = const [];
  String? _selectedTwinId;
  String? _selectedTopId;
  String? _selectedBottomId;
  String? _selectedShoesId;
  final Set<String> _selectedAccessoryIds = {};
  static const _maxAccessories = 5;
  Uint8List? _resultImage;
  String? _error;
  bool _loading = true;
  bool _generating = false;
  int _refreshCount = 0;
  final ScrollController _scrollController = ScrollController();
  final Stopwatch _generationStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _closetWorker = ever(_closet.clothes, (_) => _removeDeletedChoices());
    _loadChoices();
  }

  @override
  void dispose() {
    _generationStopwatch.stop();
    _closetWorker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _removeDeletedChoices() {
    if (!mounted) return;
    final ids = _closetItemIds;
    setState(() {
      _tops = _tops.where((item) => ids.contains(item.id)).toList();
      _bottoms = _bottoms.where((item) => ids.contains(item.id)).toList();
      _shoes = _shoes.where((item) => ids.contains(item.id)).toList();
      _accessories = _accessories
          .where((item) => ids.contains(item.id))
          .toList();
      if (!ids.contains(_selectedTopId)) _selectedTopId = null;
      if (!ids.contains(_selectedBottomId)) _selectedBottomId = null;
      if (!ids.contains(_selectedShoesId)) _selectedShoesId = null;
      _selectedAccessoryIds.removeWhere((id) => !ids.contains(id));
    });
  }

  Future<void> _loadChoices({bool newOutfit = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (newOutfit) {
        _refreshCount++;
        _resultImage = null;
        _selectedTwinId = null;
        _selectedTopId = null;
        _selectedBottomId = null;
        _selectedShoesId = null;
        _selectedAccessoryIds.clear();
        _twins = const [];
        _tops = const [];
        _bottoms = const [];
        _shoes = const [];
        _accessories = const [];
      }
    });
    try {
      final assetSyncWarning = await _closet.syncWardrobeItemsForTryOn();
      await _closet.fetchClothes();
      final responses = await Future.wait<List<dynamic>>([
        _aiService.listTwins(),
        _aiService.listWardrobe(),
      ]);
      final twins = responses[0]
          .map((value) => _TryOnChoice.fromTwin(value as Map<String, dynamic>))
          .toList();
      // Firestore closet membership is authoritative: the AI wardrobe can
      // still contain processed copies of items deleted from the closet.
      final closetItemIds = _closetItemIds;
      final garments = responses[1]
          .where(
            (value) => closetItemIds.contains(
              (value as Map<String, dynamic>)['itemId'],
            ),
          )
          .map(
            (value) => _TryOnChoice.fromGarment(value as Map<String, dynamic>),
          )
          .where(
            (item) =>
                item.category == 'Tops' ||
                item.category == 'Pants' ||
                item.category == 'Skirts' ||
                item.category == 'Shoes' ||
                item.category == 'Accessories',
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _twins = twins;
        _tops = garments.where((item) => item.category == 'Tops').toList();
        _bottoms = garments
            .where(
              (item) => item.category == 'Pants' || item.category == 'Skirts',
            )
            .toList();
        _shoes = garments.where((item) => item.category == 'Shoes').toList();
        _accessories = garments
            .where((item) => item.category == 'Accessories')
            .toList();
        _selectedTwinId = newOutfit || twins.isEmpty ? null : twins.first.id;
        _selectedTopId = newOutfit || _tops.isEmpty ? null : _tops.first.id;
        _selectedBottomId = newOutfit || _bottoms.isEmpty
            ? null
            : _bottoms.first.id;
        // Shoe generation uses paid hosted credits, so never select it
        // automatically when the screen opens or refreshes.
        _selectedShoesId = null;
        _selectedAccessoryIds.clear();
        _error = assetSyncWarning;
        _loading = false;
      });
    } on AiServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your digital twins and wardrobe.';
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    final twinId = _selectedTwinId;
    final garmentIds = [
      ?_selectedTopId,
      ?_selectedBottomId,
      ?_selectedShoesId,
      ..._selectedAccessoryIds,
    ];
    if (twinId == null || garmentIds.isEmpty || _generating) return;

    _generationStopwatch
      ..reset()
      ..start();
    setState(() {
      _generating = true;
      _error = null;
      _resultImage = null;
    });
    // The generate button sits below the pickers; bring the animated
    // loading indicator into view.
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    }
    try {
      final response = await _aiService.tryOn(
        twinId: twinId,
        garmentItemIds: garmentIds,
      );
      final result = base64Decode(response['resultImageB64'] as String);
      if (!mounted) return;
      setState(() => _resultImage = result);
    } on AiServiceException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'The try-on result could not be displayed.');
    } finally {
      _generationStopwatch.stop();
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _openTwinSetup() async {
    await Get.to(() => const EditTwinScreen());
    if (mounted) await _loadChoices();
  }

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
        title: const Text(
          'Virtual Try-On',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _generating || _loading
                ? null
                : () => _loadChoices(newOutfit: true),
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Obx(
                () => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (_closet.syncStatus.value.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(_closet.syncStatus.value),
                    ],
                  ],
                ),
              ),
            )
          : ListView(
              key: ValueKey(_refreshCount),
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _resultCard(),
                const SizedBox(height: 24),
                _sectionTitle('1. Choose your digital twin'),
                const SizedBox(height: 10),
                if (_twins.isEmpty)
                  _emptyCard(
                    'Create a digital twin from your profile before trying on clothes.',
                    actionLabel: 'Create digital twin',
                    onAction: _openTwinSetup,
                  )
                else
                  _choiceStrip(
                    _twins,
                    _selectedTwinId,
                    (id) => setState(() => _selectedTwinId = id),
                  ),
                const SizedBox(height: 24),
                _sectionTitle('2. Choose a Top'),
                const SizedBox(height: 10),
                if (_tops.isEmpty)
                  _emptyCard(
                    'No uploaded Tops are available. You can still generate with Pants or a Skirt only.',
                    actionLabel: 'Back to closet',
                    onAction: Get.back,
                  )
                else
                  _garmentChoiceStrip(
                    _tops,
                    _selectedTopId,
                    noneLabel: 'No top',
                    onSelected: (id) => setState(() => _selectedTopId = id),
                  ),
                const SizedBox(height: 24),
                _sectionTitle('3. Choose Pants or a Skirt'),
                const SizedBox(height: 10),
                if (_bottoms.isEmpty)
                  _emptyCard(
                    'No uploaded Pants or Skirts are available. You can still generate with a Top only.',
                    actionLabel: 'Back to closet',
                    onAction: Get.back,
                  )
                else
                  _garmentChoiceStrip(
                    _bottoms,
                    _selectedBottomId,
                    noneLabel: 'No bottoms',
                    onSelected: (id) => setState(() => _selectedBottomId = id),
                  ),
                const SizedBox(height: 24),
                _sectionTitle('4. Choose Shoes'),
                const SizedBox(height: 10),
                if (_shoes.isEmpty)
                  _emptyCard(
                    'No uploaded Shoes are available. You can still generate without shoes.',
                    actionLabel: 'Back to closet',
                    onAction: Get.back,
                  )
                else
                  _garmentChoiceStrip(
                    _shoes,
                    _selectedShoesId,
                    noneLabel: 'No shoes',
                    onSelected: (id) => setState(() => _selectedShoesId = id),
                  ),
                const SizedBox(height: 24),
                _sectionTitle('5. Choose Accessories'),
                const SizedBox(height: 10),
                if (_accessories.isEmpty)
                  _emptyCard(
                    'Add a clear accessory photo to the Accessories category in your closet. Hats, bags, glasses, and jewelry can be tried on.',
                    actionLabel: 'Back to closet',
                    onAction: Get.back,
                  )
                else
                  _garmentChoiceStrip(
                    _accessories,
                    null,
                    selectedIds: _selectedAccessoryIds,
                    noneLabel: 'No accessories',
                    onSelected: _toggleAccessory,
                  ),
                const SizedBox(height: 8),
                Text(
                  'Select up to $_maxAccessories accessories. Tap a selected item to remove it. '
                  '${_selectedAccessoryIds.length} selected · ${_selectedAccessoryIds.length * 2} accessory credits at Balanced 1K.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (_selectedAccessoryIds.isNotEmpty)
                  const Text(
                    'Choose different accessory types, such as a hat, bag and necklace. Items worn in the same place may replace each other.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade800),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        _selectedTwinId == null ||
                            (_selectedTopId == null &&
                                _selectedBottomId == null &&
                                _selectedShoesId == null &&
                                _selectedAccessoryIds.isEmpty) ||
                            _generating
                        ? null
                        : _generate,
                    icon: _generating
                        ? null
                        : const Icon(Icons.checkroom_outlined),
                    label: Text(
                      _generating
                          ? 'Creating your try-on…'
                          : 'Generate Virtual Try-On',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tops, Pants, and Skirts run locally. Shoes and accessories use API credits. Save your favorite results in My Outfits.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _resultCard() {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _generating
            ? Center(child: GenerationProgress(stopwatch: _generationStopwatch))
            : _resultImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_resultImage!, fit: BoxFit.contain),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FilledButton.icon(
                      onPressed: _saveResult,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      label: const Text('Save Outfit'),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checkroom, size: 72, color: Colors.grey.shade500),
                  const SizedBox(height: 12),
                  const Text(
                    'Your result will appear here',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _saveResult() async {
    final image = _resultImage;
    if (image == null) return;
    try {
      await LikedOutfitsService.like(
        imageBytes: image,
        source: OutfitSource.tryOn,
        title: 'Virtual Try-On',
      );
      Get.snackbar('Outfit saved', 'You can find it in My Outfits.');
    } catch (error) {
      Get.snackbar('Could not save outfit', error.toString());
    }
  }

  Widget _choiceStrip(
    List<_TryOnChoice> choices,
    String? selectedId,
    ValueChanged<String> onSelected,
  ) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: choices.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final choice = choices[index];
          final selected = choice.id == selectedId;
          return Semantics(
            button: true,
            selected: selected,
            label: choice.label,
            child: InkWell(
              onTap: () => onSelected(choice.id),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 120,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? Colors.black : Colors.grey.shade300,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: ColoredBox(
                          color: Colors.grey.shade100,
                          child: Image.memory(
                            choice.image,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      choice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _toggleAccessory(String? id) {
    if (_generating) return;
    if (id != null &&
        !_selectedAccessoryIds.contains(id) &&
        _selectedAccessoryIds.length >= _maxAccessories) {
      Get.snackbar(
        'Accessory limit',
        'Choose up to $_maxAccessories accessories per outfit.',
      );
      return;
    }
    setState(() {
      if (id == null) {
        _selectedAccessoryIds.clear();
      } else if (!_selectedAccessoryIds.remove(id)) {
        _selectedAccessoryIds.add(id);
      }
    });
  }

  Widget _garmentChoiceStrip(
    List<_TryOnChoice> choices,
    String? selectedId, {
    Set<String>? selectedIds,
    required String noneLabel,
    required ValueChanged<String?> onSelected,
  }) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: choices.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            final selected = selectedIds?.isEmpty ?? (selectedId == null);
            return Semantics(
              button: true,
              selected: selected,
              label: noneLabel,
              child: InkWell(
                onTap: _generating ? null : () => onSelected(null),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? Colors.black : Colors.grey.shade300,
                      width: selected ? 3 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block, size: 42, color: Colors.black45),
                      const SizedBox(height: 10),
                      Text(
                        noneLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final choice = choices[index - 1];
          final selected =
              selectedIds?.contains(choice.id) ?? (choice.id == selectedId);
          return Semantics(
            button: true,
            selected: selected,
            label: choice.label,
            child: InkWell(
              onTap: _generating
                  ? null
                  : () => onSelected(
                      selectedIds != null
                          ? choice.id
                          : selected
                          ? null
                          : choice.id,
                    ),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 120,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? Colors.black : Colors.grey.shade300,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: ColoredBox(
                          color: Colors.grey.shade100,
                          child: Image.memory(
                            choice.image,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      choice.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
  );

  Widget _emptyCard(
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(foregroundColor: Colors.black),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}

class _TryOnChoice {
  const _TryOnChoice({
    required this.id,
    required this.image,
    required this.label,
    this.category,
  });

  factory _TryOnChoice.fromTwin(Map<String, dynamic> json) {
    return _TryOnChoice(
      id: json['twinId'] as String,
      image: base64Decode(json['personImageB64'] as String),
      label: 'Digital Twin',
    );
  }

  factory _TryOnChoice.fromGarment(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>;
    final category = metadata['category'] as String;
    return _TryOnChoice(
      id: json['itemId'] as String,
      image: base64Decode(json['itemImageB64'] as String),
      label: category,
      category: category,
    );
  }

  final String id;
  final Uint8List image;
  final String label;
  final String? category;
}
