import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  var isLoading = false.obs;

  Future<void> register(String name, String email, String password) async {
    try {
      isLoading.value = true;
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password
      );

      await _db.collection('users').doc(userCred.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': DateTime.now().toIso8601String(),
      });

      Get.snackbar("Success", "Account created successfully!");
    } on FirebaseAuthException catch (e) {
      Get.snackbar("Error", e.message ?? "Registration failed");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      Get.snackbar("Success", "Logged in successfully!");
    } on FirebaseAuthException catch (e) {
      Get.snackbar("Error", e.message ?? "Login failed");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}