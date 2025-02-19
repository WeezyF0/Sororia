import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddComplaintScreen extends StatefulWidget {
  const AddComplaintScreen({super.key});

  @override
  _AddComplaintScreenState createState() => _AddComplaintScreenState();
}

class _AddComplaintScreenState extends State<AddComplaintScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied. Enable them in settings.");
    }
  }

  Future<void> _submitComplaint(BuildContext context) async {
    String complaintText = _controller.text.trim();
    if (complaintText.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await _checkLocationPermission(); // Check and request permission

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await FirebaseFirestore.instance.collection('complaints').add({
        'issue_type': 'app',
        'text': complaintText,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close screen after submission
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error adding complaint: $error")),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Complaint")),
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
