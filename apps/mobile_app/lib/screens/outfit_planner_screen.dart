import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/closet_controller.dart';

class OutfitPlannerScreen extends StatefulWidget {
  const OutfitPlannerScreen({super.key});
  @override
  State<OutfitPlannerScreen> createState() => _OutfitPlannerScreenState();
}

class _OutfitPlannerScreenState extends State<OutfitPlannerScreen> {
  late final ClosetController closet = Get.isRegistered<ClosetController>()
      ? Get.find<ClosetController>() : Get.put(ClosetController());
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>>? get plans {
    final user = auth.currentUser;
    return user == null ? null : db.collection('users').doc(user.uid).collection('outfitPlans');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Outfit Planner'), backgroundColor: Colors.white),
    backgroundColor: Colors.white,
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(14)),
            child: const Row(children: [
              Icon(Icons.calendar_today, color: Colors.green), SizedBox(width: 14),
              Expanded(child: Text('Select a date to plan an outfit', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
              Icon(Icons.add, color: Colors.green),
            ]),
          ),
        ),
        const SizedBox(height: 26),
        const Text('Upcoming Outfits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Expanded(child: plans == null ? const Center(child: Text('Please sign in first.')) : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: plans!.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text('Could not load outfit plans.'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final today = DateUtils.dateOnly(DateTime.now());
            final docs = snapshot.data!.docs.where((d) {
              final value = d.data()['date'];
              return value is Timestamp && !value.toDate().isBefore(today);
            }).toList()..sort((a, b) => (a.data()['date'] as Timestamp).compareTo(b.data()['date'] as Timestamp));
            if (docs.isEmpty) return const Center(child: Text('No outfits planned yet.\nTap above to create one!', textAlign: TextAlign.center));
            return ListView.separated(
              itemCount: docs.length, separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _planCard(docs[i]),
            );
          },
        )),
      ]),
    ),
  );

  Widget _planCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final date = (doc.data()['date'] as Timestamp).toDate();
    final items = (doc.data()['items'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      SizedBox(width: 65, child: Text('${date.day}/${date.month}\n${date.year}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
      Expanded(child: SizedBox(height: 70, child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: items.length, separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, i) => SizedBox(width: 60, child: _image(items[i])),
      ))),
      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(doc.reference)),
    ])));
  }

  Widget _image(Map<String, dynamic> data) {
    final asset = data['assetPath'] as String?;
    return asset != null && asset.isNotEmpty
        ? Image.asset(asset, fit: BoxFit.contain)
        : Image.network(data['imageUrl'] ?? '', fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image));
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
    final date = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: DateTime(now.year + 2));
    if (date != null) _chooseItems(date);
  }

  void _chooseItems(DateTime date) {
    final selected = <String>{};
    Get.bottomSheet(StatefulBuilder(builder: (context, update) => Container(
      height: Get.height * .75, padding: const EdgeInsets.all(20), color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Choose outfit for ${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Expanded(child: GridView.builder(
          itemCount: closet.clothes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemBuilder: (_, i) {
            final item = closet.clothes[i]; final chosen = selected.contains(item.id);
            final dynamic closetItem = item;
            final String? assetPath = closetItem.assetPath as String?;
            return InkWell(onTap: () => update(() => chosen ? selected.remove(item.id) : selected.add(item.id)), child: Container(
              decoration: BoxDecoration(color: Colors.grey.shade100, border: Border.all(color: chosen ? Colors.green : Colors.transparent, width: 3), borderRadius: BorderRadius.circular(12)),
              child: Stack(children: [Positioned.fill(child: Padding(padding: const EdgeInsets.all(5), child: assetPath != null && assetPath.isNotEmpty ? Image.asset(assetPath, fit: BoxFit.contain) : Image.network(item.imageUrl, fit: BoxFit.contain))), if (chosen) const Align(alignment: Alignment.topRight, child: Icon(Icons.check_circle, color: Colors.green))]),
            ));
          },
        )),
        ElevatedButton(onPressed: selected.isEmpty ? null : () => _save(date, selected), child: Text('Save Outfit (${selected.length})')),
      ]),
    )), isScrollControlled: true);
  }

  Future<void> _save(DateTime date, Set<String> ids) async {
    final values = closet.clothes.where((x) => ids.contains(x.id)).map((x) {
      final dynamic closetItem = x;
      final String? assetPath = closetItem.assetPath as String?;
      return {'id': x.id, 'category': x.category, 'imageUrl': x.imageUrl, if (assetPath != null) 'assetPath': assetPath};
    }).toList();
    final id = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      await plans!.doc(id).set({'date': Timestamp.fromDate(DateUtils.dateOnly(date)), 'items': values, 'updatedAt': FieldValue.serverTimestamp()});
      Get.back(); Get.snackbar('Outfit planned', 'Your outfit was saved.');
    } catch (e) { Get.snackbar('Error', 'Could not save outfit: $e'); }
  }

  void _delete(DocumentReference<Map<String, dynamic>> ref) => Get.dialog(AlertDialog(
    title: const Text('Delete planned outfit?'), actions: [
      TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
      TextButton(onPressed: () async { Get.back(); await ref.delete(); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
    ],
  ));
}
