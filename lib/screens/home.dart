import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:complaints_app/screens/navbar.dart';
import 'package:complaints_app/screens/open_complaint.dart';
import 'package:flutter/cupertino.dart';
import 'package:complaints_app/services/unpack_polyline.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  final FocusNode _searchFocusNode = FocusNode();
  
  // Routing variables
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  List<LatLng> _routePoints = [];
  bool _isRouteVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  void _searchLocation() async {
    try {
      String placeName = _searchController.text.trim();
      if (placeName.isEmpty) {
        _showError("Please enter a place name");
        return;
      }

      List<geo.Location> locations = await geo.locationFromAddress(placeName);
      if (locations.isNotEmpty) {
        geo.Location location = locations.first;
        LatLng destination = LatLng(location.latitude, location.longitude);
        
        setState(() {
          _destinationLocation = destination;
        });
        
        _mapController.move(destination, 14.0);
        
        // Get current location and draw route
        await _getCurrentLocationCoordinates();
        if (_currentLocation != null) {
          await _drawRoute();
        }
      } else {
        _showError("Location not found");
      }
    } catch (e) {
      _showError("Invalid place name");
    }
  }

  Future<void> _drawRoute() async {
    if (_currentLocation == null || _destinationLocation == null) return;

    try {
      // Build OSRM API URL
      String coordinates = "${_currentLocation!.longitude},${_currentLocation!.latitude};${_destinationLocation!.longitude},${_destinationLocation!.latitude}";
      String url = "http://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=polyline";
      
      // Make HTTP request
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final String encodedPolyline = data['routes'][0]['geometry'];
          final List<LatLng> routePoints = decodePolyline(encodedPolyline).unpackPolyline();
          
          setState(() {
            _routePoints = routePoints;
            _isRouteVisible = true;
          });

          // Fit the map to show the entire route
          if (routePoints.isNotEmpty) {
            _fitMapToRoute(routePoints);
          }
        } else {
          _showError("No route found");
        }
      } else {
        _showError("Failed to get route: HTTP ${response.statusCode}");
      }
    } catch (e) {
      _showError("Failed to get route: $e");
    }
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.map((p) => p.latitude).reduce(min);
    double maxLat = points.map((p) => p.latitude).reduce(max);
    double minLng = points.map((p) => p.longitude).reduce(min);
    double maxLng = points.map((p) => p.longitude).reduce(max);

    LatLng southwest = LatLng(minLat, minLng);
    LatLng northeast = LatLng(maxLat, maxLng);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(southwest, northeast),
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _routePoints.clear();
      _isRouteVisible = false;
      _destinationLocation = null;
    });
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

              // Add destination marker if available
              if (_destinationLocation != null) {
                markers.add(
                  Marker(
                    point: _destinationLocation!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.green,
                      size: 36,
                    ),
                  ),
                );
              }

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

              // Create polyline for route
              List<Polyline> polylines = [];
              if (_isRouteVisible && _routePoints.isNotEmpty) {
                polylines.add(
                  Polyline(
                    points: _routePoints,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                );
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
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),

          /// Search Bar
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
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isRouteVisible)
                        IconButton(
                          icon: Icon(Icons.clear, color: Colors.red),
                          onPressed: _clearRoute,
                        ),
                      IconButton(
                        icon: Icon(Icons.search, color: Colors.blue),
                        onPressed: _searchLocation,
                      ),
                    ],
                  ),
                ),
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
        // Clear focus from search field to dismiss keyboard
        _searchFocusNode.unfocus();
        Navigator.pop(context); 
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
  }