import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddComplaintScreen extends StatefulWidget {
  const AddComplaintScreen({super.key});
  
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

    final chat = model.startChat();
    final response = await chat.sendMessage(Content.multi([
      TextPart(complaintText),
    ]));

    print("Raw response: ${response.text}");

    if (response.text == null) {
      return null;
    }

    try {
      String cleanJson = response.text!.replaceAll('json\n', '');
      final result = jsonDecode(cleanJson);
      print("Parsed result: $result");
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
        "text": structuredComplaint?["Text_description"] ?? complaintText,
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
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
            foregroundDecoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.withOpacity(0.3), 
                  Colors.purple.withOpacity(0.3)
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Add Complaint",
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: "Enter your complaint"),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () => _submitComplaint(context),
                    child: const Text("Submit"),
                  ),
          ],
        ),
      ),
    );
  }
}