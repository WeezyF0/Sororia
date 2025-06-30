import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:complaints_app/screens/navbar.dart';
import 'package:complaints_app/screens/open_complaint.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Replace MapController with GoogleMapController
  gmaps.GoogleMapController? _mapController;
  LatLng? _currentLocation;
  
  // Set of Google Map markers
  Set<gmaps.Marker> _gMapMarkers = {};
  
  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocationCoordinates() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError("Location permission denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError("Location permissions are permanently denied.");
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      _showError("Failed to get current location");
    }
  }

  Future<void> _getCurrentLocation() async {
    await _getCurrentLocationCoordinates();
    if (_currentLocation != null && _mapController != null) {
      _mapController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
          14.0,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Open Google Maps for directions
  Future<void> _openMapsDirections(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showError("Could not open maps application");
    }
  }
  
  // Helper method to convert LatLng to Google Maps LatLng
  gmaps.LatLng _toGoogleMapsLatLng(LatLng point) {
    return gmaps.LatLng(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            "SORORIA",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
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
      drawer: NavBar(),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('complaints').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No complaints available"));
              }

              final random = Random();
              Set<String> uniqueCoordinates = {};
              Set<gmaps.Marker> markers = {};
              gmaps.LatLng initialPosition = gmaps.LatLng(20.5937, 78.9629);
              
              // Add current location marker if available
              if (_currentLocation != null) {
                markers.add(
                  gmaps.Marker(
                    markerId: gmaps.MarkerId('current_location'),
                    position: gmaps.LatLng(_currentLocation!.latitude, _currentLocation!.longitude),
                    icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
                    infoWindow: gmaps.InfoWindow(
                      title: 'My Location',
                    ),
                  ),
                );
                initialPosition = gmaps.LatLng(_currentLocation!.latitude, _currentLocation!.longitude);
              }

              // Add complaint markers
              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                double? lat = data['latitude'] as double?;
                double? lon = data['longitude'] as double?;
                String title = data['issue_type'] ?? 'No issue type';
                String description = data['original_text'] ?? 'No description';

                if (lat == null || lon == null) continue;

                double newLat = lat;
                double newLon = lon;
                String coordKey = "$newLat,$newLon";

                while (uniqueCoordinates.contains(coordKey)) {
                  newLat += (random.nextDouble() - 0.5) * 0.1;
                  newLon += (random.nextDouble() - 0.5) * 0.1;
                  coordKey = "$newLat,$newLon";
                }
                uniqueCoordinates.add(coordKey);

                // Add Google Maps Marker
                markers.add(
                  gmaps.Marker(
                    markerId: gmaps.MarkerId('complaint_${doc.id}'),
                    position: gmaps.LatLng(newLat, newLon),
                    icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
                    infoWindow: gmaps.InfoWindow(
                      title: title,
                      snippet: description.length > 30 ? '${description.substring(0, 30)}...' : description,
                      onTap: () => showComplaintDetails(
                        context, 
                        title, 
                        description,
                        data,
                        doc.id,
                      ),
                    ),
                  ),
                );

                // Set initial position to first marker if no current location
                if (_currentLocation == null && markers.length == 1) {
                  initialPosition = gmaps.LatLng(newLat, newLon);
                }
              }

              // Add SOS markers using StreamBuilder data
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('sos').snapshots(),
                builder: (context, sosSnapshot) {
                  // Add SOS markers to the existing markers list
                  if (sosSnapshot.hasData) {
                    String? currentUid = FirebaseAuth.instance.currentUser?.uid;
                    // Inside your StreamBuilder for SOS markers
                    for (var doc in sosSnapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      
                      bool isActive = data['active'] == true;
                      List<dynamic> relatedUsers = data['related_users'] ?? [];
                      bool isUserRelated = relatedUsers.contains(currentUid);
                      
                      if (!isActive || !isUserRelated) continue;
                      
                      double? lat = data['latitude'] as double?;
                      double? lon = data['longitude'] as double?;
                      String? userId = doc.id;
                      
                      if (lat == null || lon == null) continue;
                      
                      // Add SOS marker
                      markers.add(
                        gmaps.Marker(
                          markerId: gmaps.MarkerId('sos_$userId'),
                          position: gmaps.LatLng(lat, lon),
                          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange),
                          infoWindow: gmaps.InfoWindow(
                            title: 'SOS Alert',
                            snippet: 'Click for details',
                            onTap: () => _showSOSDetails(context, data, doc.id),
                          ),
                        ),
                      );
                    }
                  }

                  // Store updated markers in state
                  _gMapMarkers = markers;

                  // Return Google Map instead of FlutterMap
                  return gmaps.GoogleMap(
                    initialCameraPosition: gmaps.CameraPosition(
                      target: initialPosition,
                      zoom: 10,
                    ),
                    markers: markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapType: gmaps.MapType.normal,
                    trafficEnabled: true,  // Enable traffic view
                    onMapCreated: (gmaps.GoogleMapController controller) {
                      _mapController = controller;
                    },
                  );
                },
              );
            },
          ),

          /// Current Location Button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),

          // Show options
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: _buildOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionTile(context, "View Experiences", CupertinoIcons.doc_text_search, Colors.orange, '/complaints'),
            _buildOptionTile(context, "View Active Petitions", CupertinoIcons.collections, Colors.green, '/petitions'),
            _buildOptionTile(context, "Local News", Icons.newspaper_outlined, Colors.purple, '/news'),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, String title, IconData icon, Color color, String route) {
    return ListTile(
      leading: Icon(icon, color: color, size: 32),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      onTap: () {
        Navigator.of(context).pushNamed(route);
      },
    );
  }

  void showComplaintDetails(
    BuildContext context, 
    String title, 
    String description, 
    Map<String, dynamic> complaintData,
    String complaintId,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); 
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OpenComplaintScreen(
                      complaintData: complaintData,
                      complaintId: complaintId,
                    ),
                  ),
                );
              },
              child: const Text("View Details"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSOSDetails(BuildContext context, Map<String, dynamic> sosData, String sosId) async {
    // Get latitude and longitude for Google Maps
    double? lat = sosData['latitude'] as double?;
    double? lon = sosData['longitude'] as double?;
    String? userId = sosId;
    
    // Default values in case we can't fetch the user data
    String userName = "Unknown";
    String phoneNumber = "";
    
    // Fetch user data if we have a user ID
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          userName = userData['name'] ?? "Unknown";
          phoneNumber = userData['phone_no'] ?? "";
        }
      } catch (e) {
        print("Error fetching user data: $e");
      }

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emergency, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'EMERGENCY SOS ALERT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Add the person's name who triggered the alert
            Text(
              'From: $userName',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${sosData['location'] ?? 'Unknown'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Time: ${_formatTimestamp(sosData['timestamp'])}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Open Google Maps with the SOS location
                      if (lat != null && lon != null) {
                        _openMapsDirections(lat, lon);
                      } else {
                        _showError("Location coordinates not available");
                      }
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: phoneNumber.isEmpty 
                        ? null  // Disable the button if no phone number
                        : () {
                            Navigator.pop(context);
                            _makePhoneCall(phoneNumber);
                          },
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      // If phone number is empty, make button appear disabled
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    print("Original phone number: $phoneNumber"); // Debug original
    
    // Clean the phone number
    final String cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    print("Clean phone: $cleanPhone");
    
    try {
      // Try direct dialing first
      final Uri telUri = Uri(scheme: 'tel', path: cleanPhone);
      print("Attempting to launch: ${telUri.toString()}");
      
      if (await canLaunchUrl(telUri)) {
        print("Can launch - attempting to launch");
        await launchUrl(telUri);
      } else {
        print("Cannot launch tel URI - trying dial intent");
        // Try using the DIAL intent as fallback
        final Uri dialUri = Uri.parse('tel:$cleanPhone');
        if (await canLaunchUrl(dialUri)) {
          await launchUrl(dialUri, mode: LaunchMode.externalApplication);
        } else {
          _showError("Could not launch phone dialer. Device may not support this feature.");
        }
      }
    } catch (e) {
      print("Error launching phone dialer: $e");
      _showError("Error: ${e.toString()}");
    }
  }
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown time';
    try {
      DateTime dateTime;
        if (timestamp is String) {
          dateTime = DateTime.parse(timestamp);
        } else if (timestamp is int) {
          dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        } else {
          return 'Unknown time';
        }
        
        Duration difference = DateTime.now().difference(dateTime);
        
        if (difference.inMinutes < 1) {
          return 'Just now';
        } else if (difference.inMinutes < 60) {
          return '${difference.inMinutes} minutes ago';
        } else if (difference.inHours < 24) {
          return '${difference.inHours} hours ago';
        } else {
          return '${difference.inDays} days ago';
        }
      } catch (e) {
        return 'Unknown time';
      }
    }
}