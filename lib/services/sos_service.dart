import 'dart:convert'; // Required for jsonEncode
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For kDebugMode (optional, for better logging)

class SOSService {
  // Firebase instances (can be used for other SOS-related functionalities if needed)
  // final FirebaseAuth _auth = FirebaseAuth.instance;
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _notificationApiUrl =
      'https://v0-new-project-go6lmdu53tt.vercel.app/api/send-notification-to-multiple';

  /// Sends an SOS notification to multiple recipients via their FCM tokens.
  ///
  /// [senderUid] - The UID of the user initiating the SOS.
  /// [recipientTokens] - A list of FCM tokens of the devices to send the notification to.
  ///
  /// Throws an [Exception] if the HTTP request fails or returns a non-200 status code.
  Future<void> sendSosNotification({
    required String senderUid,
    required List<String> recipientTokens,
    String title = "SOS Alert!", // Default title
    String body = "An emergency SOS has been triggered. Please check on the sender.", // Default body
  }) async {
    if (recipientTokens.isEmpty) {
      if (kDebugMode) {
        print("SOS Service: No recipient tokens provided. Skipping notification.");
      }
      return; // No tokens to send to
    }

    final Map<String, dynamic> payload = {
      "tokens": recipientTokens,
      "title": title,
      "body": body,
      "data": {
        "senderUid": senderUid, // Including sender's UID in the data payload
        "type": "sos",   // Custom type to identify the notification
        "timestamp": DateTime.now().toIso8601String(),
      }
    };

    try {
      if (kDebugMode) {
        print("SOS Service: Sending SOS notification with payload: ${jsonEncode(payload)}");
      }

      final response = await http.post(
        Uri.parse(_notificationApiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('SOS Service: Notification sent successfully.');
          print('SOS Service: Response: ${response.body}');
        }
        // You can parse response.body if the API returns useful data on success
      } else {
        if (kDebugMode) {
          print(
              'SOS Service: Failed to send notification. Status Code: ${response.statusCode}');
          print('SOS Service: Response: ${response.body}');
        }
        throw Exception(
            'Failed to send SOS notification. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('SOS Service: Error sending SOS notification: $e');
      }
      // Re-throw the exception to allow the caller to handle it
      throw Exception('Error sending SOS notification: $e');
    }
  }


Future<List<String>> getEmergencyContactTokens(String userId) async {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final userDocRef = db.collection("users").doc(userId);

  // 1. Fetch the user document
  final userDocSnapshot = await userDocRef.get();

  if (!userDocSnapshot.exists) {
    print("User $userId does not exist.");
    return []; // User not found
  }

  final userData = userDocSnapshot.data();
  if (userData == null) {
    print("User data for $userId is null, though document exists.");
    return []; // Should not happen if exists is true, but good for safety
  }
  final List<dynamic>? eContactsDynamic = userData['e_contacts'];
  if (eContactsDynamic == null || eContactsDynamic.isEmpty) {
    print("User $userId has no e_contacts or it's empty.");
    return []; // No emergency contacts listed
  }

  List<String> emergencyContactUserIds = [];
  for (var contactEntry in eContactsDynamic) {
    if (contactEntry is Map<String, dynamic>) {
      final String? contactUserId = contactEntry['userId'] as String?;
      if (contactUserId != null && contactUserId.isNotEmpty) {
        emergencyContactUserIds.add(contactUserId);
      } else {
        print("Found an e_contact for user $userId without a valid 'userId' field: $contactEntry");
      }
    } else {
      print("Found an e_contact entry for user $userId that is not a Map: $contactEntry");
    }
  }

  if (emergencyContactUserIds.isEmpty) {
    print("No valid emergency contact user IDs found for $userId.");
    return [];
  }

  emergencyContactUserIds = emergencyContactUserIds.toSet().toList();

  List<Future<DocumentSnapshot<Map<String, dynamic>>>> contactDocFutures = [];
  for (String contactId in emergencyContactUserIds) {
    contactDocFutures.add(db.collection("users").doc(contactId).get());
  }

  final List<DocumentSnapshot<Map<String, dynamic>>> contactDocSnapshots =
      await Future.wait(contactDocFutures);

  List<String> allFcmTokens = [];
  for (final contactDocSnapshot in contactDocSnapshots) {
    if (contactDocSnapshot.exists) {
      final contactData = contactDocSnapshot.data();
      if (contactData != null) {
        final List<dynamic>? fcmTokensDynamic = contactData['fcmTokens'];
        if (fcmTokensDynamic != null && fcmTokensDynamic.isNotEmpty) {
          allFcmTokens.addAll(fcmTokensDynamic.whereType<String>());
        } else {
        }
      }
    } else {
    }
  }

  // Return a list of unique tokens
  return allFcmTokens.toSet().toList();
}
//also make a function identical to this but it should return emergencyContactUserIds
Future<List<String>> getEmergencyContactUserIds(String userId) async {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final userDocRef = db.collection("users").doc(userId);

  // 1. Fetch the user document
  final userDocSnapshot = await userDocRef.get();

  if (!userDocSnapshot.exists) {
    print("User $userId does not exist.");
    return []; // User not found
  }

  final userData = userDocSnapshot.data();
  if (userData == null) {
    print("User data for $userId is null, though document exists.");
    return []; // Should not happen if exists is true, but good for safety
  }

  final List<dynamic>? eContactsDynamic = userData['e_contacts'];
  if (eContactsDynamic == null || eContactsDynamic.isEmpty) {
    print("User $userId has no e_contacts or it's empty.");
    return []; // No emergency contacts listed
  }

  List<String> emergencyContactUserIds = [];
  for (var contactEntry in eContactsDynamic) {
    if (contactEntry is Map<String, dynamic>) {
      final String? contactUserId = contactEntry['userId'] as String?;
      if (contactUserId != null && contactUserId.isNotEmpty) {
        emergencyContactUserIds.add(contactUserId);
      } else {
        print("Found an e_contact for user $userId without a valid 'userId' field: $contactEntry");
      }
    } else {
      print("Found an e_contact entry for user $userId that is not a Map: $contactEntry");
    }
  }

  // Return a list of unique emergency contact user IDs
  return emergencyContactUserIds.toSet().toList();
}
}