import 'package:flutter/material.dart';

import '../config/generation_config.dart';

Future<bool> confirmMaxQualityGeneration(
  BuildContext context, {
  required int itemCount,
  bool inspiration = false,
}) async {
  final credits = maxQualityCreditCost(itemCount);
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text('Generate for $credits credits?'),
          content: Text(
            inspiration
                ? 'Try-On Max · $maxQualityLabel\n\n'
                      'One outfit-reference generation costs $credits API credits. '
                      'Your twin and inspiration photo will be sent to FASHN. '
                      'Stay on this page until it finishes. Results may vary, including hijab coverage.'
                : 'Try-On Max · $maxQualityLabel\n\n'
                      '$itemCount selected item(s) × $maxQualityCreditsPerImage credits = $credits API credits. '
                      'Each item is applied in a separate generation. Your twin and selected '
                      'clothing images will be sent to FASHN. Earlier steps may still use '
                      'credits if a later step fails. Stay on this page until it finishes. '
                      'Results may vary, including hijab coverage.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Generate · $credits credits'),
            ),
          ],
        ),
      ) ??
      false;
}
