import 'package:firebase_auth/firebase_auth.dart';

Future<User?> signUpWithEmail(String email, String password) async {
  try {
    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  } catch (e) {
    print("Error: $e");
    return null;
  }
}

Future<User?> loginWithEmail(String email, String password) async {
  try {
    UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  } catch (e) {
    print("Error: $e");
    return null;
  }
}
