// Keep in sync with apps/ai_service/app/config.py. The server independently
// checks this quote and rejects mismatches before making a paid request.
enum GenerationMode {
  fast('Fast', 1, 'Prioritizes speed. Fine details may be less accurate.'),
  balanced('Balanced', 2, 'A balance between generation speed and detail.'),
  quality('Quality', 3, 'Prioritizes detail. Takes longer to generate.');

  const GenerationMode(this.label, this.creditsPerImage, this.description);

  final String label;
  final int creditsPerImage;
  final String description;

  String get resolutionLabel => '$label · 1K';
  int creditCost(int itemCount) => itemCount * creditsPerImage;
}
