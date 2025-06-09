import 'package:complaints_app/screens/home.dart';
import 'package:complaints_app/screens/my_petitions.dart';
import 'package:complaints_app/screens/open_complaint.dart';
import 'package:complaints_app/screens/open_petition.dart';
import 'package:complaints_app/screens/my_complaints.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added import
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
import 'screens/safest_route.dart';
import 'screens/stats_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sos_screen.dart'; // Add this line
import 'screens/profile_screen.dart';

FirebaseMessaging messaging = FirebaseMessaging.instance;
// Global navigator key to use for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Helper function to update FCM token in Firestore
Future<void> _updateUserFCMTokenInFirestore(String token) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('No user logged in. FCM token will not be updated in Firestore yet.');
    return;
  }

  try {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentReference userDocRef = firestore.collection('users').doc(user.uid);

    await userDocRef.set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    print('FCM token updated/added in Firestore for user ${user.uid}');
  } catch (e) {
    print('Error updating FCM token in Firestore: $e');
  }
}

// Add a provider to store the selected protest ID
class ProtestProvider extends ChangeNotifier {
  String? _selectedProtestId;

  String? get selectedProtestId => _selectedProtestId;

  void setSelectedProtestId(String protestId) {
    _selectedProtestId = protestId;
    notifyListeners();
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

// Add this function to request notification permissions
Future<void> requestNotificationPermission() async {
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('User granted provisional permission');
  } else {
    print('User declined or has not accepted permission');
  }
}

// Add this function to show SOS banner
void _showSOSBanner(String senderUid) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: Colors.red,
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '$senderUid in trouble!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              // Navigate to home screen
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (route) => false);
            },
            child: Text(
              'VIEW',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: Text('DISMISS', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // Auto-dismiss after 10 seconds
    Future.delayed(Duration(seconds: 10), () {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      }
    });
  }
}

// Add this function to handle foreground notifications
Future<void> setupNotificationHandlers() async {
  // Handle notification when app is in foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    // Check if this is an SOS message
    if (message.data['type'] == 'sos') {
      String senderUid = message.data['senderUid'] ?? 'Someone';
      _showSOSBanner(senderUid);
    }

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
      // You can show a local notification here or update UI
    }
  });

  // Handle notification when app is opened from background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
    print('Message data: ${message.data}');

    // Check if this is an SOS message and navigate to home screen
    if (message.data['type'] == 'sos') {
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/home',
        (route) => false,
      );
    }
  });

  // Get FCM token for this device
  String? token = await messaging.getToken();
  print('FCM Token: $token');
  // You can send this token to your server to send targeted notifications

  // Attempt to update token here if user is already logged in
  if (token != null) {
    await _updateUserFCMTokenInFirestore(token);
  } else {
    print('FCM token is null, skipping update.');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Request notification permission
  await requestNotificationPermission();

  // Setup notification handlers
  await setupNotificationHandlers();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => ProtestProvider()),
      ],
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
      navigatorKey: navigatorKey, // Set global navigator key
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
        '/chatbot':
            (context) => ChatScreen(
              compInfo: ModalRoute.of(context)!.settings.arguments as String,
            ),
        '/news': (context) => NewsScreen(),
        '/test': (context) => const TestScreen(), // Add the test screen route
        '/news_map': (context) => NewsMapScreen(),
        '/safest_route': (context) => SafestRoutePage(),
        '/summary_screen': (context) => SummaryScreen(),
        '/stats_screen': (context) => StatsScreen(category: 'Category'),
        '/settings_screen': (context) => SettingsScreen(),
        '/sos': (context) => SOSScreen(), // Add this line
        '/profile_screen': (context) => ProfileScreen(),
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

  // Helper function to get and update token, to be called from build
  Future<void> _getAndUpdateFCMToken() async {
    // Wait a bit for Firebase Auth to fully initialize and currentUser to be available
    await Future.delayed(const Duration(seconds: 1));

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print(
        'AuthWrapper: No user logged in after delay. FCM token update skipped.',
      );
      return;
    }

    String? token = await messaging.getToken();
    if (token != null) {
      await _updateUserFCMTokenInFirestore(token);
    } else {
      print('FCM token is null, skipping update.');
    }
    }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }
        if (snapshot.hasData) {
          // User is logged in, ensure FCM token is updated
          // Call this asynchronously, don't await here to avoid blocking build
          _getAndUpdateFCMToken();
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
