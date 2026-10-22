import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_controller.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    // Validation functions
    String? validateName(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your name';
      }
      return null;
    }

    String? validateEmail(String? value) {
      if (value == null || value.trim().isEmpty) {
        return 'Please enter your email';
      }
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
        return 'Please enter a valid email address';
      }
      return null;
    }

    String? validatePassword(String? value) {
      if (value == null || value.isEmpty) {
        return 'Please enter a password';
      }
      if (value.length < 6) {
        return 'Password must be at least 6 characters';
      }
      if (!value.contains(RegExp(r'[A-Z]'))) {
        return 'Password must contain at least 1 uppercase letter';
      }
      if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
        return 'Password must contain at least 1 special character';
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text('Create Account', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Join StyleSync today', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 40),
                
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: validateName,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: 'Must be at least 6 characters, 1 uppercase letter, and 1 special character.',
                  ),
                  obscureText: true,
                  validator: validatePassword,
                ),
                const SizedBox(height: 32),
                
                // Sign Up Button
                Obx(() => authController.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            authController.register(
                              nameController.text.trim(),
                              emailController.text.trim(),
                              passwordController.text.trim(),
                            );
                          }
                        },
                        child: const Text('Sign Up'),
                      )),
                
                const SizedBox(height: 20),
                
                // Google Sign In Button
                Obx(() {
                  if (authController.isLoading.value) {
                    return const SizedBox.shrink();
                  } else {
                    return OutlinedButton(
                      onPressed: () {
                        authController.signInWithGoogle();
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text(
                        'Continue with Google',
                        style: TextStyle(fontSize: 16, color: Colors.black),
                      ),
                    );
                  }
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}