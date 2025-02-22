import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddComplaintScreen extends StatefulWidget {
  @override
  _AddComplaintScreenState createState() => _AddComplaintScreenState();
}

class _AddComplaintScreenState extends State<AddComplaintScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  late String? apiKey;

  @override
  void initState() {
    super.initState();
    apiKey = dotenv.env['gemini-api'];
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions are permanently denied");
      }
    }
  }

  Future<String?> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      return placemarks.isNotEmpty ? placemarks.first.locality ?? "Unknown Location" : "Unknown Location";
    } catch (_) {
      return "Unknown Location";
    }
  }

  Future<Map<String, dynamic>?> _getGeminiResponse(String complaintText) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception("Gemini API Key is missing!");
    }

    final model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey!,
      generationConfig: GenerationConfig(
        temperature: 1,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
        responseMimeType: 'application/json',
        responseSchema: Schema(
          SchemaType.object,
          enumValues: [],
          requiredProperties: ["location", "Issue Type", "Text_description"],
          properties: {
            "location": Schema(
              SchemaType.string,
            ),
            "timestamp": Schema(
              SchemaType.string,
            ),
            "Issue Type": Schema(
              SchemaType.object,
              properties: {
                "Water": Schema(
                  SchemaType.boolean,
                ),
                "Food": Schema(
                  SchemaType.boolean,
                ),
                "Hygiene": Schema(
                  SchemaType.boolean,
                ),
                "Social": Schema(
                  SchemaType.boolean,
                ),
                "Others": Schema(
                  SchemaType.boolean,
                ),
              },
            ),
            "Text_description": Schema(
              SchemaType.string,
            ),
          },
        ),
      ),
      systemInstruction: Content.system('You will be given a complaint about a specific issue in a particular place formalize it, into the format having location, time stamp, the broader types need to be marked as true, and also try be as honest as you can about the issue no alteration'),
    );

    // Start a fresh chat without the example in history
    final chat = model.startChat();
    
    // Send your complaint as a multi-part message like in the example
    final response = await chat.sendMessage(Content.multi([
        TextPart(complaintText),
    ]));

    print("Raw response: ${response.text}"); // Debug print

    if (response.text == null) {
      return null;
    }

    try {
      // Clean up the response text by removing 'json' prefix if present
      String cleanJson = response.text!.replaceAll('json\n', '');
      final result = jsonDecode(cleanJson);
      print("Parsed result: $result"); // Debug print
      return result;
    } catch (e) {
      print("Error parsing Gemini response: $e");
      print("Raw response: ${response.text}");
      return null;
    }
  }


  Future<void> _submitComplaint(BuildContext context) async {
    String complaintText = _controller.text.trim();
    if (complaintText.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _checkLocationPermission();
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      String locationName = await _getLocationName(position.latitude, position.longitude) ?? "Unknown";
      String timestamp = DateTime.now().toIso8601String();

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      String userId = user.uid;

      Map<String, dynamic>? structuredComplaint = await _getGeminiResponse(complaintText);

      List<String> issueTypes = [];
      if (structuredComplaint != null && structuredComplaint.containsKey("Issue Type")) {
        structuredComplaint["Issue Type"].forEach((key, value) {
          if (value == true) issueTypes.add(key);
        });
      }

      Map<String, dynamic> formattedComplaint = {
        "issue_type": issueTypes.join(", "),
        "latitude": position.latitude,
        "longitude": position.longitude,
        "location": locationName,
        "text": structuredComplaint?["Text_description"] ?? complaintText, // Use the processed description
        "timestamp": timestamp,
        "user_id": userId
      };

      await FirebaseFirestore.instance.collection('complaints').add(formattedComplaint);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${error.toString()}")),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Submit Complaint")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(labelText: "Enter your complaint"),
              maxLines: 5,
            ),
            SizedBox(height: 20),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () => _submitComplaint(context),
                    child: Text("Submit Complaint"),
                  ),
          ],
        ),
      ),
    );
  }
}
