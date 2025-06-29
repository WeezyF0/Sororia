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
// Remove geocoding import

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  LatLng? _currentLocation;

  // Sororia pink color from logo
  final Color sororiaPink = const Color(0xFFE91E63);

  @override
  void dispose() {
    super.dispose();
  }

  // Remove _searchLocation() method

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          iconTheme: IconThemeData(color: sororiaPink),
          title: Text(
            "SORORIA",
            style: TextStyle(
              color: sororiaPink,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
      drawer: NavBar(),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('complaints').snapshots(),
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
                      onTap:
                          () => showComplaintDetails(
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
                stream:
                    FirebaseFirestore.instance.collection('sos').snapshots(),
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

                      LatLng sosLocation = LatLng(lat, lon);

                      // Create a FutureBuilder marker that will load the name
                      markers.add(
                        Marker(
                          point: sosLocation,
                          width: 50,
                          height: 75, // Increased height to accommodate name
                          child: GestureDetector(
                            onTap: () => _showSOSDetails(context, data, doc.id),
                            child: Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
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
                                    size: 28,
                                  ),
                                ),
                                FutureBuilder<DocumentSnapshot>(
                                  future:
                                      FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(userId)
                                          .get(),
                                  builder: (context, userSnapshot) {
                                    String name = "SOS";
                                    if (userSnapshot.hasData &&
                                        userSnapshot.data!.exists) {
                                      try {
                                        final userData =
                                            userSnapshot.data!.data()
                                                as Map<String, dynamic>;
                                        print(
                                          "Marker userData for $userId: $userData",
                                        ); // Debug log
                                        name = userData['name'] ?? "SOS";
                                        // Only show first name if full name is long
                                        if (name.contains(" ") &&
                                            name.length > 8) {
                                          name = name.split(" ")[0];
                                        }
                                      } catch (e) {
                                        print(
                                          "Error extracting user data for marker: $e",
                                        );
                                      }
                                    }

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(top: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  }

                  return FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          markers.isNotEmpty
                              ? markers.first.point
                              : const LatLng(20.5937, 78.9629),
                      initialZoom: 10,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://www.google.com/maps/vt?lyrs=m@221097413,traffic&x={x}&y={y}&z={z}',
                        userAgentPackageName: 'com.complaints.app',
                      ),
                      MarkerLayer(
                        markers: markers,
                      ), // Single MarkerLayer with all markers
                    ],
                  );
                },
              );
            },
          ),

          // Remove search bar Positioned widget

          /// Current Location Button
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _getCurrentLocation,
                backgroundColor: Colors.white,
                child: Icon(Icons.my_location, color: sororiaPink),
                elevation: 0,
              ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7F7F9), Color(0xFFE3F0FF), Color(0xFFD0E6FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOptionTile(
            context,
            "View Experiences",
            CupertinoIcons.doc_text_search,
            sororiaPink,
            '/complaints',
          ),
          Divider(height: 1, color: Colors.grey.withOpacity(0.12)),
          _buildOptionTile(
            context,
            "View Active Petitions",
            CupertinoIcons.collections,
            sororiaPink,
            '/petitions',
          ),
          Divider(height: 1, color: Colors.grey.withOpacity(0.12)),
          _buildOptionTile(
            context,
            "Local News",
            Icons.newspaper_outlined,
            sororiaPink,
            '/news',
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String route,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pushNamed(route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: color.withOpacity(0.4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: sororiaPink,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => OpenComplaintScreen(
                                complaintData: complaintData,
                                complaintId: complaintId,
                              ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sororiaPink,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      "View Details",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showSOSDetails(
    BuildContext context,
    Map<String, dynamic> sosData,
    String sosId,
  ) async {
    double? lat = sosData['latitude'] as double?;
    double? lon = sosData['longitude'] as double?;
    String? userId = sosId;

    String userName = "Unknown";
    String phoneNumber = "";

    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emergency, color: Colors.orange, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'EMERGENCY SOS ALERT',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  'From: $userName',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Location: ${sosData['location'] ?? 'Unknown'}',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                SizedBox(height: 8),
                Text(
                  'Time: ${_formatTimestamp(sosData['timestamp'])}',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          if (lat != null && lon != null) {
                            _openMapsDirections(lat, lon);
                          } else {
                            _showError("Location coordinates not available");
                          }
                        },
                        icon: Icon(Icons.directions),
                        label: Text('Get Directions'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sororiaPink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            phoneNumber.isEmpty
                                ? null
                                : () {
                                  Navigator.pop(context);
                                  _makePhoneCall(phoneNumber);
                                },
                        icon: Icon(Icons.phone),
                        label: Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey.shade300,
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
          _showError(
            "Could not launch phone dialer. Device may not support this feature.",
          );
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
