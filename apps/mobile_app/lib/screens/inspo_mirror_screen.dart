import 'package:flutter/material.dart';
import 'package:get/get.dart';

class InspoMirrorScreen extends StatelessWidget {
  const InspoMirrorScreen({super.key});

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
        title: const Text('AI Inspo-Mirror', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Upload Inspiration Photo Area
              GestureDetector(
                onTap: () {
                  Get.snackbar("Coming Soon", "Image upload is under construction");
                },
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.pink.shade200, width: 2),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, size: 40, color: Colors.pink),
                      SizedBox(height: 10),
                      Text('Upload Inspiration Photo', style: TextStyle(color: Colors.pink, fontWeight: FontWeight.bold)),
                      Text('e.g., from Instagram or Pinterest', style: TextStyle(color: Colors.pink, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Generate Button
              ElevatedButton(
                onPressed: () {
                  Get.snackbar("Coming Soon", "AI Style extraction is under construction");
                },
                child: const Text('Generate Style on Digital Twin'),
              ),
              
              const Spacer(),
              
              // Result Placeholder
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text('Result will appear here', style: TextStyle(color: Colors.grey)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}