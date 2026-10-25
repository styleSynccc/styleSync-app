import 'dart:async';

import 'package:mobile_app/services/ai_service.dart';

// A valid 1x1 PNG keeps image decoding local and deterministic.
const testImageBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

Map<String, dynamic> twinJson(String id) => {
  'twinId': id,
  'personImageB64': testImageBase64,
};

Map<String, dynamic> garmentJson(String id, String category) => {
  'itemId': id,
  'itemImageB64': testImageBase64,
  'metadata': {'category': category},
};

class FakeAiService extends AiService {
  List<dynamic> twins = [twinJson('twin-1')];
  List<dynamic> wardrobe = [garmentJson('top-1', 'Tops')];
  Object? loadError;
  Object? generationError;
  Completer<List<dynamic>>? pendingTwins;
  Completer<Map<String, dynamic>>? pendingGeneration;
  Map<String, dynamic> result = {'resultImageB64': testImageBase64};
  int twinLoads = 0;
  int wardrobeLoads = 0;
  final generationCalls = <({String twinId, String garmentItemId})>[];

  @override
  Future<List<dynamic>> listTwins() async {
    twinLoads++;
    if (loadError != null) throw loadError!;
    return pendingTwins?.future ?? twins;
  }

  @override
  Future<List<dynamic>> listWardrobe() async {
    wardrobeLoads++;
    return wardrobe;
  }

  @override
  Future<Map<String, dynamic>> tryOn({
    required String twinId,
    required String garmentItemId,
  }) async {
    generationCalls.add((twinId: twinId, garmentItemId: garmentItemId));
    if (generationError != null) throw generationError!;
    return pendingGeneration?.future ?? result;
  }
}
