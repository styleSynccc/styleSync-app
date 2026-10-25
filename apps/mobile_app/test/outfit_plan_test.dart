import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/outfit_plan.dart';

void main() {
  final now = DateTime(2026, 10, 25, 22, 12);

  test('a past reminder today is no longer upcoming', () {
    final data = {
      'date': Timestamp.fromDate(DateTime(2026, 10, 25)),
      'reminderAt': Timestamp.fromDate(DateTime(2026, 10, 25, 22, 11)),
    };
    expect(isUpcomingOutfitPlan(data, now), isFalse);
  });

  test('a plan expires at its selected time, not at midnight', () {
    final data = {'reminderAt': Timestamp.fromDate(now)};
    expect(
      isUpcomingOutfitPlan(data, now.subtract(const Duration(seconds: 1))),
      isTrue,
    );
    expect(isUpcomingOutfitPlan(data, now), isFalse);
    expect(
      isUpcomingOutfitPlan(data, now.add(const Duration(seconds: 1))),
      isFalse,
    );
  });

  test('a future reminder is upcoming', () {
    expect(
      isUpcomingOutfitPlan({
        'reminderAt': Timestamp.fromDate(DateTime(2026, 10, 26, 8)),
      }, now),
      isTrue,
    );
  });

  test('legacy date-only plan expires at the next local midnight', () {
    final data = {'date': Timestamp.fromDate(DateTime(2026, 10, 25))};
    expect(isUpcomingOutfitPlan(data, now), isTrue);
    expect(isUpcomingOutfitPlan(data, DateTime(2026, 10, 26)), isFalse);
    expect(outfitPlanExpiresAt(data), DateTime(2026, 10, 26));
  });

  test('a date-only plan from yesterday is not upcoming', () {
    expect(
      isUpcomingOutfitPlan({
        'date': Timestamp.fromDate(DateTime(2026, 10, 24)),
      }, now),
      isFalse,
    );
  });

  test('missing or invalid dates do not produce upcoming outfits', () {
    expect(isUpcomingOutfitPlan({}, now), isFalse);
    expect(isUpcomingOutfitPlan({'date': 'invalid'}, now), isFalse);
  });

  test(
    'existing planner records appear in gallery without createdAt or imageUrl',
    () {
      final savedAt = Timestamp.fromDate(DateTime(2026, 10, 24, 18));
      final items = [
        {
          'imageUrl': 'https://example.com/closet-shirt.jpg',
          'category': 'Tops',
        },
        {
          'assetPath': 'assets/images/pants/jeans_blue.png',
          'category': 'Pants',
        },
      ];
      final original = <String, dynamic>{
        'date': Timestamp.fromDate(DateTime(2026, 10, 25)),
        'updatedAt': savedAt,
        'items': items,
        'notificationId': 20261025,
      };
      final gallery = plannerGalleryData(original);
      expect(gallery['source'], 'planner');
      expect(gallery['title'], 'Outfit for 25/10/2026');
      expect(gallery['createdAt'], savedAt);
      expect(gallery['items'], items);
      expect(gallery['notificationId'], 20261025);
      expect(original.containsKey('source'), isFalse);
    },
  );

  test('gallery preserves custom titles and creation dates', () {
    final createdAt = Timestamp.fromDate(now);
    final gallery = plannerGalleryData({
      'title': 'Office outfit',
      'createdAt': createdAt,
      'updatedAt': Timestamp.fromDate(now.add(const Duration(days: 1))),
    });
    expect(gallery['title'], 'Office outfit');
    expect(gallery['createdAt'], createdAt);
    expect(outfitSourceLabel(gallery['source']), 'Outfit Planner');
    expect(outfitSourceLabel('vton'), 'VTON');
    expect(outfitSourceLabel('inspo'), 'AI Inspo Mirror');
  });
}
