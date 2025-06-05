import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

class NotificationService {
  static FirebaseMessaging? _messaging;
  
  static FirebaseMessaging? get messaging => _messaging;

  static Future<void> initialize() async {
    if (kIsWeb) {
      // Skip Firebase Messaging initialization on web
      return;
    }
    
    _messaging = FirebaseMessaging.instance;
    
    // Request notification permissions
    await requestPermission();
    
    // Setup message handlers
    await setupMessageHandlers();
  }

  static Future<void> requestPermission() async {
    if (kIsWeb || _messaging == null) return;
    
    NotificationSettings settings = await _messaging!.requestPermission(
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

  static Future<void> setupMessageHandlers() async {
    if (kIsWeb || _messaging == null) return;
    
    // Handle notification when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // You can show a local notification here or update UI
      }
    });

    // Handle notification when app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      print('Message data: ${message.data}');
      // Navigate to specific screen based on notification data
    });

    // Get FCM token for this device
    String? token = await _messaging!.getToken();
    print('FCM Token: $token');
    // You can send this token to your server to send targeted notifications
  }

  static Future<void> setupBackgroundMessageHandler() async {
    if (kIsWeb) return;
    
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}
