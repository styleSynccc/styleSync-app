import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/ai_service.dart';
import 'edit_profile_screen.dart';

/// Shows the user's virtual (digital) twin.
class VirtualTwinScreen extends StatefulWidget {
  const VirtualTwinScreen({super.key});
  @override
  State<VirtualTwinScreen> createState() => _VirtualTwinScreenState();
}

class _VirtualTwinScreenState extends State<VirtualTwinScreen> {
  Uint8List? _twinBytes;
  String _photoUrl = '';
  bool _loading = true;
  int _quarterTurns = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        _photoUrl = doc.data()?['digitalTwinPhotoUrl']?.toString() ?? '';
      }
      final twins = await AiService().listTwins();
      if (twins.isNotEmpty) {
        final first = twins.first as Map<String, dynamic>;
        _twinBytes = base64Decode(first['personImageB64'] as String);
      }
    } catch (_) {
      // Fall back to the stored photo URL below.
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasTwin = _twinBytes != null || _photoUrl.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Virtual Twin'),
        backgroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: !hasTwin
                          ? const Center(
                              child: Text(
                                'No virtual twin yet.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : InteractiveViewer(
                              minScale: 1,
                              maxScale: 4,
                              child: Center(
                                child: RotatedBox(
                                  quarterTurns: _quarterTurns,
                                  child: _twinBytes != null
                                      ? Image.memory(
                                          _twinBytes!,
                                          fit: BoxFit.contain,
                                        )
                                      : Image.network(
                                          _photoUrl,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.broken_image),
                                        ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pinch to zoom and drag to move your twin.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  if (hasTwin)
                    OutlinedButton.icon(
                      onPressed: () => setState(
                        () => _quarterTurns = (_quarterTurns + 1) % 4,
                      ),
                      icon: const Icon(Icons.rotate_right),
                      label: const Text('Rotate view'),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: Text(hasTwin ? 'Edit Twin' : 'Create Twin'),
                    onPressed: () async {
                      await Get.to(() => const EditTwinScreen());
                      if (mounted) _load();
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
