import 'package:complaints_app/screens/complaints_map_screen.dart';
import 'package:complaints_app/screens/open_petition.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/complaint_list_screen.dart';
import 'screens/add_complaint_screen.dart';
import 'screens/add_petition_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/petitions_list_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Complaints App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthWrapper(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/complaints': (context) => ComplaintListScreen(),
        '/add_complaint': (context) => AddComplaintScreen(),
        '/add_petition': (context) => AddPetitionScreen(),
        '/petitions': (context) => PetitionListScreen(),
        '/complaints_map': (context) => ComplaintMapScreen(),
        '/open_petition': (context) => OpenPetitionScreen(),
      },
    );
  }
}

// Automatically redirects based on authentication status
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return ComplaintListScreen(); // User is logged in
        }
        return LoginScreen(); // No user logged in, show login screen
      },
    );
  }
}
