import 'package:complaints_app/screens/phone_auth.dart';
import 'package:flutter/material.dart';
import 'package:complaints_app/services/auth_service.dart';
import 'signup_screen.dart';
import 'complaint_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _auth = AuthService();

  void _login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    var user = await _auth.login(email, password);
    if (user != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ComplaintListScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          // Remove default leading/back button to avoid misalignment
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/appBar_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            // SafeArea prevents overlap with status bar
            child: SafeArea(
              // Center horizontally & vertically
              child: Center(
                // Row sized to its children, so they remain together in the center
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start, // Distribute space between children
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Custom back arrow (white)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    // Title
                    const Text(
                      "LOGIN",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            elevation: 8.0, // Adds a shadow for the card look
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0), // Rounded corners
            ),
            margin: EdgeInsets.symmetric(horizontal: 24.0),
            color: Colors.grey[900], // Dark card background color
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Shrink to fit its children
                children: [
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                  ),
                  SizedBox(height: 16.0),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: "Password",
                      labelStyle: TextStyle(color: Colors.white),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                    ),
                    style: TextStyle(color: Colors.white),
                    obscureText: true,
                  ),
                  SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300], // Button background color
                      padding: EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text("Login", style: TextStyle(fontSize: 20, color: Colors.black)),
                  ),
                  SizedBox(height: 16.0),
                  Column(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SignupScreen()),
                          );
                        },
                        child: Text(
                          "Don't have an account? Sign up",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PhoneAuthScreen()),
                          );
                        },
                        child: Text(
                          "Login with Phone Number",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
