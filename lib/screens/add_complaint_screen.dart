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
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      return placemarks.isNotEmpty
          ? placemarks.first.locality ?? "Unknown Location"
          : "Unknown Location";
    } catch (_) {
      return "Unknown Location";
    }
  }

  Future<Map<String, dynamic>?> _getGeminiResponse(String complaintText) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception("Gemini API Key is missing!");
    }

    // Define the allowed tags explicitly
    final List<String> allowedTags = [
      "Workplace", "Family", "Safety", "Social", "Others", 
      "Severe", "Institutional", "Discrimination", "Harassment", 
      "Healthcare", "Education", "Legal", "Domestic", "Public", 
      "Online", "Financial", "Professional", "Transport", "City", "Night"
    ];

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey!,
      generationConfig: GenerationConfig(
        temperature: 1,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
        responseMimeType: 'application/json',
        responseSchema: Schema(
          SchemaType.object,
          requiredProperties: ["Issue Type", "Text_description", "Primary_tags"],
          properties: {
            "Issue Type": Schema(
              SchemaType.object,
              requiredProperties: allowedTags,
              properties: Map.fromEntries(
                allowedTags.map((tag) => MapEntry(tag, Schema(SchemaType.boolean)))
              ),
            ),
            "Primary_tags": Schema(
              SchemaType.array,
              items: Schema(
                SchemaType.string,
                enumValues: allowedTags, // Only allow tags from the predefined list
              ),
              description: "The 3 most relevant tags for this complaint, in order of relevance",
            ),
            "Text_description": Schema(
              SchemaType.string,
            ),
          },
        ),
      ),
      systemInstruction: Content.system(
        'You will be given an experience from a woman about a specific issue. '
        'Analyze it carefully and do the following:\n'
        '1. Formalize it into a brief but precise description\n'
        '2. Mark all applicable issue types as true\n'
        '3. Select ONLY the 3 MOST RELEVANT tags from this list ONLY: ${allowedTags.join(", ")}\n'
        '4. List them in the Primary_tags array in order of relevance\n'
        '5. Be honest and accurate in your assessment without altering the core issue\n'
        '6. Be sensitive to the serious nature of these reports and prioritize tags that best categorize the experience'
      ),
    );

    // Rest of the function remains the same
    final chat = model.startChat();
    final response = await chat.sendMessage(
      Content.multi([TextPart(complaintText)]),
    );

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
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      String locationName =
          await _getLocationName(position.latitude, position.longitude) ??
          "Unknown";
      String timestamp = DateTime.now().toIso8601String();

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");

      String userId = user.uid;

      // Get the structured complaint using Gemini
      Map<String, dynamic>? structuredComplaint = await _getGeminiResponse(
        complaintText,
      );

      // Use primary tags if available, otherwise fall back to issue types
      List<String> issueTypes = [];
      
      if (structuredComplaint != null) {
        if (structuredComplaint.containsKey("Primary_tags") && 
            structuredComplaint["Primary_tags"] is List) {
            
          // Use the AI-selected primary tags (limited to 4)
          issueTypes = List<String>.from(structuredComplaint["Primary_tags"]);
        } else if (structuredComplaint.containsKey("Issue Type")) {
          // Fall back to old method: get all true tags
          Map<String, dynamic> allTags = structuredComplaint["Issue Type"];
          List<MapEntry<String, dynamic>> sortedTags = allTags.entries.where(
            (entry) => entry.value == true
          ).toList();
          
          // Limit to 4 tags
          sortedTags = sortedTags.take(4).toList();
          issueTypes = sortedTags.map((e) => e.key).toList();
        }
      }

      Map<String, dynamic> formattedComplaint = {
        "issue_type": issueTypes.join(", "),
        "issue_tags": issueTypes, // StoSre as array for better querying
        "latitude": position.latitude,
        "longitude": position.longitude,
        "location": locationName,
        "original_text": complaintText, 
        "processed_text": structuredComplaint?["Text_description"] ?? complaintText,
        "timestamp": timestamp,
        "timestamp_ms": DateTime.now().millisecondsSinceEpoch,
        "user_id": userId,
        "queried": false,
        "upvotes": 0,
      };

      // Add the complaint document and then update user's my_c field with the new complaint's ID.
      DocumentReference complaintRef = await FirebaseFirestore.instance
          .collection('complaints')
          .add(formattedComplaint);

      // Update the user's my_c array.
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'my_c': FieldValue.arrayUnion([complaintRef.id]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Your experience has been shared successfully"))
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${error.toString()}"))
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "Share Experience",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          titleSpacing: 0,
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
                  Colors.purple.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: "Share your experience",
                  hintText: "Tell us what happened...",
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: () => _submitComplaint(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text(
                      "Submit",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}