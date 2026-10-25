import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthController extends GetxController {
  AuthController({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  var isLoading = false.obs;

  User? get currentUser => _auth.currentUser;

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;

      // Trigger the Google authentication flow
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        isLoading.value = false;
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential for Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      await _auth.signInWithCredential(credential);

      // Save user data to Firestore if they are new
      final User? user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _db.collection('users').doc(user.uid).get();
        if (!userDoc.exists) {
          await _db.collection('users').doc(user.uid).set({
            'name': user.displayName ?? 'Google User',
            'email': user.email,
            'createdAt': DateTime.now().toIso8601String(),
          });
          Get.offAllNamed('/signup', arguments: {'googleMode': true});
          return;
        }

        final data = userDoc.data();
        if (data?['isProfileComplete'] == true) {
          Get.offAllNamed('/home');
        } else if (data?['gender'] != null &&
            data!['gender'].toString().isNotEmpty) {
          Get.offAllNamed('/user-setup');
        } else {
          Get.offAllNamed('/signup', arguments: {'googleMode': true});
        }
      }
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> completeGoogleRegistration(
    String name,
    String gender,
    String password,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      Get.snackbar('Error', 'Your Google session expired. Please try again.');
      return;
    }

    try {
      isLoading.value = true;
      final hasPasswordProvider = user.providerData.any(
        (provider) => provider.providerId == 'password',
      );
      if (!hasPasswordProvider) {
        final email = user.email;
        if (email == null || email.isEmpty) {
          throw FirebaseAuthException(
            code: 'missing-email',
            message: 'Your Google account did not provide an email address.',
          );
        }
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await user.linkWithCredential(credential);
      }

      await _db.collection('users').doc(user.uid).set({
        'name': name,
        'email': user.email,
        'gender': gender,
        'createdAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      Get.offAllNamed('/user-setup');
      Get.snackbar('Success', 'Complete your profile to continue.');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register(
    String name,
    String email,
    String password,
    String gender,
  ) async {
    try {
      isLoading.value = true;
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data in Firestore
      await _db.collection('users').doc(userCred.user!.uid).set({
        'name': name,
        'email': email,
        'gender': gender,
        'createdAt': DateTime.now().toIso8601String(),
      });

      Get.snackbar("Success", "Account created successfully!");
      Get.offAllNamed('/user-setup'); // <-- ADD THIS LINE
      isLoading.value = false;
      // TODO: We will navigate to the User Setup screen here later!
      // For now, it will just clear the loading spinner.
      isLoading.value = false;
    } on FirebaseAuthException catch (e) {
      isLoading.value = false; // Stop loading on error
      Get.snackbar("Error", e.message ?? "Registration failed");
    } catch (e) {
      isLoading.value = false; // Stop loading on error
      Get.snackbar("Error", e.toString());
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;
      UserCredential userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCred.user;
      if (user != null) {
        DocumentSnapshot userDoc = await _db
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          var data = userDoc.data() as Map<String, dynamic>?;

          if (data != null && data['isProfileComplete'] == true) {
            Get.offAllNamed('/home');
          } else {
            Get.offAllNamed('/user-setup');
          }
        } else {
          Get.offAllNamed('/user-setup');
        }
      }
    } on FirebaseAuthException catch (e) {
      Get.snackbar("Error", e.message ?? "Login failed");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resetPassword(String email, {bool closeDialog = false}) async {
    if (isLoading.value) return;
    try {
      isLoading.value = true;
      await _auth.sendPasswordResetEmail(email: email);
      if (closeDialog && Get.isDialogOpen == true) Get.back();
      Get.snackbar("Success", "Password reset link sent to your email.");
    } on FirebaseAuthException catch (e) {
      Get.snackbar("Error", e.message ?? "Failed to send reset email.");
    } catch (e) {
      Get.snackbar("Error", e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    Get.offAllNamed('/login');
  }
}
