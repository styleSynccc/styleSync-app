import 'package:flutter/material.dart';

import '../config/generation_config.dart';

Future<bool> confirmGeneration(
  BuildContext context, {
  required int itemCount,
  GenerationMode mode = GenerationMode.quality,
  bool inspiration = false,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Generate outfit?'),
          content: Text(
            inspiration
                ? 'Try-On Max · ${mode.resolutionLabel}\n\n'
                      'Your twin and inspiration photo will be sent to FASHN. '
                      'Stay on this page until it finishes. Results may vary, including hijab coverage.'
                : 'Try-On Max · ${mode.resolutionLabel}\n\n'
                      'Each item is applied in a separate generation. Your twin and selected '
                      'clothing images will be sent to FASHN. Stay on this page until it finishes. '
                      'Results may vary, including hijab coverage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Generate'),
            ),
          ],
        ),
      ) ??
      false;
}
