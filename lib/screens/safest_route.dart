import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:complaints_app/screens/navbar.dart';
import 'package:flutter/cupertino.dart';
import 'package:complaints_app/services/unpack_polyline.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class SafestRoutePage extends StatefulWidget {
  const SafestRoutePage({super.key});

  @override
  State<SafestRoutePage> createState() => _SafestRoutePageState();
}

class _SafestRoutePageState extends State<SafestRoutePage> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  final FocusNode _searchFocusNode = FocusNode();
  
  // Routing variables
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  List<LatLng> _bestRoutePoints = [];
  List<List<LatLng>> _alternativeRoutes = [];
  bool _isRouteVisible = false;
  bool _isLoading = false;
  List<LatLng> _newsMarkers = []; // Store news marker locations for safety calculation
  
  // Route metrics
  List<double> _routeDistances = [];
  List<double> _routeDurations = [];
  List<double> _routeSafetyScores = [];
  List<double> _routeOverallScores = [];
  int _bestRouteIndex = 0;

  // Constants
  static const double _earthRadius = 6371000; // Earth radius in meters
  static const double _safetyWeight = 0.6;
  static const double _distanceWeight = 0.4;
  static const int _maxRoutes = 5;

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
        _showMessage("Location services are disabled.", isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage("Location permission denied", isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage("Location permissions are permanently denied.", isError: true);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      _showMessage("Failed to get current location: ${e.toString()}", isError: true);
    }
  }

  Future<void> _searchLocation() async {
    final placeName = _searchController.text.trim();
    if (placeName.isEmpty) {
      _showMessage("Please enter a destination location", isError: true);
      return;
    }

    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final locations = await geo.locationFromAddress(placeName);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final destination = LatLng(location.latitude, location.longitude);
        
        setState(() {
          _destinationLocation = destination;
        });
        
        _mapController.move(destination, 14.0);
        
        // Get current location and draw best route
        await _getCurrentLocationCoordinates();
        if (_currentLocation != null) {
          await _drawBestRoute();
        }
      } else {
        _showMessage("Location not found", isError: true);
      }
    } catch (e) {
      _showMessage("Invalid place name: ${e.toString()}", isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Improved distance calculation using Haversine formula
  double _distancePointToLine(LatLng point, LatLng lineStart, LatLng lineEnd) {
    // Convert to radians
    final lat1 = point.latitude * pi / 180;
    final lon1 = point.longitude * pi / 180;
    final lat2 = lineStart.latitude * pi / 180;
    final lon2 = lineStart.longitude * pi / 180;
    final lat3 = lineEnd.latitude * pi / 180;
    final lon3 = lineEnd.longitude * pi / 180;
    
    // Calculate distances
    final dLon13 = lon1 - lon2;
    final dLat13 = lat1 - lat2;
    final dLon23 = lon3 - lon2;
    final dLat23 = lat3 - lat2;
    
    final a13 = 2 * asin(sqrt(sin(dLat13/2) * sin(dLat13/2) + 
                        cos(lat1) * cos(lat2) * sin(dLon13/2) * sin(dLon13/2)));
    final a23 = 2 * asin(sqrt(sin(dLat23/2) * sin(dLat23/2) + 
                        cos(lat2) * cos(lat3) * sin(dLon23/2) * sin(dLon23/2)));
    
    if (a23 == 0) return a13 * _earthRadius;
    
    final bearing12 = atan2(sin(dLon13) * cos(lat1), 
                           cos(lat2) * sin(lat1) - sin(lat2) * cos(lat1) * cos(dLon13));
    final bearing23 = atan2(sin(dLon23) * cos(lat3), 
                           cos(lat2) * sin(lat3) - sin(lat2) * cos(lat3) * cos(dLon23));
    
    final crossTrack = asin(sin(a13) * sin(bearing12 - bearing23));
    return crossTrack.abs() * _earthRadius;
  }

  // Improved safety calculation with better weighting
  double _calculateRouteSafety(List<LatLng> routePoints) {
    if (routePoints.isEmpty || _newsMarkers.isEmpty) return 1000.0;
    
    double totalSafety = 0.0;
    int segmentCount = 0;
    
    for (int i = 0; i < routePoints.length - 1; i++) {
      final segmentStart = routePoints[i];
      final segmentEnd = routePoints[i + 1];
      
      double minDistance = double.infinity;
      
      for (final newsMarker in _newsMarkers) {
        final distance = _distancePointToLine(newsMarker, segmentStart, segmentEnd);
        minDistance = min(minDistance, distance);
      }
      
      // Apply exponential decay for safety (closer = much less safe)
      final safetyScore = minDistance < 100 ? 0 : 
                         minDistance < 500 ? minDistance * 0.5 : 
                         minDistance;
      
      totalSafety += safetyScore;
      segmentCount++;
    }
    
    return segmentCount > 0 ? totalSafety / segmentCount : 1000.0;
  }

  // Improved overall score calculation
  double _calculateOverallScore(double safetyScore, double distance) {
    if (_routeDistances.isEmpty) return 0.0;
    
    final maxDistance = _routeDistances.reduce(max);
    final maxSafety = _routeSafetyScores.reduce(max);
    
    // Normalize scores (0-1)
    final normalizedSafety = maxSafety > 0 ? safetyScore / maxSafety : 0.0;
    final normalizedDistance = maxDistance > 0 ? 1.0 - (distance / maxDistance) : 1.0;
    
    // Weighted combination
    return (normalizedSafety * _safetyWeight) + (normalizedDistance * _distanceWeight);
  }

  // Improved route fetching with better error handling
  Future<List<List<LatLng>>> _getAlternativeRoutes() async {
    if (_currentLocation == null || _destinationLocation == null) return [];
    
    _clearRouteMetrics();
    final routes = <List<LatLng>>[];
    
    try {
      // Get OSRM routes
      await _fetchOSRMRoutes(routes);
      
      // Generate additional waypoint routes if needed
      if (routes.length < 3) {
        await _generateWaypointRoutes(routes);
      }
      
      // Calculate overall scores
      _calculateAllOverallScores(routes);
      
    } catch (e) {
      debugPrint("Error getting alternative routes: $e");
    }
    
    return routes;
  }

  void _clearRouteMetrics() {
    _routeDistances.clear();
    _routeDurations.clear();
    _routeSafetyScores.clear();
    _routeOverallScores.clear();
  }

  Future<void> _fetchOSRMRoutes(List<List<LatLng>> routes) async {
    final coordinates = "${_currentLocation!.longitude},${_currentLocation!.latitude};"
                       "${_destinationLocation!.longitude},${_destinationLocation!.latitude}";
    final url = "http://router.project-osrm.org/route/v1/driving/$coordinates"
               "?overview=full&geometries=polyline&alternatives=true";
    
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      
      if (data['code'] == 'Ok' && data['routes'] != null) {
        for (final route in data['routes'] as List) {
          _processRoute(route, routes);
        }
      }
    }
  }

  void _processRoute(Map<String, dynamic> route, List<List<LatLng>> routes) {
    final encodedPolyline = route['geometry'] as String?;
    final distance = (route['distance'] as num?)?.toDouble() ?? 0.0;
    final duration = (route['duration'] as num?)?.toDouble() ?? 0.0;
    
    if (encodedPolyline != null) {
      final routePoints = decodePolyline(encodedPolyline).unpackPolyline();
      if (routePoints.isNotEmpty) {
        routes.add(routePoints);
        _routeDistances.add(distance);
        _routeDurations.add(duration);
        
        final safetyScore = _calculateRouteSafety(routePoints);
        _routeSafetyScores.add(safetyScore);
      }
    }
  }

  // Optimized waypoint generation
  Future<void> _generateWaypointRoutes(List<List<LatLng>> existingRoutes) async {
    if (_currentLocation == null || _destinationLocation == null) return;
    
    final midLat = (_currentLocation!.latitude + _destinationLocation!.latitude) / 2;
    final midLng = (_currentLocation!.longitude + _destinationLocation!.longitude) / 2;
    
    // More strategic waypoint placement
    final waypoints = [
      LatLng(midLat + 0.008, midLng + 0.008), // Northeast
      LatLng(midLat - 0.008, midLng - 0.008), // Southwest
      LatLng(midLat + 0.008, midLng - 0.008), // Northwest
      LatLng(midLat - 0.008, midLng + 0.008), // Southeast
    ];
    
    for (final waypoint in waypoints) {
      if (existingRoutes.length >= _maxRoutes) break;
      
      await _fetchWaypointRoute(waypoint, existingRoutes);
    }
  }

  Future<void> _fetchWaypointRoute(LatLng waypoint, List<List<LatLng>> routes) async {
    try {
      final coordinates = "${_currentLocation!.longitude},${_currentLocation!.latitude};"
                         "${waypoint.longitude},${waypoint.latitude};"
                         "${_destinationLocation!.longitude},${_destinationLocation!.latitude}";
      final url = "http://router.project-osrm.org/route/v1/driving/$coordinates"
                 "?overview=full&geometries=polyline";
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        if (data['code'] == 'Ok' && data['routes'] != null) {
          final routeList = data['routes'] as List;
          if (routeList.isNotEmpty) {
            _processRoute(routeList[0] as Map<String, dynamic>, routes);
          }
        }
      }
    } catch (e) {
      debugPrint("Error generating waypoint route: $e");
    }
  }

  void _calculateAllOverallScores(List<List<LatLng>> routes) {
    for (int i = 0; i < routes.length; i++) {
      final overallScore = _calculateOverallScore(_routeSafetyScores[i], _routeDistances[i]);
      _routeOverallScores.add(overallScore);
    }
  }

  Future<void> _drawBestRoute() async {
    if (_currentLocation == null || _destinationLocation == null) return;

    try {
      _showMessage("Finding best route...", isError: false);
      
      final routes = await _getAlternativeRoutes();
      
      if (routes.isEmpty) {
        _showMessage("No routes found", isError: true);
        return;
      }
      
      // Find best route
      _bestRouteIndex = _findBestRouteIndex();
      
      // Separate best route from alternatives
      final alternativeRoutes = <List<LatLng>>[];
      for (int i = 0; i < routes.length; i++) {
        if (i != _bestRouteIndex) {
          alternativeRoutes.add(routes[i]);
        }
      }
      
      setState(() {
        _bestRoutePoints = routes[_bestRouteIndex];
        _alternativeRoutes = alternativeRoutes;
        _isRouteVisible = true;
      });

      if (_bestRoutePoints.isNotEmpty) {
        _fitMapToRoute(_bestRoutePoints);
      }
      
      _showMessage("Best route found (${routes.length} alternatives analyzed)", isError: false);
      
    } catch (e) {
      _showMessage("Failed to get best route: ${e.toString()}", isError: true);
    }
  }

  int _findBestRouteIndex() {
    int bestIndex = 0;
    double maxScore = _routeOverallScores[0];
    
    for (int i = 1; i < _routeOverallScores.length; i++) {
      if (_routeOverallScores[i] > maxScore) {
        maxScore = _routeOverallScores[i];
        bestIndex = i;
      }
    }
    
    return bestIndex;
  }

  // Improved formatting methods
  String _formatDistance(double meters) {
    return meters < 1000 
        ? "${meters.round()}m"
        : "${(meters / 1000).toStringAsFixed(1)}km";
  }

  String _formatDuration(double seconds) {
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    
    return hours > 0 ? "${hours}h ${minutes}m" : "${minutes}m";
  }

  String _formatScore(double score) {
    return "${(score * 100).toStringAsFixed(1)}%";
  }

  void _fitMapToRoute(List<LatLng> points) {
    if (points.isEmpty) return;

    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    
    final bounds = LatLngBounds(
      LatLng(lats.reduce(min), lngs.reduce(min)),
      LatLng(lats.reduce(max), lngs.reduce(max)),
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ),
    );
  }

  void _clearRoute() {
    setState(() {
      _bestRoutePoints.clear();
      _alternativeRoutes.clear();
      _isRouteVisible = false;
      _destinationLocation = null;
      _clearRouteMetrics();
      _bestRouteIndex = 0;
    });
    _searchController.clear();
  }

  Future<void> _getCurrentLocation() async {
    await _getCurrentLocationCoordinates();
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 14.0);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  // URL launching logic from NewsMapScreen
  Future<void> _launchNewsUrl(String? url) async {
    if (url == null || url.isEmpty) {
      _showMessage("No news article URL available", isError: true);
      return;
    }

    try {
      // Clean the URL - remove any extra whitespace
      String cleanUrl = url.trim();
      
      // Ensure URL has proper protocol
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      
      print("Attempting to launch URL: $cleanUrl"); // Debug log
      
      final Uri uri = Uri.parse(cleanUrl);
      
      // Try different launch modes
      if (await canLaunchUrl(uri)) {
        // Try external application first
        bool launched = await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
        );
        
        if (!launched) {
          // Fallback to platform default
          launched = await launchUrl(
            uri, 
            mode: LaunchMode.platformDefault,
          );
        }
        
        if (!launched) {
          // Final fallback to in-app web view
          await launchUrl(
            uri, 
            mode: LaunchMode.inAppWebView,
          );
        }
      } else {
        _showMessage("Cannot open this URL on your device", isError: true);
      }
    } catch (e) {
      print("URL Launch Error: $e"); // Debug log
      _showMessage("Error opening article: ${e.toString()}", isError: true);
    }
  }

  List<Marker> _buildMarkers(QuerySnapshot snapshot) {
    final markers = <Marker>[];
    final newsMarkers = <LatLng>[];

    // Add current location marker
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

    // Add destination marker
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

    // Add news markers WITHOUT offset
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = data['latitude'] as double?;
      final lon = data['longitude'] as double?;
      final title = data['issue_type'] ?? 'No issue type';
      final description = data['original_text'] ?? 'No description';
      final sourceUrl = data['source_url'] as String?;

      if (lat == null || lon == null) continue;

      final newsLocation = LatLng(lat, lon);
      newsMarkers.add(newsLocation);

      markers.add(
        Marker(
          point: newsLocation,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => _showNewsDetails(context, title, description, sourceUrl),
            child: const Icon(
              CupertinoIcons.exclamationmark_shield_fill,
              color: Color.fromARGB(255, 31, 134, 178),
              size: 36,
            ),
          ),
        ),
      );
    }

    // Update news markers for safety calculation
    _newsMarkers = newsMarkers;

    return markers;
  }

  List<Polyline> _buildPolylines() {
    if (!_isRouteVisible) return [];

    final polylines = <Polyline>[];

    // Add alternative routes first
    for (final route in _alternativeRoutes) {
      if (route.isNotEmpty) {
        polylines.add(
          Polyline(
            points: route,
            strokeWidth: 3.0,
            color: Colors.red.withOpacity(0.6),
          ),
        );
      }
    }

    // Add best route on top
    if (_bestRoutePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: _bestRoutePoints,
          strokeWidth: 5.0,
          color: Colors.green,
        ),
      );
    }

    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            "SAFEST ROUTE",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
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
      drawer: const NavBar(),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('news_markers').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No news markers available"));
              }

              final markers = _buildMarkers(snapshot.data!);
              final polylines = _buildPolylines();

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

          // Search Bar
          Positioned(
            top: 30,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: "Search for a destination...",
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isRouteVisible)
                        IconButton(
                          icon: const Icon(Icons.clear, color: Colors.red),
                          onPressed: _clearRoute,
                        ),
                      IconButton(
                        icon: _isLoading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search, color: Colors.blue),
                        onPressed: _isLoading ? null : _searchLocation,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Route Information Panel
          if (_isRouteVisible && _routeDistances.isNotEmpty)
            Positioned(
              top: 100,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
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
                        const SizedBox(width: 8),
                        const Text("Best Route", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_formatDistance(_routeDistances[_bestRouteIndex])} • ${_formatDuration(_routeDurations[_bestRouteIndex])}",
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                          Text(
                            "Score: ${_formatScore(_routeOverallScores[_bestRouteIndex])}",
                            style: TextStyle(fontSize: 10, color: Colors.green[700]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 4,
                          color: Colors.red.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        const Text("Alternative Routes", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Text(
                        "Based on safety + distance",
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Current Location Button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewsDetails(
    BuildContext context, 
    String title, 
    String description, 
    String? sourceUrl,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20.0),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient background
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.8),
                    Colors.deepOrange.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      CupertinoIcons.exclamationmark_shield_fill,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Description Section
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Description",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Close"),
                  ),
                ),
                if (sourceUrl != null && sourceUrl.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _launchNewsUrl(sourceUrl);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_new, size: 16),
                          SizedBox(width: 4),
                          Text("Read More"),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}