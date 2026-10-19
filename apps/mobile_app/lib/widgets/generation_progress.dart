import 'dart:async';

import 'package:flutter/material.dart';

/// Simple progress display shared by the outfit generation screens.
class GenerationProgress extends StatefulWidget {
  const GenerationProgress({
    super.key,
    required this.stopwatch,
    this.label = 'Generating outfit…',
  });

  final Stopwatch stopwatch;
  final String label;

  @override
  State<GenerationProgress> createState() => _GenerationProgressState();
}

class _GenerationProgressState extends State<GenerationProgress> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.stopwatch.elapsed;
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Elapsed time $minutes:$seconds',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
