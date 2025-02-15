import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/complaint_list_screen.dart';
import 'screens/add_complaint_screen.dart';
import 'screens/add_petition_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/petitions_list_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, 
  );
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
      initialRoute: '/login',  // Change as needed
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/complaints': (context) => ComplaintListScreen(),
        '/add_complaint': (context) => AddComplaintScreen(),
        '/add_petition': (context) => AddPetitionScreen(),
        '/petitions': (context) => PetitionListScreen(),
      },
    );
  }
}
