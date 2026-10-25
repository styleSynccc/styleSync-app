import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/closet_controller.dart';
import '../services/notification_service.dart';
import '../models/outfit_plan.dart';

class OutfitPlannerScreen extends StatefulWidget {
  const OutfitPlannerScreen({super.key});
  @override
  State<OutfitPlannerScreen> createState() => _OutfitPlannerScreenState();
}

class _OutfitPlannerScreenState extends State<OutfitPlannerScreen>
    with WidgetsBindingObserver {
  late final ClosetController closet = Get.isRegistered<ClosetController>()
      ? Get.find<ClosetController>()
      : Get.put(ClosetController());
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  bool _savingPlan = false;
  late final Future<void> _remindersRestored;
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _plansStream;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _plansStream = plans?.snapshots();
    _remindersRestored = _restoreReminders();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _refreshWhenNextPlanExpires(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
    DateTime now,
  ) {
    _expiryTimer?.cancel();
    DateTime? next;
    for (final document in documents) {
      final expires = outfitPlanExpiresAt(document.data());
      if (expires != null &&
          expires.isAfter(now) &&
          (next == null || expires.isBefore(next))) {
        next = expires;
      }
    }
    if (next == null) return;
    _expiryTimer = Timer(
      next.difference(now) + const Duration(milliseconds: 50),
      () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _restoreReminders() async {
    final collection = plans;
    final uid = auth.currentUser?.uid;
    if (collection == null) return;
    try {
      final snapshot = await collection.get();
      for (final document in snapshot.docs) {
        if (auth.currentUser?.uid != uid) return;
        final data = document.data();
        final id = data['notificationId'];
        final time = data['reminderAt'];
        if (id is! int || time is! Timestamp) continue;
        if (time.toDate().isAfter(DateTime.now())) {
          await NotificationService.instance.scheduleOutfitReminder(
            id: id,
            reminderAt: time.toDate(),
            itemCount: (data['items'] as List? ?? []).length,
          );
        } else {
          await NotificationService.instance.cancel(id);
        }
      }
    } catch (_) {
      // Plans still load through the stream; a failed repair can be retried.
    }
  }

  Future<void> _testNotification() async {
    try {
      final sent = await NotificationService.instance.showTestNotification();
      if (!sent) {
        Get.snackbar(
          'Notifications disabled',
          'Allow notifications in your phone settings.',
        );
      }
    } catch (_) {
      Get.snackbar(
        'Could not show test reminder',
        'Check your notification settings and try again.',
      );
    }
  }

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
      actions: [
        IconButton(
          tooltip: 'Test notification',
          onPressed: _testNotification,
          icon: const Icon(Icons.notifications_active_outlined),
        ),
      ],
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
                    stream: _plansStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Could not load outfit plans.'),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final now = DateTime.now();
                      _refreshWhenNextPlanExpires(snapshot.data!.docs, now);
                      final docs =
                          snapshot.data!.docs.where((d) {
                            return isUpcomingOutfitPlan(d.data(), now);
                          }).toList()..sort(
                            (a, b) => outfitPlanExpiresAt(
                              a.data(),
                            )!.compareTo(outfitPlanExpiresAt(b.data())!),
                          );
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No upcoming outfits.\nCreate a new plan above. Past plans are saved in My Outfits.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
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
    final date =
        (doc.data()['date'] as Timestamp?)?.toDate() ??
        outfitPlanExpiresAt(doc.data())!;
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
    if (_savingPlan) return;
    _savingPlan = true;
    final values = closet.clothes.where((x) => ids.contains(x.id)).map((x) {
      final dynamic closetItem = x;
      final String? assetPath = closetItem.assetPath as String?;
      return {
        'id': x.id,
        'category': x.category,
        'imageUrl': x.imageUrl,
        'assetPath': ?assetPath,
      };
    }).toList();
    final date = DateUtils.dateOnly(reminderAt);
    final id =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final notificationId = date.year * 10000 + date.month * 100 + date.day;
    try {
      await _remindersRestored;
      final service = NotificationService.instance;
      if (!await service.canSchedulePreciseReminders()) {
        final enable = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Allow precise reminders?'),
            content: const Text(
              'Allow StyleSync in Android’s Alarms & reminders settings to receive your outfit reminder at the selected time. Without this, Android may delay it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Use approximate'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
        if (enable == true) await service.requestPreciseReminderPermission();
      }
      await plans!.doc(id).set({
        'date': Timestamp.fromDate(date),
        'reminderAt': Timestamp.fromDate(reminderAt),
        'notificationId': notificationId,
        'items': values,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ReminderScheduleStatus? reminderStatus;
      try {
        reminderStatus = await NotificationService.instance
            .scheduleOutfitReminder(
              id: notificationId,
              reminderAt: reminderAt,
              itemCount: values.length,
            );
      } catch (_) {
        // The outfit is still safely stored even if the OS rejects a reminder.
      }

      Get.back();
      Get.snackbar('Outfit planned', switch (reminderStatus) {
        ReminderScheduleStatus.exact =>
          'Reminder set for ${_formatTime(reminderAt)}.',
        ReminderScheduleStatus.approximate =>
          'Reminder set for around ${_formatTime(reminderAt)}. Android may delay it because precise reminders are disabled.',
        ReminderScheduleStatus.notificationsDisabled =>
          'Outfit saved. Enable notifications in your phone settings to receive reminders.',
        ReminderScheduleStatus.timePassed =>
          'Outfit saved, but the reminder time has already passed. Choose a future time.',
        null =>
          'Outfit saved, but the reminder could not be scheduled. Please try again.',
      });
    } catch (e) {
      Get.snackbar('Error', 'Could not save outfit: $e');
    } finally {
      _savingPlan = false;
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
            try {
              await doc.reference.delete();
            } catch (_) {
              Get.snackbar('Could not delete outfit', 'Please try again.');
              return;
            }
            final notificationId = doc.data()['notificationId'];
            if (notificationId is int) {
              try {
                await NotificationService.instance.cancel(notificationId);
              } catch (_) {
                Get.snackbar(
                  'Reminder could not be cancelled',
                  'The outfit was deleted. Check your phone reminders.',
                );
              }
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
