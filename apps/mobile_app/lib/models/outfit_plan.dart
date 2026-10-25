import 'package:cloud_firestore/cloud_firestore.dart';

/// Plans with a reminder expire at that instant. Older date-only plans remain
/// upcoming through their local calendar day, not forever after that day.
DateTime? outfitPlanExpiresAt(Map<String, dynamic> data) {
  final reminder = data['reminderAt'];
  if (reminder is Timestamp) return reminder.toDate();
  final date = data['date'];
  if (date is! Timestamp) return null;
  final local = date.toDate();
  return DateTime(local.year, local.month, local.day + 1);
}

bool isUpcomingOutfitPlan(Map<String, dynamic> data, DateTime now) =>
    outfitPlanExpiresAt(data)?.isAfter(now) ?? false;

/// Reuse existing plans directly in the gallery; no image upload, migration,
/// duplicated Firestore document, or deletion of shared closet images needed.
Map<String, dynamic> plannerGalleryData(Map<String, dynamic> data) {
  final date = data['date'];
  final plannedDate = date is Timestamp ? date.toDate() : null;
  final title = data['title']?.toString().trim();
  return {
    ...data,
    'source': 'planner',
    'title': title != null && title.isNotEmpty
        ? title
        : plannedDate == null
        ? 'Planned Outfit'
        : 'Outfit for ${plannedDate.day}/${plannedDate.month}/${plannedDate.year}',
    'createdAt': data['createdAt'] ?? data['updatedAt'] ?? data['date'],
  };
}

String outfitSourceLabel(dynamic source) => switch (source) {
  'planner' => 'Outfit Planner',
  'inspo' => 'AI Inspo Mirror',
  _ => 'VTON',
};
