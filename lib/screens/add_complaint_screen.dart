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
  State<AddComplaintScreen> createState() => _AddComplaintScreenState();
}

class _AddComplaintScreenState extends State<AddComplaintScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _isLoading = false;
  bool _showAdvanced = false;
  bool _manualTagMode = false;

  Set<String> _selectedTags = {};
  String? _customLocation;
  DateTime? _customDateTime;

  late final String? _apiKey;

  final List<String> allowedTags = [
    "Workplace","Family","Safety","Social","Others","Severe","Institutional",
    "Discrimination","Harassment","Healthcare","Education","Legal","Domestic",
    "Public","Online","Financial","Professional","Transport","City","Night",
  ];

  @override
  void initState() {
    super.initState();
    _apiKey = dotenv.env['gemini-api'];
  }

  /* ───────────────────────────── Location helpers ─────────────────────────── */

  Future<void> _ensureLocationPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        throw Exception("Location permission permanently denied");
      }
    }
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      return placemarks.isNotEmpty
          ? placemarks.first.locality ?? "Unknown Location"
          : "Unknown Location";
    } catch (_) {
      return "Unknown Location";
    }
  }

  // Add this new method for forward geocoding
  Future<Map<String, dynamic>?> _geocodeAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final location = locations.first;
        return {
          'latitude': location.latitude,
          'longitude': location.longitude,
        };
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /* ───────────────────────────── Gemini helper ────────────────────────────── */

  Future<Map<String, dynamic>?> _callGemini(String text) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception("Gemini API key missing");
    }

    final model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey!,
      generationConfig: GenerationConfig(
        temperature: 1,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 8192,
        responseMimeType: 'application/json',
        responseSchema: Schema(
          SchemaType.object,
          requiredProperties: ["Issue Type","Text_description","Primary_tags"],
          properties: {
            "Issue Type": Schema(
              SchemaType.object,
              requiredProperties: allowedTags,
              properties: {
                for (final t in allowedTags) t: Schema(SchemaType.boolean)
              },
            ),
            "Primary_tags": Schema(
              SchemaType.array,
              items: Schema(SchemaType.string, enumValues: allowedTags),
            ),
            "Text_description": Schema(SchemaType.string),
          },
        ),
      ),
      systemInstruction: Content.system(
        'You will be given an experience from a woman about a specific issue. '
        '1. Summarise in a brief description.\n'
        '2. Mark relevant issue types as true.\n'
        '3. Return the 3 most relevant Primary_tags from this list: '
        '${allowedTags.join(", ")}',
      ),
    );

    final chat = model.startChat();
    final res = await chat.sendMessage(Content.text(text));

    if (res.text == null) return null;

    try {
      final clean = res.text!.replaceFirst(RegExp(r'^json\s*'), '');
      return jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /* ───────────────────────────── UI builders ──────────────────────────────── */

  Widget _tagSelector() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _manualTagMode,
                onChanged: (v) {
                  setState(() {
                    _manualTagMode = v ?? false;
                    if (!_manualTagMode) _selectedTags.clear();
                  });
                },
              ),
              const Text("Manually enter tags",
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: allowedTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag,
                    style: TextStyle(
                        color: _manualTagMode
                            ? null
                            : Colors.grey.shade500)),
                selected: isSelected,
                onSelected: _manualTagMode
                    ? (sel) {
                        setState(() => sel
                            ? _selectedTags.add(tag)
                            : _selectedTags.remove(tag));
                      }
                    : null,
                selectedColor:
                    Theme.of(context).primaryColor.withOpacity(0.3),
                checkmarkColor: Theme.of(context).primaryColor,
                backgroundColor:
                    _manualTagMode ? null : Colors.grey.shade200,
              );
            }).toList(),
          ),
        ],
      );

  Widget _locationInput() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text("Custom location",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.location_on),
              hintText: "Enter location (optional)",
              border: OutlineInputBorder(),
            ),
            onChanged: (v) =>
                _customLocation = v.trim().isEmpty ? null : v.trim(),
          ),
        ],
      );

  Widget _dateTimePicker() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text("Incident date & time",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(4)),
            leading: const Icon(Icons.calendar_today),
            title: Text(_customDateTime != null
                ? "${_customDateTime!.day}/${_customDateTime!.month}/${_customDateTime!.year}"
                : "Select date"),
            subtitle: Text(_customDateTime != null
                ? "${_customDateTime!.hour.toString().padLeft(2, '0')}:${_customDateTime!.minute.toString().padLeft(2, '0')}"
                : "Current time will be used"),
            trailing: _customDateTime != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () =>
                        setState(() => _customDateTime = null),
                  )
                : null,
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _customDateTime ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(
                        _customDateTime ?? DateTime.now()));
                if (t != null) {
                  setState(() {
                    _customDateTime =
                        DateTime(d.year, d.month, d.day, t.hour, t.minute);
                  });
                }
              }
            },
          ),
        ],
      );

  /* ───────────────────────────── Submit ───────────────────────────────────── */

  Future<void> _submit() async {
    final rawText = _textController.text.trim();
    if (rawText.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      /* 1️⃣  Call Gemini irrespective of user-overrides */
      final geminiData = await _callGemini(rawText);

      /* 2️⃣  Location handling */
      double lat = 0, lng = 0;
      String locName = "Unknown";

      if (_customLocation != null && _customLocation!.isNotEmpty) {
        // User entered manual location - try to geocode it
        locName = _customLocation!;
        final geocoded = await _geocodeAddress(_customLocation!);
        if (geocoded != null) {
          lat = geocoded['latitude'];
          lng = geocoded['longitude'];
        }
        // If geocoding fails, lat/lng remain 0,0 but we keep the user's location name
      } else {
        // Use current location
        await _ensureLocationPermission();
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        lat = pos.latitude;
        lng = lng = pos.longitude;
        locName = await _reverseGeocode(lat, lng) ?? "Unknown";
      }

      /* 3️⃣  Timestamp handling */
      final incidentDateTime = _customDateTime ?? DateTime.now();
      final uploadDateTime = DateTime.now(); // Always current time for upload
      
      final incidentTimestampIso = incidentDateTime.toIso8601String();
      final uploadTimestampIso = uploadDateTime.toIso8601String();

      /* 4️⃣  Tags merge */
      List<String> finalTags;
      if (_manualTagMode && _selectedTags.isNotEmpty) {
        finalTags = _selectedTags.toList();
      } else if (geminiData != null &&
          geminiData["Primary_tags"] is List<dynamic>) {
        finalTags = List<String>.from(geminiData["Primary_tags"]);
      } else {
        finalTags = [];
      }

      /* 5️⃣  Processed text */
      final processedText =
          geminiData?["Text_description"] ?? rawText;

      /* 6️⃣  Build Firestore object */
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("Not authenticated");

      final payload = {
        "issue_type": finalTags.join(", "),
        "issue_tags": finalTags,
        "location": locName,
        "latitude": lat,
        "longitude": lng,
        "original_text": rawText,
        "processed_text": processedText,
        "timestamp": incidentTimestampIso, // When the incident occurred
        "timestamp_ms": uploadDateTime.millisecondsSinceEpoch,//rough fix for sorting to work :)
        "timestamp_uploaded": uploadTimestampIso, // When the complaint was uploaded
        "timestamp_uploaded_ms": uploadDateTime.millisecondsSinceEpoch,
        "user_id": uid,
        "queried": false,
        "upvotes": 0,
        "manual_tag_override": _manualTagMode,
        "custom_location_used": _customLocation != null,
        "custom_datetime_used": _customDateTime != null,
      };

      final ref = await FirebaseFirestore.instance
          .collection('complaints')
          .add(payload);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'my_c': FieldValue.arrayUnion([ref.id])});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Experience shared successfully")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }

    setState(() => _isLoading = false);
  }

  /* ───────────────────────────── Build ────────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        centerTitle: true,
        title: const Text("SHARE EXPERIENCE",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              fontSize: 24,
            )),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /* ── text input ── */
            SizedBox(
              height: 200,
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  labelText: "Share your experience",
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
                textAlign: TextAlign.start,
                textAlignVertical: TextAlignVertical.top,
              ),
            ),
            const SizedBox(height: 20),

            /* ── advanced toggle ── */
            CheckboxListTile(
              value: _showAdvanced,
              onChanged: (v) =>
                  setState(() => _showAdvanced = v ?? false),
              title: const Text("Enter more details",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text("Specify location, tags and time"),
              controlAffinity: ListTileControlAffinity.leading,
            ),

            /* ── advanced section ── */
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _showAdvanced
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                children: [
                  _tagSelector(),
                  _locationInput(),
                  _dateTimePicker(),
                ],
              ),
              secondChild: const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            /* ── submit button ── */
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: const Text("Submit", style: TextStyle(fontSize: 16)),
                  ),
          ],
        ),
      ),
    );
  }
}
