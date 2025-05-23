import 'package:complaints_app/screens/home.dart';
import 'package:complaints_app/screens/my_petitions.dart';
import 'package:complaints_app/screens/open_complaint.dart';
import 'package:complaints_app/screens/open_petition.dart';
import 'package:complaints_app/screens/my_complaints.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/complaint_list_screen.dart';
import 'screens/add_complaint_screen.dart';
import 'screens/add_petition_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/phone_auth.dart';
import 'screens/petitions_list_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'screens/chat_screen.dart';
import 'screens/news_screen.dart';
import 'screens/test_screen.dart';
import 'screens/news_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sororia',
      themeMode: themeProvider.themeMode,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      home: AuthWrapper(),
      routes: {
        '/home': (context) => HomePage(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/phone': (context) => PhoneAuthScreen(),
        '/complaints': (context) => ComplaintListScreen(),
        '/add_complaint': (context) => AddComplaintScreen(),
        '/add_petition': (context) => AddPetitionScreen(),
        '/petitions': (context) => PetitionListScreen(),
        '/open_petition': (context) => OpenPetitionScreen(),
        '/my_petitions': (context) => MyPetitionScreen(),
        '/my_complaints': (context) => MyComplaintScreen(),
        '/chatbot': (context) => ChatScreen(compInfo: ModalRoute.of(context)!.settings.arguments as String),
        '/news': (context) => NewsScreen(),
        '/test': (context) => const TestScreen(), // Add the test screen route
        '/news_map': (context) => NewsMapScreen(),

      },
      onGenerateRoute: (settings) {
        if (settings.name == '/open_complaint') {
          final args = settings.arguments as Map<String, dynamic>;
          final complaintData = args['complaintData'] as Map<String, dynamic>;
          final complaintId = args['complaintId'] as String;
          return MaterialPageRoute(
            builder:
                (context) => OpenComplaintScreen(
                  complaintData: complaintData,
                  complaintId: complaintId,
                ),
          );
        }
        return null;
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }
        if (snapshot.hasData) {
          return HomePage(); // Changed to HomePage instead of ComplaintListScreen
        }
        return LoginScreen();
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ColorPalette.primaryLight,
              ColorPalette.primaryLight.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', height: 120),
              SizedBox(height: 24),
              Text(
                'Sororia',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Women Empowerment Portal',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: 48),
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}