import 'package:flutter/material.dart';

import '../config/generation_config.dart';

class GenerationModeSelector extends StatelessWidget {
  const GenerationModeSelector({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final GenerationMode mode;
  final ValueChanged<GenerationMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Generation mode',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: GenerationMode.values.map((option) {
            return ChoiceChip(
              label: Text(option.label),
              selected: option == mode,
              selectedColor: Colors.black,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: option == mode ? Colors.white : Colors.black,
              ),
              onSelected: onChanged == null ? null : (_) => onChanged!(option),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          '${mode.description} All modes use 1K resolution.',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
