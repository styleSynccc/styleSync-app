import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VirtualTryOnScreen extends StatelessWidget {
  const VirtualTryOnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: const Text('Virtual Try-On', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Digital Twin Placeholder
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.accessibility_new, size: 80, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('Digital Twin', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Select Outfit Button
              ElevatedButton(
                onPressed: () {
                  Get.snackbar("Coming Soon", "AI Try-On generation is under construction");
                },
                child: const Text('Select Outfit to Try On'),
              ),
              
              // Selected Items List
              Expanded(
                flex: 1,
                child: ListView(
                  padding: const EdgeInsets.only(top: 20),
                  children: const [
                    Text('Selected Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text('- No items selected yet', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}