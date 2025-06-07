import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:complaints_app/services/sos_service.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  _SOSScreenState createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  bool _isLoading = false;
  bool _sosActive = false;
  late SOSService sosService;

  @override
  void initState() {
    super.initState();
    sosService = SOSService();
    _checkCurrentSOSStatus();
  }

  Future<void> _checkCurrentSOSStatus() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('sos')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          setState(() {
            _sosActive = data['active'] ?? false;
          });
        }
      }
    } catch (e) {
      // Handle error silently or show error message
    }
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

  Future<void> _toggleSOS(bool value) async {
    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not authenticated");
      String userId = user.uid;

      if (value) {
        // Activate SOS
        await _checkLocationPermission();
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        String locationName =
            await _getLocationName(position.latitude, position.longitude) ??
            "Unknown";
        String timestamp = DateTime.now().toIso8601String();
        
        // Get emergency contact tokens
        List<String> tokens = await sosService.getEmergencyContactTokens(userId);
        
        // Send SOS notification
        await sosService.sendSosNotification(
          senderUid: userId,
          recipientTokens: tokens,
          title: "EMERGENCY SOS ALERT!",
          body: "Emergency alert from ${user.displayName ?? 'a user'} at $locationName",
        );
        
        List<String> uids = await sosService.getEmergencyContactUserIds(userId);

        Map<String, dynamic> formattedSOS = {
          "latitude": position.latitude,
          "longitude": position.longitude,
          "location": locationName,
          "active": true, 
          "timestamp": timestamp,
          "timestamp_ms": DateTime.now().millisecondsSinceEpoch,
          "related_users": uids,
        };

        await FirebaseFirestore.instance.collection('sos').doc(userId).set(formattedSOS);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("SOS alert activated"))
          );
        }
      } else {
        // Deactivate SOS
        await FirebaseFirestore.instance
            .collection('sos')
            .doc(userId)
            .update({'active': false});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("SOS alert deactivated"))
          );
        }
      }

      setState(() => _sosActive = value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${error.toString()}"))
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        backgroundColor: Colors.red,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _sosActive ? 'SOS Alert is Active' : 'SOS Alert is Inactive',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _sosActive ? Colors.red : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              _sosActive 
                ? 'Your emergency contacts have been notified'
                : 'Toggle to activate emergency alert',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.red)
                : GestureDetector(
                    onTap: _isLoading ? null : () => _toggleSOS(!_sosActive),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: _sosActive ? Colors.red : Colors.grey,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_sosActive ? Colors.red : Colors.grey).withOpacity(0.5),
                            spreadRadius: 5,
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _sosActive ? 'ACTIVE' : 'INACTIVE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 30),
            // Alternative switch UI
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('SOS Alert: '),
                Switch(
                  value: _sosActive,
                  onChanged: _isLoading ? null : _toggleSOS,
                  activeColor: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'This will alert your emergency contacts with your current location',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}