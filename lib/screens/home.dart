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
  List<LatLng> _safestRoutePoints = [];
  List<List<LatLng>> _alternativeRoutes = [];
  bool _isRouteVisible = false;
  List<LatLng> _complaintMarkers = []; // Store complaint locations for safety calculation
  
  // Route metrics
  List<double> _routeDistances = []; // Store distances for all routes
  List<double> _routeDurations = []; // Store durations for all routes
  int _safestRouteIndex = 0; // Track which route is safest

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
        
        // Get current location and draw safest route
        await _getCurrentLocationCoordinates();
        if (_currentLocation != null) {
          await _drawSafestRoute();
        }
      } else {
        _showError("Location not found");
      }
    } catch (e) {
      _showError("Invalid place name");
    }
  }

  // Calculate distance between a point and a line segment
  double _distancePointToLine(LatLng point, LatLng lineStart, LatLng lineEnd) {
    const double earthRadius = 6371000; // Earth radius in meters
    
    // Convert to radians
    double lat1 = point.latitude * pi / 180;
    double lon1 = point.longitude * pi / 180;
    double lat2 = lineStart.latitude * pi / 180;
    double lon2 = lineStart.longitude * pi / 180;
    double lat3 = lineEnd.latitude * pi / 180;
    double lon3 = lineEnd.longitude * pi / 180;
    
    // Calculate cross track distance (simplified version)
    double dLon13 = lon1 - lon2;
    double dLat13 = lat1 - lat2;
    double dLon23 = lon3 - lon2;
    double dLat23 = lat3 - lat2;
    
    double a13 = 2 * asin(sqrt(sin(dLat13/2) * sin(dLat13/2) + 
                        cos(lat1) * cos(lat2) * sin(dLon13/2) * sin(dLon13/2)));
    double a23 = 2 * asin(sqrt(sin(dLat23/2) * sin(dLat23/2) + 
                        cos(lat2) * cos(lat3) * sin(dLon23/2) * sin(dLon23/2)));
    
    if (a23 == 0) return a13 * earthRadius;
    
    double bearing12 = atan2(sin(dLon13) * cos(lat1), 
                           cos(lat2) * sin(lat1) - sin(lat2) * cos(lat1) * cos(dLon13));
    double bearing23 = atan2(sin(dLon23) * cos(lat3), 
                           cos(lat2) * sin(lat3) - sin(lat2) * cos(lat3) * cos(dLon23));
    
    double crossTrack = asin(sin(a13) * sin(bearing12 - bearing23));
    return crossTrack.abs() * earthRadius;
  }

  // Calculate safety score for a route (higher is safer)
  double _calculateRouteSafety(List<LatLng> routePoints) {
    if (routePoints.isEmpty || _complaintMarkers.isEmpty) return 1000.0; // Very safe if no complaints
    
    double totalMinDistance = 0.0;
    int segmentCount = 0;
    
    // Check each route segment against all complaint markers
    for (int i = 0; i < routePoints.length - 1; i++) {
      LatLng segmentStart = routePoints[i];
      LatLng segmentEnd = routePoints[i + 1];
      
      double minDistanceForSegment = double.infinity;
      
      // Find minimum distance from this segment to any complaint marker
      for (LatLng complaint in _complaintMarkers) {
        double distance = _distancePointToLine(complaint, segmentStart, segmentEnd);
        minDistanceForSegment = min(minDistanceForSegment, distance);
      }
      
      totalMinDistance += minDistanceForSegment;
      segmentCount++;
    }
    
    return segmentCount > 0 ? totalMinDistance / segmentCount : 1000.0;
  }

  // Get multiple route alternatives using different waypoints
  Future<List<List<LatLng>>> _getAlternativeRoutes() async {
    if (_currentLocation == null || _destinationLocation == null) return [];
    
    List<List<LatLng>> routes = [];
    _routeDistances.clear(); // Clear previous distances
    _routeDurations.clear(); // Clear previous durations
    
    try {
      // Route 1: Direct route
      String directCoordinates = "${_currentLocation!.longitude},${_currentLocation!.latitude};${_destinationLocation!.longitude},${_destinationLocation!.latitude}";
      String directUrl = "http://router.project-osrm.org/route/v1/driving/$directCoordinates?overview=full&geometries=polyline&alternatives=true";
      
      final directResponse = await http.get(Uri.parse(directUrl));
      
      if (directResponse.statusCode == 200) {
        final Map<String, dynamic> directData = json.decode(directResponse.body);
        
        if (directData['code'] == 'Ok' && directData['routes'].isNotEmpty) {
          // Add all alternative routes from OSRM
          for (var route in directData['routes']) {
            final String encodedPolyline = route['geometry'];
            final double distance = route['distance']?.toDouble() ?? 0.0; // in meters
            final double duration = route['duration']?.toDouble() ?? 0.0; // in seconds
            
            final List<LatLng> routePoints = decodePolyline(encodedPolyline).unpackPolyline();
            if (routePoints.isNotEmpty) {
              routes.add(routePoints);
              _routeDistances.add(distance);
              _routeDurations.add(duration);
            }
          }
        }
      }
      
      // Generate additional waypoint-based routes if we have less than 3 routes
      if (routes.length < 3) {
        await _generateWaypointRoutes(routes);
      }
      
    } catch (e) {
      print("Error getting alternative routes: $e");
    }
    
    return routes;
  }

  // Generate routes with intermediate waypoints for more alternatives
  Future<void> _generateWaypointRoutes(List<List<LatLng>> existingRoutes) async {
    if (_currentLocation == null || _destinationLocation == null) return;
    
    // Calculate midpoint and create offset waypoints
    double midLat = (_currentLocation!.latitude + _destinationLocation!.latitude) / 2;
    double midLng = (_currentLocation!.longitude + _destinationLocation!.longitude) / 2;
    
    List<LatLng> waypoints = [
      LatLng(midLat + 0.01, midLng + 0.01), // Offset northeast
      LatLng(midLat - 0.01, midLng - 0.01), // Offset southwest
      LatLng(midLat + 0.01, midLng - 0.01), // Offset northwest
      LatLng(midLat - 0.01, midLng + 0.01), // Offset southeast
    ];
    
    for (LatLng waypoint in waypoints) {
      if (existingRoutes.length >= 5) break; // Limit to 5 routes max
      
      try {
        String coordinates = "${_currentLocation!.longitude},${_currentLocation!.latitude};${waypoint.longitude},${waypoint.latitude};${_destinationLocation!.longitude},${_destinationLocation!.latitude}";
        String url = "http://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=polyline";
        
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          
          if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
            final String encodedPolyline = data['routes'][0]['geometry'];
            final double distance = data['routes'][0]['distance']?.toDouble() ?? 0.0;
            final double duration = data['routes'][0]['duration']?.toDouble() ?? 0.0;
            
            final List<LatLng> routePoints = decodePolyline(encodedPolyline).unpackPolyline();
            if (routePoints.isNotEmpty) {
              existingRoutes.add(routePoints);
              _routeDistances.add(distance);
              _routeDurations.add(duration);
            }
          }
        }
      } catch (e) {
        print("Error generating waypoint route: $e");
      }
    }
  }

  Future<void> _drawSafestRoute() async {
    if (_currentLocation == null || _destinationLocation == null) return;

    try {
      _showError("Finding safest route...");
      
      // Get multiple route alternatives
      List<List<LatLng>> routes = await _getAlternativeRoutes();
      
      if (routes.isEmpty) {
        _showError("No routes found");
        return;
      }
      
      // Calculate safety score for each route
      List<double> safetyScores = [];
      for (List<LatLng> route in routes) {
        double score = _calculateRouteSafety(route);
        safetyScores.add(score);
      }
      
      // Find the safest route (highest score)
      _safestRouteIndex = 0;
      double maxSafety = safetyScores[0];
      
      for (int i = 1; i < safetyScores.length; i++) {
        if (safetyScores[i] > maxSafety) {
          maxSafety = safetyScores[i];
          _safestRouteIndex = i;
        }
      }
      
      // Separate safest route from alternatives
      List<List<LatLng>> alternativeRoutes = [];
      for (int i = 0; i < routes.length; i++) {
        if (i != _safestRouteIndex) {
          alternativeRoutes.add(routes[i]);
        }
      }
      
      setState(() {
        _safestRoutePoints = routes[_safestRouteIndex];
        _alternativeRoutes = alternativeRoutes;
        _isRouteVisible = true;
      });

      // Fit the map to show the entire route
      if (_safestRoutePoints.isNotEmpty) {
        _fitMapToRoute(_safestRoutePoints);
      }
      
      _showError("Safest route selected (${routes.length} alternatives analyzed)");
      
    } catch (e) {
      _showError("Failed to get safest route: $e");
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return "${meters.round()}m";
    } else {
      return "${(meters / 1000).toStringAsFixed(1)}km";
    }
  }

  String _formatDuration(double seconds) {
    int hours = (seconds / 3600).floor();
    int minutes = ((seconds % 3600) / 60).floor();
    
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
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
      _safestRoutePoints.clear();
      _alternativeRoutes.clear();
      _isRouteVisible = false;
      _destinationLocation = null;
      _routeDistances.clear();
      _routeDurations.clear();
      _safestRouteIndex = 0;
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
              
              // Clear and rebuild complaint markers list
              _complaintMarkers.clear();

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

                LatLng complaintLocation = LatLng(newLat, newLon);
                _complaintMarkers.add(complaintLocation); // Store for safety calculation

                markers.add(
                  Marker(
                    point: complaintLocation,
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

              // Create polylines for routes
              List<Polyline> polylines = [];
              
              if (_isRouteVisible) {
                // Draw alternative routes first (so they appear behind the safest route)
                for (int i = 0; i < _alternativeRoutes.length; i++) {
                  if (_alternativeRoutes[i].isNotEmpty) {
                    polylines.add(
                      Polyline(
                        points: _alternativeRoutes[i],
                        strokeWidth: 3.0,
                        color: Colors.red.withOpacity(0.6), // Semi-transparent red for unsafe routes
                      ),
                    );
                  }
                }
                
                // Draw safest route on top
                if (_safestRoutePoints.isNotEmpty) {
                  polylines.add(
                    Polyline(
                      points: _safestRoutePoints,
                      strokeWidth: 5.0,
                      color: Colors.green, // Bold green for safest route
                    ),
                  );
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

          /// Route Legend with Distance/Duration
          if (_isRouteVisible && _routeDistances.isNotEmpty)
            Positioned(
              top: 100,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 4,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8),
                        Text("Safest Route", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.only(left: 28),
                      child: Text(
                        "${_formatDistance(_routeDistances[_safestRouteIndex])} • ${_formatDuration(_routeDurations[_safestRouteIndex])}",
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 4,
                          color: Colors.red.withOpacity(0.6),
                        ),
                        SizedBox(width: 8),
                        Text("Alternative Routes", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
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

          // Only show options when routes are NOT visible
          if (!_isRouteVisible)
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