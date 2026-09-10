import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController resetEmailController = TextEditingController();

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
        return 'Please enter your password';
      }
      return null; // For login, we just check if it's empty. Firebase will handle incorrect passwords.
    }

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              child: Form(
                key: formKey,
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Welcome Back', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Login to sync your style', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 40),
                
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: validatePassword,
                ),
                const SizedBox(height: 16),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Get.dialog(
                        AlertDialog(
                          title: const Text('Reset Password'),
                          content: TextField(
                            controller: resetEmailController,
                            decoration: const InputDecoration(labelText: 'Enter your email'),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                if (resetEmailController.text.trim().isNotEmpty && 
                                    RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(resetEmailController.text.trim())) {
                                  authController.resetPassword(resetEmailController.text.trim());
                                } else {
                                  Get.snackbar("Error", "Please enter a valid email");
                                }
                              },
                              child: const Text('Send Link'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                Obx(() => authController.isLoading.value
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            authController.login(
                              emailController.text.trim(),
                              passwordController.text.trim(),
                            );
                          }
                        },
                        child: const Text('Login'),
                      )),
                const SizedBox(height: 20),
                
                   const SizedBox(height: 20),
                // Google Sign In Button
                Obx(() => authController.isLoading.value
                  ? const SizedBox.shrink()
                  : OutlinedButton(
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/google.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Continue with Google',
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                    )),
                    
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    GestureDetector(
                      onTap: () => Get.toNamed('/signup'),
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                )
              ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
