/// Must match WARDROBE_CATEGORIES / HIJAB_STYLES in
/// apps/ai_service/app/config.py - the server rejects anything else.
/// Also matches home_screen.dart's _categoryOrder: the app's closet UI
/// defines these labels, and the backend was updated to accept them as-is.
const List<String> wardrobeCategories = [
  'Tops',
  'Pants',
  'Shoes',
  'Accessories',
  'Hijab',
];
const List<String> hijabStyles = ['shawl', 'pashmina', 'instant', 'khimar'];
