import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/closet_controller.dart';
import '../services/notification_service.dart';

class OutfitPlannerScreen extends StatefulWidget {
  const OutfitPlannerScreen({super.key});
  @override
  State<OutfitPlannerScreen> createState() => _OutfitPlannerScreenState();
}

class _OutfitPlannerScreenState extends State<OutfitPlannerScreen> {
  late final ClosetController closet = Get.isRegistered<ClosetController>()
      ? Get.find<ClosetController>()
      : Get.put(ClosetController());
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? get plans {
    final user = auth.currentUser;
    return user == null
        ? null
        : db.collection('users').doc(user.uid).collection('outfitPlans');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Outfit Planner'),
      backgroundColor: Colors.white,
    ),
    backgroundColor: Colors.white,
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.green),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Select a date to plan an outfit',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.add, color: Colors.green),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Upcoming Outfits',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: plans == null
                ? const Center(child: Text('Please sign in first.'))
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: plans!.snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return const Center(
                          child: Text('Could not load outfit plans.'),
                        );
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      final today = DateUtils.dateOnly(DateTime.now());
                      final docs =
                          snapshot.data!.docs.where((d) {
                            final value = d.data()['date'];
                            return value is Timestamp &&
                                !value.toDate().isBefore(today);
                          }).toList()..sort(
                            (a, b) => (a.data()['date'] as Timestamp).compareTo(
                              b.data()['date'] as Timestamp,
                            ),
                          );
                      if (docs.isEmpty)
                        return const Center(
                          child: Text(
                            'No outfits planned yet.\nTap above to create one!',
                            textAlign: TextAlign.center,
                          ),
                        );
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _planCard(docs[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _planCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final date = (doc.data()['date'] as Timestamp).toDate();
    final reminderAt = (doc.data()['reminderAt'] as Timestamp?)?.toDate();
    final items = (doc.data()['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 75,
              child: Text(
                '${date.day}/${date.month}\n${date.year}${reminderAt == null ? '' : '\n${_formatTime(reminderAt)}'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (_, i) =>
                      SizedBox(width: 60, child: _image(items[i])),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _delete(doc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(Map<String, dynamic> data) {
    final asset = data['assetPath'] as String?;
    return asset != null && asset.isNotEmpty
        ? Image.asset(asset, fit: BoxFit.contain)
        : Image.network(
            data['imageUrl'] ?? '',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
          );
  }

  Future<void> _pickDate() async {
    if (auth.currentUser == null) {
      Get.snackbar('Sign in required', 'Please sign in first.');
      return;
    }
    if (closet.clothes.isEmpty) await closet.fetchClothes();
    if (closet.clothes.isEmpty) {
      Get.snackbar('Closet is empty', 'Add clothes before planning.');
      return;
    }
    if (!mounted) return;
    final now = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;

    final currentTime = TimeOfDay.now();
    final defaultTime = date.isAtSameMomentAs(now)
        ? TimeOfDay(hour: (currentTime.hour + 1) % 24, minute: 0)
        : const TimeOfDay(hour: 8, minute: 0);
    final time = await showTimePicker(
      context: context,
      initialTime: defaultTime,
      helpText: 'Choose reminder time',
    );
    if (time == null) return;

    final reminderAt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!reminderAt.isAfter(DateTime.now())) {
      Get.snackbar(
        'Choose a future time',
        'The reminder time must be later than now.',
      );
      return;
    }
    _chooseItems(reminderAt);
  }

  void _chooseItems(DateTime reminderAt) {
    final selected = <String>{};
    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, update) => Container(
          height: Get.height * .75,
          padding: const EdgeInsets.all(20),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose outfit for ${reminderAt.day}/${reminderAt.month}/${reminderAt.year} at ${_formatTime(reminderAt)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: GridView.builder(
                  itemCount: closet.clothes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (_, i) {
                    final item = closet.clothes[i];
                    final chosen = selected.contains(item.id);
                    final dynamic closetItem = item;
                    final String? assetPath = closetItem.assetPath as String?;
                    return InkWell(
                      onTap: () => update(
                        () => chosen
                            ? selected.remove(item.id)
                            : selected.add(item.id),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          border: Border.all(
                            color: chosen ? Colors.green : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: assetPath != null && assetPath.isNotEmpty
                                    ? Image.asset(
                                        assetPath,
                                        fit: BoxFit.contain,
                                      )
                                    : Image.network(
                                        item.imageUrl,
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ),
                            if (chosen)
                              const Align(
                                alignment: Alignment.topRight,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => _save(reminderAt, selected),
                child: Text('Save Outfit (${selected.length})'),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _save(DateTime reminderAt, Set<String> ids) async {
    final values = closet.clothes.where((x) => ids.contains(x.id)).map((x) {
      final dynamic closetItem = x;
      final String? assetPath = closetItem.assetPath as String?;
      return {
        'id': x.id,
        'category': x.category,
        'imageUrl': x.imageUrl,
        if (assetPath != null) 'assetPath': assetPath,
      };
    }).toList();
    final date = DateUtils.dateOnly(reminderAt);
    final id =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final notificationId = date.year * 10000 + date.month * 100 + date.day;
    try {
      await plans!.doc(id).set({
        'date': Timestamp.fromDate(date),
        'reminderAt': Timestamp.fromDate(reminderAt),
        'notificationId': notificationId,
        'items': values,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      var reminderScheduled = false;
      try {
        reminderScheduled = await NotificationService.instance
            .scheduleOutfitReminder(
              id: notificationId,
              reminderAt: reminderAt,
              itemCount: values.length,
            );
      } catch (_) {
        // The outfit is still safely stored even if the OS rejects a reminder.
      }

      Get.back();
      Get.snackbar(
        'Outfit planned',
        reminderScheduled
            ? 'Reminder set for ${_formatTime(reminderAt)}.'
            : 'Outfit saved, but notification permission was not granted.',
      );
    } catch (e) {
      Get.snackbar('Error', 'Could not save outfit: $e');
    }
  }

  void _delete(QueryDocumentSnapshot<Map<String, dynamic>> doc) => Get.dialog(
    AlertDialog(
      title: const Text('Delete planned outfit?'),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            Get.back();
            await doc.reference.delete();
            final notificationId = doc.data()['notificationId'];
            if (notificationId is int) {
              await NotificationService.instance.cancel(notificationId);
            }
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  String _formatTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
