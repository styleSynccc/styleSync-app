import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/ai_service.dart';
import 'edit_profile_screen.dart';

class VirtualTryOnScreen extends StatefulWidget {
  const VirtualTryOnScreen({super.key, this.aiService});

  final AiService? aiService;

  @override
  State<VirtualTryOnScreen> createState() => _VirtualTryOnScreenState();
}

class _VirtualTryOnScreenState extends State<VirtualTryOnScreen> {
  late final AiService _aiService = widget.aiService ?? AiService();
  List<_TryOnChoice> _twins = const [];
  List<_TryOnChoice> _garments = const [];
  String? _selectedTwinId;
  String? _selectedGarmentId;
  Uint8List? _resultImage;
  String? _error;
  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadChoices();
  }

  Future<void> _loadChoices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final responses = await Future.wait<List<dynamic>>([
        _aiService.listTwins(),
        _aiService.listWardrobe(),
      ]);
      final twins = responses[0]
          .map((value) => _TryOnChoice.fromTwin(value as Map<String, dynamic>))
          .toList();
      final garments = responses[1]
          .map(
            (value) => _TryOnChoice.fromGarment(value as Map<String, dynamic>),
          )
          .where((item) => item.category == 'Tops' || item.category == 'Pants')
          .toList();
      if (!mounted) return;
      setState(() {
        _twins = twins;
        _garments = garments;
        _selectedTwinId = twins.isEmpty ? null : twins.first.id;
        _selectedGarmentId = garments.isEmpty ? null : garments.first.id;
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
    final garmentId = _selectedGarmentId;
    if (twinId == null || garmentId == null || _generating) return;

    setState(() {
      _generating = true;
      _error = null;
      _resultImage = null;
    });
    try {
      final response = await _aiService.tryOn(
        twinId: twinId,
        garmentItemId: garmentId,
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

  Future<void> _openTwinSetup() async {
    await Get.to(() => const EditProfileScreen());
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
            onPressed: _generating ? null : _loadChoices,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChoices,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                  _sectionTitle('2. Choose a Top or Pants'),
                  const SizedBox(height: 10),
                  if (_garments.isEmpty)
                    _emptyCard(
                      'Add a Top or Pants photo to your closet first. Bundled sample items are not AI-ready.',
                      actionLabel: 'Back to closet',
                      onAction: Get.back,
                    )
                  else
                    _choiceStrip(
                      _garments,
                      _selectedGarmentId,
                      (id) => setState(() => _selectedGarmentId = id),
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
                              _selectedGarmentId == null ||
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
                    'The first result downloads and loads the model, so it can take several minutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
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
        child: _resultImage != null
            ? Image.memory(_resultImage!, fit: BoxFit.contain)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _generating ? Icons.hourglass_top : Icons.checkroom,
                    size: 72,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _generating
                        ? 'CatVTON is creating your outfit'
                        : 'Your result will appear here',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
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
