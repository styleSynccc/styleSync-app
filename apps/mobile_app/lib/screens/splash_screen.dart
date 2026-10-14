import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openInitialScreen();
  }

  Future<void> _openInitialScreen() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Get.offAllNamed('/login');
      return;
    }

    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = profile.data();
      if (data?['isProfileComplete'] == true) {
        Get.offAllNamed('/home');
      } else if (data?['gender'] != null &&
          data!['gender'].toString().isNotEmpty) {
        Get.offAllNamed('/user-setup');
      } else {
        Get.offAllNamed('/signup', arguments: {'googleMode': true});
      }
    } catch (_) {
      // Keep authentication usable if the profile lookup is temporarily down.
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The Logo
            Image.asset('assets/images/stylesync_logo.png', width: 200),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.black),
          ],
        ),
      ),
    );
  }
}
