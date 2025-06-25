import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import 'home.dart';
import 'signup_screen.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _auth = AuthService();

  // Sororia pink color from logo
  final Color sororiaPink = const Color(0xFFE91E63);

  void _login(BuildContext context) async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    
    // Check if email is registered with Google
    bool isGoogleAccount = await _auth.checkIfGoogleAccount(email);
    
    if (isGoogleAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("This email is registered with Google. Please use 'Sign in with Google' instead."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    final user = await _auth.login(email, password);
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed")),
      );
    }
  }

  void _loginWithGoogle(BuildContext context) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      await googleSignIn.signOut(); // Ensure fresh sign-in
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        print("Google Sign-In canceled by user");
        return;
      }

      final email = googleUser.email;
      print("Attempting Google Sign-In with email: $email");

      // Check if this email already has a password account
      final bool emailExistsWithPassword = await _auth.checkIfEmailExists(email);
      if (emailExistsWithPassword) {
        // Stop if it’s already registered under email/password
        print("Email already exists with password - blocking Google sign-in");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "This email is already registered with a password. Use your password to log in.",
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        await googleSignIn.signOut();
        return;
      }

      // Proceed to get Google credential
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential;
      try {
        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        // <-- Catch the special case “account-exists-with-different-credential”
        if (e.code == "account-exists-with-different-credential") {
          print("Attempt to sign in with Google failed: same email used by another provider");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "This email is already registered with a different sign-in method. Please use that method.",
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          await googleSignIn.signOut();
          return;
        } else {
          // Otherwise, rethrow to handle normally
          rethrow;
        }
      }

      // If we reach here, sign-in succeeded
      final user = userCredential.user;
      if (user != null) {
        await _auth.storeGoogleUserData(user);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomePage()));
      }
    } catch (e) {
      print("Google Sign-In error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred during Google Sign-In: ${e.toString()}")),
      );
    }
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo2.png', height: 120),
                SizedBox(height: 24),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: "Email"),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(labelText: "Password"),
                  obscureText: true,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _login(context),
                  child: Text("Login"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sororiaPink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: Image.asset('assets/images/google_icon.png', height: 20),
                  label: Text("Sign in with Google"),
                  onPressed: () => _loginWithGoogle(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 2,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SignupScreen()),
                  ),
                  child: Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(color: sororiaPink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
