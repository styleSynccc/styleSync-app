import 'package:flutter/material.dart';

/// The style preferences a user can pick from (multi-select).
const List<String> stylePreferenceOptions = [
  'Casual',
  'Formal',
  'Modest',
  'Streetwear',
  'Sports',
];

/// Multi-select chip group for style preferences.
class StylePreferenceSelector extends StatelessWidget {
  const StylePreferenceSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Style Preferences',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pick as many as you like.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: stylePreferenceOptions.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: Colors.black,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              onSelected: (value) {
                final next = List<String>.from(selected);
                value ? next.add(option) : next.remove(option);
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
