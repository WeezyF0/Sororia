import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;

      if (user != null) {
        await _db.collection("users").doc(user.uid).set({
          "email": email,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      return user;
    } catch (e) {
      print("Signup Error: $e");
      return null;
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;

      if (user != null) {
        await _db.collection("users").doc(user.uid).set({
          "email": user.email,
          "name": user.displayName,
          "createdAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return user;
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> storeGoogleUserData(User user) async {
    try {
      await _db.collection("users").doc(user.uid).set({
        "email": user.email,
        "name": user.displayName,
        "createdAt": FieldValue.serverTimestamp(),
        // Add any additional fields you want to store
      }, SetOptions(merge: true)); // merge: true will update fields without overwriting existing ones
    } catch (e) {
      print("Error storing Google user data: $e");
    }
  }

  /// Checks if an email exists in Firebase Auth with password provider
  /// Checks if an email exists in Firebase Auth with password provider
  Future<bool> checkIfEmailExists(String email) async {
    try {
      print("Checking if email exists with password auth: $email");
      // Fetch sign-in methods for the email
      List<String> methods = await _auth.fetchSignInMethodsForEmail(email);
      print("Available auth methods for $email: $methods");
      
      // If email/password is in the list of methods, the email exists with password auth
      bool exists = methods.contains('password');
      print("Email exists with password auth: $exists");
      return exists;
    } catch (e) {
      print("Error checking email existence: $e");
      return false;
    }
  }

  /// Checks if an email is registered with Google provider
  Future<bool> checkIfGoogleAccount(String email) async {
    try {
      print("Checking if email exists with Google auth: $email");
      // Fetch sign-in methods for the email
      List<String> methods = await _auth.fetchSignInMethodsForEmail(email);
      print("Available auth methods for $email: $methods");
      
      // Check if Google is in the list of providers
      bool isGoogle = methods.contains('google.com');
      print("Email exists with Google auth: $isGoogle");
      return isGoogle;
    } catch (e) {
      print("Error checking Google account: $e");
      return false;
    }
  }
}
