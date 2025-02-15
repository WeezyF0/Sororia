import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> signUp(String email, String password) async {
  try {
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email, password: password);
    User? user = result.user;

    if (user != null) {
      print("User created: ${user.uid}");
      await _db.collection("users").doc(user.uid).set({
        "email": email,
        "createdAt": FieldValue.serverTimestamp(),
      }).then((_) {
        print("User successfully saved in Firestore.");
      }).catchError((error) {
        print("Firestore Save Error: $error");
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

  Future<void> logout() async {
    await _auth.signOut();
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  
}
