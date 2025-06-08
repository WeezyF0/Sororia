import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:complaints_app/screens/navbar.dart';
import 'package:complaints_app/screens/open_complaint.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geocoding/geocoding.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _searchLocation() async {
    try {
      String placeName = _searchController.text.trim();
      if (placeName.isEmpty) {
        _showError("Please enter a place name");
        return;
      }

      List<Location> locations = await locationFromAddress(placeName);
      if (locations.isNotEmpty) {
        Location location = locations.first;
        _mapController.move(LatLng(location.latitude, location.longitude), 14.0);
      } else {
        _showError("Location not found");
      }
    } catch (e) {
      _showError("Invalid place name");
    }
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
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 14.0);
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
              List<Marker> markers = [];
              
              // Add current location marker if available
              if (_currentLocation != null) {
                markers.add(
                  Marker(
                    point: _currentLocation!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 36,
                    ),
                  ),
                );
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

                markers.add(
                  Marker(
                    point: LatLng(newLat, newLon),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => showComplaintDetails(
                        context, 
                        title, 
                        description,
                        data,
                        doc.id,
                      ),
                      child: const Icon(
                        Icons.place_rounded,
                        color: Colors.red,
                        size: 36,
                      ),
                    ),
                  ),
                );
              }

              // Add SOS markers using StreamBuilder data
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('sos').snapshots(),
                builder: (context, sosSnapshot) {
                  // Add SOS markers to the existing markers list
                  if (sosSnapshot.hasData) {
                    String? currentUid = FirebaseAuth.instance.currentUser?.uid;
                    if (currentUid != null) {
                      for (var doc in sosSnapshot.data!.docs) {
                        var data = doc.data() as Map<String, dynamic>;
                        
                        bool isActive = data['active'] == true;
                        List<dynamic> relatedUsers = data['related_users'] ?? [];
                        bool isUserRelated = relatedUsers.contains(currentUid);
                        
                        if (!isActive || !isUserRelated) continue;
                        
                        double? lat = data['latitude'] as double?;
                        double? lon = data['longitude'] as double?;
                        
                        if (lat == null || lon == null) continue;
                        
                        LatLng sosLocation = LatLng(lat, lon);
                        
                        markers.add(
                          Marker(
                            point: sosLocation,
                            width: 50,
                            height: 50,
                            child: GestureDetector(
                              onTap: () => _showSOSDetails(context, data, doc.id),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.6),
                                      spreadRadius: 3,
                                      blurRadius: 7,
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.emergency,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  }

                  return FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: markers.isNotEmpty
                          ? markers.first.point
                          : const LatLng(20.5937, 78.9629),
                      initialZoom: 10,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://www.google.com/maps/vt?lyrs=m@221097413,traffic&x={x}&y={y}&z={z}',
                        userAgentPackageName: 'com.complaints.app',
                      ),
                      MarkerLayer(markers: markers), // Single MarkerLayer with all markers
                    ],
                  );
                },
              );
            },
          ),

          // Add search bar
          Positioned(
            top: 30,
            left: 20,
            right: 20,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: "Search for a location...",
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: Colors.blue),
                    onPressed: _searchLocation,
                  ),
                ),
                onSubmitted: (_) => _searchLocation(),
              ),
            ),
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

  void _showSOSDetails(BuildContext context, Map<String, dynamic> sosData, String sosId) {
    // Get latitude and longitude for Google Maps
    double? lat = sosData['latitude'] as double?;
    double? lon = sosData['longitude'] as double?;

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
                    onPressed: () {
                      Navigator.pop(context);
                      // Add call functionality
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
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