import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/auth_controller.dart';
import 'edit_profile_screen.dart';
import 'saved_outfits_screen.dart';
import 'virtual_twin_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in again.')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load your profile.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() ?? <String, dynamic>{};
          final preferences = (data['stylePreferences'] as List? ?? const [])
              .map((value) => value.toString())
              .toList();
          final height = data['height']?.toString() ?? 'Not set';
          final weight = data['weight']?.toString() ?? 'Not set';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name']?.toString() ?? 'User',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? 'No email',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    _metricCard('Height', '$height cm'),
                    const SizedBox(width: 12),
                    _metricCard('Weight', '$weight kg'),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Style Preferences',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                preferences.isEmpty
                    ? TextButton(
                        onPressed: () => Get.to(() => const EditTwinScreen()),
                        child: const Text('Add your style preferences'),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: preferences
                            .map((preference) => Chip(label: Text(preference)))
                            .toList(),
                      ),
                const SizedBox(height: 28),
                _action(
                  Icons.edit_outlined,
                  'Edit Twin',
                  'Update your twin and preferences',
                  () {
                    Get.to(() => const EditTwinScreen());
                  },
                ),
                _action(
                  Icons.view_in_ar_outlined,
                  'View Virtual Twin',
                  'Zoom and explore your saved twin',
                  () {
                    Get.to(() => const VirtualTwinScreen());
                  },
                ),
                _action(
                  Icons.grid_view_rounded,
                  'My Outfits',
                  'See your saved VTON and Inspo outfits',
                  () {
                    Get.to(() => const MyOutfitsScreen());
                  },
                ),
                _action(
                  Icons.lock_outline,
                  'Change Password',
                  'Send a reset link to your email',
                  () {
                    authController.resetPassword(user.email ?? '');
                  },
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: authController.logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metricCard(String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    ),
  );

  Widget _action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 5),
    leading: Icon(icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
