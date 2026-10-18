import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/ai_service.dart';
import '../services/closet_controller.dart';
import '../services/liked_outfits_service.dart';
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
  String? _selectedTwinId;
  String? _selectedTopId;
  String? _selectedBottomId;
  String? _selectedShoesId;
  Uint8List? _resultImage;
  String? _error;
  bool _loading = true;
  bool _generating = false;
  int _refreshCount = 0;
  final ScrollController _scrollController = ScrollController();
  // Snapshot of the selection being generated, so the loading animation
  // doesn't change if the user taps other items mid-generation.
  Uint8List? _pendingTwinImage;
  List<_TryOnChoice> _pendingGarments = const [];

  @override
  void initState() {
    super.initState();
    _closetWorker = ever(_closet.clothes, (_) => _removeDeletedChoices());
    _loadChoices();
  }

  @override
  void dispose() {
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
      if (!ids.contains(_selectedTopId)) _selectedTopId = null;
      if (!ids.contains(_selectedBottomId)) _selectedBottomId = null;
      if (!ids.contains(_selectedShoesId)) _selectedShoesId = null;
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
        _twins = const [];
        _tops = const [];
        _bottoms = const [];
        _shoes = const [];
      }
    });
    try {
      final assetSyncWarning = await _closet.syncAssetItemsForTryOn();
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
                item.category == 'Shoes',
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
        _selectedTwinId = newOutfit || twins.isEmpty ? null : twins.first.id;
        _selectedTopId = newOutfit || _tops.isEmpty ? null : _tops.first.id;
        _selectedBottomId = newOutfit || _bottoms.isEmpty
            ? null
            : _bottoms.first.id;
        // Shoe generation uses paid hosted credits, so never select it
        // automatically when the screen opens or refreshes.
        _selectedShoesId = null;
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
    final garmentIds = [?_selectedTopId, ?_selectedBottomId, ?_selectedShoesId];
    if (twinId == null || garmentIds.isEmpty || _generating) return;

    setState(() {
      _generating = true;
      _error = null;
      _resultImage = null;
      _pendingTwinImage = _findChoice(_twins, twinId)?.image;
      _pendingGarments = [
        ?_findChoice(_tops, _selectedTopId),
        ?_findChoice(_bottoms, _selectedBottomId),
        ?_findChoice(_shoes, _selectedShoesId),
      ];
    });
    // The generate button sits below the pickers; bring the animated
    // result card into view.
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
      if (mounted) setState(() => _generating = false);
    }
  }

  _TryOnChoice? _findChoice(List<_TryOnChoice> choices, String? id) {
    for (final choice in choices) {
      if (choice.id == id) return choice;
    }
    return null;
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
          ? const Center(child: CircularProgressIndicator())
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
                                _selectedShoesId == null) ||
                            _generating
                        ? null
                        : _generate,
                    icon: _generating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
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
                  'Tops, Pants, and Skirts run with local FASHN VTON. Shoes need FASHN Try-On Max API credits. Save results you want to keep in My Outfits.',
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, ?current],
          ),
          child: _resultImage != null
              ? Stack(
                  key: const ValueKey('result'),
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
              : _generating
              ? _TryOnGeneratingView(
                  key: const ValueKey('generating'),
                  twinImage: _pendingTwinImage,
                  garments: _pendingGarments,
                )
              : Column(
                  key: const ValueKey('placeholder'),
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

  Widget _garmentChoiceStrip(
    List<_TryOnChoice> choices,
    String? selectedId, {
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
            final selected = selectedId == null;
            return Semantics(
              button: true,
              selected: selected,
              label: noneLabel,
              child: InkWell(
                onTap: () => onSelected(null),
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
          final selected = choice.id == selectedId;
          return Semantics(
            button: true,
            selected: selected,
            label: choice.label,
            child: InkWell(
              onTap: () => onSelected(selected ? null : choice.id),
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

/// Animated placeholder shown in the result card while the AI generates a
/// try-on: the blurred twin gets "scanned", the chosen garments float above
/// it, sparkles twinkle, and a status line walks through the steps.
class _TryOnGeneratingView extends StatefulWidget {
  const _TryOnGeneratingView({
    super.key,
    required this.twinImage,
    required this.garments,
  });

  final Uint8List? twinImage;
  final List<_TryOnChoice> garments;

  @override
  State<_TryOnGeneratingView> createState() => _TryOnGeneratingViewState();
}

class _TryOnGeneratingViewState extends State<_TryOnGeneratingView>
    with TickerProviderStateMixin {
  static const _accent = Color(0xFF7C4DFF);
  static const _secondsPerMessage = 4;
  static const _patienceMessages = [
    'Almost there…',
    'Perfecting the details…',
    'Good looks take a moment…',
  ];
  static const _sparkleSpots = [
    Alignment(-0.75, -0.3),
    Alignment(0.72, -0.12),
    Alignment(-0.62, 0.32),
    Alignment(0.8, 0.42),
    Alignment(0.15, -0.55),
    Alignment(-0.1, 0.15),
  ];

  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  late final Timer _ticker;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _scan.dispose();
    _float.dispose();
    super.dispose();
  }

  List<String> get _steps => [
    'Analyzing your digital twin…',
    'Mapping your pose and body shape…',
    for (final garment in widget.garments) _fittingMessage(garment),
    'Matching fabric, folds and lighting…',
    'Adding the finishing touches…',
  ];

  static String _fittingMessage(_TryOnChoice garment) =>
      switch (garment.category) {
        'Tops' => 'Fitting your top…',
        'Pants' => 'Tailoring your pants…',
        'Skirts' => 'Draping your skirt…',
        'Shoes' => 'Lacing up your shoes…',
        _ => 'Fitting your ${garment.label.toLowerCase()}…',
      };

  String get _message {
    final steps = _steps;
    final index = _elapsedSeconds ~/ _secondsPerMessage;
    if (index < steps.length) return steps[index];
    // Generation is running long: cycle reassuring messages instead of
    // restarting the step list.
    return _patienceMessages[(index - steps.length) %
        _patienceMessages.length];
  }

  String get _elapsedLabel {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return minutes == 0
        ? '${seconds}s'
        : '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.twinImage != null)
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Opacity(
              opacity: 0.45,
              child: Image.memory(widget.twinImage!, fit: BoxFit.contain),
            ),
          ),
        _scanLine(),
        _sparkles(),
        if (widget.garments.isNotEmpty)
          Positioned(top: 18, left: 0, right: 0, child: _floatingGarments()),
        Positioned(left: 14, right: 14, bottom: 14, child: _statusCard()),
      ],
    );
  }

  Widget _scanLine() => AnimatedBuilder(
    animation: _scan,
    builder: (context, _) => Align(
      alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_scan.value)),
      child: Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _accent.withValues(alpha: 0),
              _accent.withValues(alpha: 0.18),
              _accent.withValues(alpha: 0),
            ],
          ),
        ),
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.transparent, _accent, Colors.transparent],
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _sparkles() => AnimatedBuilder(
    animation: _float,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < _sparkleSpots.length; i++)
          Align(
            alignment: _sparkleSpots[i],
            child: _sparkle(
              phase: (_float.value + i / _sparkleSpots.length) % 1,
              size: 14.0 + (i % 3) * 6,
            ),
          ),
      ],
    ),
  );

  Widget _sparkle({required double phase, required double size}) {
    final twinkle = math.sin(phase * math.pi);
    return Opacity(
      opacity: twinkle,
      child: Transform.rotate(
        angle: phase * math.pi / 2,
        child: Transform.scale(
          scale: 0.5 + 0.6 * twinkle,
          child: Icon(Icons.auto_awesome, size: size, color: _accent),
        ),
      ),
    );
  }

  Widget _floatingGarments() => AnimatedBuilder(
    animation: _float,
    builder: (context, _) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.garments.length; i++)
          Transform.translate(
            offset: Offset(
              0,
              math.sin(
                    (_float.value + i / widget.garments.length) * 2 * math.pi,
                  ) *
                  6,
            ),
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.memory(
                  widget.garments[i].image,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _statusCard() => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: Text(
                  _message,
                  key: ValueKey(_message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _elapsedLabel,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 4,
            color: _accent,
            backgroundColor: _accent.withValues(alpha: 0.12),
          ),
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
