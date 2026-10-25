import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';
import '../services/liked_outfits_service.dart';
import '../widgets/generation_progress.dart';
import '../widgets/generation_confirmation.dart';
import '../config/generation_config.dart';
import 'edit_profile_screen.dart';

class InspoMirrorScreen extends StatefulWidget {
  const InspoMirrorScreen({super.key, this.aiService});
  final AiService? aiService;
  @override
  State<InspoMirrorScreen> createState() => _InspoMirrorScreenState();
}

class _InspoMirrorScreenState extends State<InspoMirrorScreen> {
  late final AiService _api = widget.aiService ?? AiService();
  final _title = TextEditingController();
  final _scroll = ScrollController();
  final Stopwatch _generationStopwatch = Stopwatch();
  List<({String id, Uint8List image})> _twins = [];
  String? _twinId;
  String? _resultUid;
  Uint8List? _reference, _result;
  String _filename = 'inspiration.jpg';
  String? _error;
  bool _loading = true,
      _picking = false,
      _generating = false,
      _saving = false,
      _saved = false;
  bool get _busy => _generating || _saving || _picking;
  bool _confirmingGeneration = false;

  @override
  void initState() {
    super.initState();
    _loadTwins();
  }

  @override
  void dispose() {
    _generationStopwatch.stop();
    _title.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadTwins() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await _api.listTwins();
      final twins = values
          .map(
            (value) => (
              id: value['twinId'] as String,
              image: base64Decode(value['personImageB64'] as String),
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _twins = twins;
        _twinId = twins.isEmpty ? null : twins.first.id;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AiServiceException
              ? error.message
              : 'Could not load your twins. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_busy) return;
    setState(() => _picking = true);
    try {
      final photo = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (photo == null) return;
      if (await photo.length() > 25 * 1024 * 1024) {
        throw const FormatException('Choose a photo smaller than 25 MB.');
      }
      final bytes = await photo.readAsBytes();
      if (mounted) {
        setState(() {
          _reference = bytes;
          _filename = photo.name;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : 'Could not open that photo. Please choose another.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _generate() async {
    final twinId = _twinId;
    final reference = _reference;
    if (_busy || _confirmingGeneration || twinId == null || reference == null) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'Please sign in again before generating.');
      return;
    }
    _confirmingGeneration = true;
    bool confirmed;
    try {
      confirmed = await confirmMaxQualityGeneration(
        context,
        itemCount: 1,
        inspiration: true,
      );
    } finally {
      _confirmingGeneration = false;
    }
    if (!confirmed || !mounted) return;
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      setState(
        () => _error = 'Your sign-in changed. Please reopen Inspo Mirror.',
      );
      return;
    }
    _generationStopwatch
      ..reset()
      ..start();
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final response = await _api.createInspoMirror(
        twinId: twinId,
        bytes: reference,
        filename: _filename,
      );
      final bytes = base64Decode(response['resultImageB64'] as String);
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        setState(
          () => _error = 'Your sign-in changed. Please reopen Inspo Mirror.',
        );
        return;
      }
      setState(() {
        _result = bytes;
        _resultUid = uid;
        _saved = false;
        _title.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AiServiceException
              ? error.message
              : 'Could not generate this outfit. Please try another photo.',
        );
      }
    } finally {
      _generationStopwatch.stop();
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _result == null || _saved) return;
    if (_resultUid == null ||
        _resultUid != FirebaseAuth.instance.currentUser?.uid) {
      setState(
        () => _error = 'Your sign-in changed. Please reopen Inspo Mirror.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await LikedOutfitsService.like(
        imageBytes: _result!,
        source: OutfitSource.inspoMirror,
        ownerUid: _resultUid!,
        title: _title.text.trim().isEmpty
            ? 'Inspo Mirror Outfit'
            : _title.text.trim(),
      );
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save your outfit. Your result is still here; try saving again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_generating && !_saving,
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AI Inspo Mirror'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh twins',
            onPressed: _busy || _loading ? null : _loadTwins,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'An outfit you love. On your twin.',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload a clear photo of one fully clothed person. Keep the whole outfit in frame, including shoes if you want to transfer them.',
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 22),
            InkWell(
              onTap: _busy ? null : _pickPhoto,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 280,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.pink.shade200),
                ),
                child: _reference == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 44,
                            color: Colors.pink,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Upload inspiration photo',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 6),
                          Text('Choose from your gallery'),
                        ],
                      )
                    : Image.memory(
                        _reference!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text(
                            'Cannot preview this photo. Choose another.',
                          ),
                        ),
                      ),
              ),
            ),
            if (_reference != null)
              TextButton.icon(
                onPressed: _busy ? null : _pickPhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Change inspiration photo'),
              ),
            const SizedBox(height: 22),
            const Text(
              'Choose your twin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_twins.isEmpty) ...[
              const Text(
                'Create a digital twin from a full-body photo to try this outfit on yourself.',
              ),
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        await Get.to(() => const EditTwinScreen());
                        if (mounted) _loadTwins();
                      },
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Create or edit twin'),
              ),
            ] else
              SizedBox(
                height: 184,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _twins.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, index) {
                    final twin = _twins[index];
                    final selected = _twinId == twin.id;
                    return Semantics(
                      selected: selected,
                      button: true,
                      label: 'Twin ${index + 1}',
                      child: InkWell(
                        onTap: _busy
                            ? null
                            : () => setState(() => _twinId = twin.id),
                        child: Container(
                          width: 125,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? Colors.black : Colors.black12,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: Image.memory(
                                  twin.image,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                selected
                                    ? 'Selected twin'
                                    : 'Twin ${index + 1}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              '$maxQualityLabel · $maxQualityCreditsPerImage API credits per generation',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your twin and inspiration photo are sent to FASHN to generate the outfit. Details and fit may vary.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            if (_generating)
              GenerationProgress(stopwatch: _generationStopwatch),
            ElevatedButton.icon(
              onPressed:
                  _busy || _loading || _twinId == null || _reference == null
                  ? null
                  : _generate,
              icon: _generating ? null : const Icon(Icons.checkroom_outlined),
              label: Text(
                _generating ? 'Creating your outfit…' : 'Generate on my twin',
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_result != null) ...[
              const SizedBox(height: 28),
              const Text(
                'Your inspired look',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (_generating) const Text('Previous result'),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.memory(_result!, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                enabled: !_busy && !_saved,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Outfit name (optional)',
                ),
              ),
              ElevatedButton.icon(
                onPressed: _busy || _saved ? null : _save,
                icon: Icon(_saved ? Icons.check : Icons.bookmark_border),
                label: Text(
                  _saving
                      ? 'Saving…'
                      : _saved
                      ? 'Saved to My Outfits'
                      : 'Save Outfit',
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => Get.toNamed('/my-outfits'),
                child: const Text('View My Outfits'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
