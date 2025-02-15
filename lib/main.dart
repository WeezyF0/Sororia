import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:complaints_app/screens/complaint_map_screen.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
      home: ComplaintsMapScreen(),  
    );
  }
}



