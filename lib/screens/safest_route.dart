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
  final TextEditingController _destSearchController =
      TextEditingController(); // Renamed from _searchController
  final TextEditingController _sourceSearchController =
      TextEditingController(); // New controller for source
  final MapController _mapController = MapController();
  final FocusNode _destFocusNode = FocusNode(); // Renamed from _searchFocusNode
  final FocusNode _sourceFocusNode = FocusNode();

  // Routing variables
  LatLng? _currentLocation;
  LatLng? _sourceLocation;
  bool _showSourceField = false;
  bool _useCurrentLocationAsSource = true;
  LatLng? _destinationLocation;
  List<LatLng> _bestRoutePoints = [];
  List<List<LatLng>> _alternativeRoutes = [];
  bool _isRouteVisible = false;
  bool _isLoading = false;
  List<LatLng> _newsMarkers =
      []; // Store news marker locations for safety calculation

  // Marker visibility toggles
  bool _showNews = true;
  bool _showNGOs = false;
  bool _showPoliceStations = false;

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
    _destSearchController.dispose();
    _sourceSearchController.dispose();
    _destFocusNode.dispose();
    _sourceFocusNode.dispose();
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
        _showMessage(
          "Location permissions are permanently denied.",
          isError: true,
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      _showMessage(
        "Failed to get current location: ${e.toString()}",
        isError: true,
      );
    }
  }

  Future<void> _searchSourceLocation() async {
    final placeName = _sourceSearchController.text.trim();
    if (placeName.isEmpty) {
      _showMessage("Please enter a source location", isError: true);
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
        final source = LatLng(location.latitude, location.longitude);

        setState(() {
          _sourceLocation = source;
          _useCurrentLocationAsSource = false;
        });

        _mapController.move(source, 14.0);

        // If destination is already set, recalculate route
        if (_destinationLocation != null) {
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

  Future<void> _searchDestinationLocation() async {
    final placeName = _destSearchController.text.trim();
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
        setState(() {
          _destinationLocation = LatLng(location.latitude, location.longitude);
          _isRouteVisible = false; // Ensure route is not shown yet
        });
        _mapController.move(_destinationLocation!, 14.0);
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

    final a13 =
        2 *
        asin(
          sqrt(
            sin(dLat13 / 2) * sin(dLat13 / 2) +
                cos(lat1) * cos(lat2) * sin(dLon13 / 2) * sin(dLon13 / 2),
          ),
        );
    final a23 =
        2 *
        asin(
          sqrt(
            sin(dLat23 / 2) * sin(dLat23 / 2) +
                cos(lat2) * cos(lat3) * sin(dLon23 / 2) * sin(dLon23 / 2),
          ),
        );

    if (a23 == 0) return a13 * _earthRadius;

    final bearing12 = atan2(
      sin(dLon13) * cos(lat1),
      cos(lat2) * sin(lat1) - sin(lat2) * cos(lat1) * cos(dLon13),
    );
    final bearing23 = atan2(
      sin(dLon23) * cos(lat3),
      cos(lat2) * sin(lat3) - sin(lat2) * cos(lat3) * cos(dLon23),
    );

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
        final distance = _distancePointToLine(
          newsMarker,
          segmentStart,
          segmentEnd,
        );
        minDistance = min(minDistance, distance);
      }

      // Apply exponential decay for safety (closer = much less safe)
      final safetyScore =
          minDistance < 100
              ? 0
              : minDistance < 500
              ? minDistance * 0.5
              : minDistance;

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
    final normalizedDistance =
        maxDistance > 0 ? 1.0 - (distance / maxDistance) : 1.0;

    // Weighted combination
    return (normalizedSafety * _safetyWeight) +
        (normalizedDistance * _distanceWeight);
  }

  // Improved route fetching with better error handling
  Future<List<List<LatLng>>> _getAlternativeRoutes(
    LatLng sourceLocation,
  ) async {
    if (sourceLocation == null || _destinationLocation == null) return [];

    _clearRouteMetrics();
    final routes = <List<LatLng>>[];

    try {
      // Get OSRM routes
      await _fetchOSRMRoutes(routes, sourceLocation);
      // Generate additional waypoint routes if needed
      if (routes.length < 3) {
        await _generateWaypointRoutes(routes, sourceLocation);
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

  Future<void> _fetchOSRMRoutes(
    List<List<LatLng>> routes,
    LatLng sourceLocation,
  ) async {
    final coordinates =
        "${sourceLocation.longitude},${sourceLocation.latitude};"
        "${_destinationLocation!.longitude},${_destinationLocation!.latitude}";
    final url =
        "http://router.project-osrm.org/route/v1/driving/$coordinates"
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
  Future<void> _generateWaypointRoutes(
    List<List<LatLng>> existingRoutes,
    LatLng sourceLocation,
  ) async {
    if (sourceLocation == null || _destinationLocation == null) return;

    final midLat =
        (sourceLocation.latitude + _destinationLocation!.latitude) / 2;
    final midLng =
        (sourceLocation.longitude + _destinationLocation!.longitude) / 2;
    // More strategic waypoint placement
    final waypoints = [
      LatLng(midLat + 0.008, midLng + 0.008), // Northeast
      LatLng(midLat - 0.008, midLng - 0.008), // Southwest
      LatLng(midLat + 0.008, midLng - 0.008), // Northwest
      LatLng(midLat - 0.008, midLng + 0.008), // Southeast
    ];

    for (final waypoint in waypoints) {
      if (existingRoutes.length >= _maxRoutes) break;

      await _fetchWaypointRoute(waypoint, existingRoutes, sourceLocation);
    }
  }

  Future<void> _fetchWaypointRoute(
    LatLng waypoint,
    List<List<LatLng>> routes,
    LatLng sourceLocation,
  ) async {
    try {
      final coordinates =
          "${sourceLocation.longitude},${sourceLocation.latitude};"
          "${waypoint.longitude},${waypoint.latitude};"
          "${_destinationLocation!.longitude},${_destinationLocation!.latitude}";
      final url =
          "http://router.project-osrm.org/route/v1/driving/$coordinates"
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
      final overallScore = _calculateOverallScore(
        _routeSafetyScores[i],
        _routeDistances[i],
      );
      _routeOverallScores.add(overallScore);
    }
  }

  Future<void> _drawBestRoute() async {
    // Get the correct source location
    LatLng? sourceLocation =
        _useCurrentLocationAsSource ? _currentLocation : _sourceLocation;
    if (sourceLocation == null || _destinationLocation == null) return;

    try {
      _showMessage("Finding best route...", isError: false);

      final routes = await _getAlternativeRoutes(sourceLocation);

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

      _showMessage(
        "Best route found (${routes.length} alternatives analyzed)",
        isError: false,
      );
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
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  void _clearRoute() {
    setState(() {
      _bestRoutePoints = [];
      _alternativeRoutes = [];
      _isRouteVisible = false;
      _destinationLocation = null;
      _routeDistances.clear();
      _routeDurations.clear();
      _routeSafetyScores.clear();
      _routeOverallScores.clear();
      _bestRouteIndex = 0;
    });
    _destSearchController.clear(); // Clear destination search field
  }

  Future<void> _getCurrentLocation() async {
    await _getCurrentLocationCoordinates();
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 14.0);
      setState(() {
        _useCurrentLocationAsSource = true;
        _sourceSearchController.clear(); // Clear the source search field
      });

      // If destination is set, recalculate route
      if (_destinationLocation != null) {
        await _drawBestRoute();
      }
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
          launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        }

        if (!launched) {
          // Final fallback to in-app web view
          await launchUrl(uri, mode: LaunchMode.inAppWebView);
        }
      } else {
        _showMessage("Cannot open this URL on your device", isError: true);
      }
    } catch (e) {
      print("URL Launch Error: $e"); // Debug log
      _showMessage("Error opening article: ${e.toString()}", isError: true);
    }
  }

  Stream<List<QuerySnapshot>> _combineStreams() {
    return Stream.periodic(const Duration(seconds: 1), (count) async {
      final news =
          await FirebaseFirestore.instance.collection('news_markers').get();
      final ngos = await FirebaseFirestore.instance.collection('ngos').get();
      final police =
          await FirebaseFirestore.instance.collection('police_stations').get();
      return [news, ngos, police];
    }).asyncMap((future) => future);
  }

  List<Marker> _buildMarkers(
    QuerySnapshot newsSnapshot,
    QuerySnapshot ngosSnapshot,
    QuerySnapshot policeSnapshot,
  ) {
    final markers = <Marker>[];
    final newsMarkers = <LatLng>[];

    // Add current location marker if using it as source
    if (_useCurrentLocationAsSource && _currentLocation != null) {
      markers.add(
        Marker(
          point: _currentLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.my_location, color: Colors.blue, size: 36),
        ),
      );
    }

    // Add custom source location marker if set
    if (!_useCurrentLocationAsSource && _sourceLocation != null) {
      markers.add(
        Marker(
          point: _sourceLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.trip_origin, color: Colors.blue, size: 36),
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
          child: const Icon(Icons.location_on, color: Colors.green, size: 36),
        ),
      );
    }

    // Add news markers
    if (_showNews) {
      for (final doc in newsSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final lat = data['latitude'] as double?;
          final lon = data['longitude'] as double?;
          final title = data['issue_type']?.toString() ?? 'No issue type';
          final description =
              data['original_text']?.toString() ?? 'No description';
          final sourceUrl = data['source_url']?.toString();

          if (lat == null || lon == null) continue;

          final newsLocation = LatLng(lat, lon);
          newsMarkers.add(newsLocation);

          markers.add(
            Marker(
              point: newsLocation,
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap:
                    () => _showNewsDetails(
                      context,
                      title,
                      description,
                      sourceUrl,
                    ),
                child: const Icon(
                  CupertinoIcons.exclamationmark_shield_fill,
                  color: Color.fromARGB(255, 31, 134, 178),
                  size: 36,
                ),
              ),
            ),
          );
        } catch (e) {
          print("Error processing news marker: $e");
          continue;
        }
      }
    }

    // Add NGO markers
    if (_showNGOs) {
      for (final doc in ngosSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

          // Handle location field safely
          final locationData = data['location'];
          if (locationData == null) continue;

          double? lat, lon;

          if (locationData is Map<String, dynamic>) {
            lat = locationData['latitude'] as double?;
            lon = locationData['longitude'] as double?;
          }

          if (lat == null || lon == null) continue;

          final name = data['name']?.toString() ?? 'Unknown NGO';

          // Handle sectors array safely
          List<String>? sectors;
          final sectorsData = data['sectors'];
          if (sectorsData is List) {
            sectors = sectorsData.map((e) => e.toString()).toList();
          }

          final ngoLocation = LatLng(lat, lon);

          markers.add(
            Marker(
              point: ngoLocation,
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showNGODetails(context, name, sectors),
                child: const Icon(
                  Icons.volunteer_activism,
                  color: Colors.orange,
                  size: 36,
                ),
              ),
            ),
          );
        } catch (e) {
          print("Error processing NGO marker: $e");
          continue;
        }
      }
    }

    // Add Police Station markers
    if (_showPoliceStations) {
      for (final doc in policeSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final lat = data['latitude'] as double?;
          final lon = data['longitude'] as double?;
          final name = data['name']?.toString() ?? 'Police Station';

          if (lat == null || lon == null) continue;

          final policeLocation = LatLng(lat, lon);

          markers.add(
            Marker(
              point: policeLocation,
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => _showPoliceStationDetails(context, name),
                child: const Icon(
                  Icons.local_police,
                  color: Colors.red,
                  size: 36,
                ),
              ),
            ),
          );
        } catch (e) {
          print("Error processing police marker: $e");
          continue;
        }
      }
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

  Widget _buildMarkerToggle(
    String label,
    IconData icon,
    Color color,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 4),
        Switch(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  void _showNGODetails(
    BuildContext context,
    String name,
    List<String>? sectors,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.volunteer_activism,
                color: Colors.purple,
                size: 40,
              ),
              const SizedBox(height: 10),
              const Text(
                'NGO Services:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 5),
              if (sectors != null && sectors.isNotEmpty)
                ...sectors.map(
                  (sector) => Padding(
                    padding: const EdgeInsets.only(left: 10, top: 2),
                    child: Text(
                      '• $sector',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(left: 10),
                  child: Text(
                    '• General services',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
            ],
          ),
          actions: [
            // Get Directions Button
            if (!_isRouteVisible)
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();

                  try {
                    final ngoSnapshot =
                        await FirebaseFirestore.instance
                            .collection('ngos')
                            .where('name', isEqualTo: name)
                            .get();

                    if (ngoSnapshot.docs.isNotEmpty) {
                      final doc = ngoSnapshot.docs.first;
                      final data = doc.data();

                      // Extract latitude and longitude as separate fields
                      final latitude =
                          data['location']?['latitude']?.toDouble();
                      final longitude =
                          data['location']?['longitude']?.toDouble();

                      if (latitude != null && longitude != null) {
                        // Set as destination
                        setState(() {
                          _destinationLocation = LatLng(latitude, longitude);
                        });

                        _destSearchController.text = name;

                        if (_useCurrentLocationAsSource &&
                            _currentLocation == null) {
                          await _getCurrentLocationCoordinates();
                        }

                        if ((_useCurrentLocationAsSource &&
                                _currentLocation != null) ||
                            (!_useCurrentLocationAsSource &&
                                _sourceLocation != null)) {
                          await _drawBestRoute();
                        } else {
                          _showMessage(
                            "Please set your location first",
                            isError: true,
                          );
                        }
                      } else {
                        _showMessage(
                          "Location data not available",
                          isError: true,
                        );
                      }
                    } else {
                      _showMessage("NGO not found", isError: true);
                    }
                  } catch (e) {
                    _showMessage(
                      "Error getting directions: ${e.toString()}",
                      isError: true,
                    );
                  }
                },
                icon: const Icon(Icons.directions, color: Colors.green),
                label: const Text(
                  'Get Directions',
                  style: TextStyle(color: Colors.green),
                ),
              ),

            // Clear Route Button (if route is visible)
            if (_isRouteVisible)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearRoute();
                },
                icon: const Icon(Icons.clear, color: Colors.red),
                label: const Text(
                  'Clear Route',
                  style: TextStyle(color: Colors.red),
                ),
              ),

            // Close Button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showPoliceStationDetails(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.local_police, color: Colors.blue, size: 40),
              SizedBox(height: 10),
              Text(
                'Police Station',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            // Get Directions Button
            if (!_isRouteVisible)
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();

                  try {
                    final policeSnapshot =
                        await FirebaseFirestore.instance
                            .collection('police_stations')
                            .where('name', isEqualTo: name)
                            .get();

                    if (policeSnapshot.docs.isNotEmpty) {
                      final doc = policeSnapshot.docs.first;
                      final data = doc.data();

                      // Police stations have direct latitude/longitude fields
                      final latitude = data['latitude']?.toDouble();
                      final longitude = data['longitude']?.toDouble();

                      if (latitude != null && longitude != null) {
                        // Set as destination
                        setState(() {
                          _destinationLocation = LatLng(latitude, longitude);
                        });

                        _destSearchController.text = name;

                        if (_useCurrentLocationAsSource &&
                            _currentLocation == null) {
                          await _getCurrentLocationCoordinates();
                        }

                        if ((_useCurrentLocationAsSource &&
                                _currentLocation != null) ||
                            (!_useCurrentLocationAsSource &&
                                _sourceLocation != null)) {
                          await _drawBestRoute();
                        } else {
                          _showMessage(
                            "Please set your location first",
                            isError: true,
                          );
                        }
                      } else {
                        _showMessage(
                          "Location data not available",
                          isError: true,
                        );
                      }
                    } else {
                      _showMessage("Police station not found", isError: true);
                    }
                  } catch (e) {
                    _showMessage(
                      "Error getting directions: ${e.toString()}",
                      isError: true,
                    );
                  }
                },
                icon: const Icon(Icons.directions, color: Colors.green),
                label: const Text(
                  'Get Directions',
                  style: TextStyle(color: Colors.green),
                ),
              ),

            // Clear Route Button (if route is visible)
            if (_isRouteVisible)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _clearRoute();
                },
                icon: const Icon(Icons.clear, color: Colors.red),
                label: const Text(
                  'Clear Route',
                  style: TextStyle(color: Colors.red),
                ),
              ),

            // Close Button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMapsDirections(
    double sourceLat,
    double sourceLng,
    double destLat,
    double destLng,
  ) async {
    final url =
        "https://www.google.com/maps/dir/?api=1&origin=$sourceLat,$sourceLng&destination=$destLat,$destLng";
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showMessage("Could not open maps application", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color sororiaPink = const Color(0xFFE91E63);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          iconTheme: IconThemeData(color: sororiaPink),
          title: const Text(
            "SAFEST ROUTE",
            style: TextStyle(
              color: Color(0xFFE91E63),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
      drawer: const NavBar(),
      body: Stack(
        children: [
          // Map Layer
          StreamBuilder<List<QuerySnapshot>>(
            stream: _combineStreams(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.length < 3) {
                return const Center(child: Text("Loading map data..."));
              }

              final newsSnapshot = snapshot.data![0];
              final ngosSnapshot = snapshot.data![1];
              final policeSnapshot = snapshot.data![2];

              final markers = _buildMarkers(
                newsSnapshot,
                ngosSnapshot,
                policeSnapshot,
              );
              final polylines = _buildPolylines();

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
                  if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),

          // Search Bars
          Positioned(
            top: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Source Location Search Bar (visible only when showing directions)
                if (_showSourceField || _isRouteVisible)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 5),
                      ],
                    ),
                    child: TextField(
                      controller: _sourceSearchController,
                      focusNode: _sourceFocusNode,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText:
                            _useCurrentLocationAsSource
                                ? "Current Location (tap to change)"
                                : "Source Location",
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                        prefixIcon: Icon(
                          Icons.trip_origin,
                          color: sororiaPink,
                          size: 20,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_useCurrentLocationAsSource)
                              IconButton(
                                icon: const Icon(
                                  Icons.my_location,
                                  color: Color(0xFFE91E63),
                                ),
                                onPressed: _getCurrentLocation,
                                tooltip: "Use current location",
                              ),
                            IconButton(
                              icon:
                                  _isLoading
                                      ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(Icons.search, color: sororiaPink),
                              onPressed:
                                  _isLoading ? null : _searchSourceLocation,
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        if (_useCurrentLocationAsSource) {
                          setState(() {
                            _useCurrentLocationAsSource = false;
                          });
                        }
                      },
                    ),
                  ),

                // Destination Location Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 5),
                    ],
                  ),
                  child: TextField(
                    controller: _destSearchController,
                    focusNode: _destFocusNode,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: "Search for a destination...",
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 20,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isRouteVisible)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: _clearRoute,
                            ),
                          IconButton(
                            icon:
                                _isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Icon(Icons.search, color: sororiaPink),
                            onPressed:
                                _isLoading ? null : _searchDestinationLocation,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Route Information Panel
          if (_isRouteVisible && _routeDistances.isNotEmpty)
            Positioned(
              top: _showSourceField || _isRouteVisible ? 150 : 100,
              right: 20,
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF7F7F9),
                      Color(0xFFE3F0FF),
                      Color(0xFFD0E6FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 20, height: 4, color: Colors.green),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            "Best Route",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_formatDistance(_routeDistances[_bestRouteIndex])} • ${_formatDuration(_routeDurations[_bestRouteIndex])}",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            "Score: ${_formatScore(_routeOverallScores[_bestRouteIndex])}",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green[700],
                            ),
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
                        const Flexible(
                          child: Text(
                            "Alternative Routes",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
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
          Stack(
            children: [
              // Your map widget here

              // Floating Action Buttons
              Positioned(
                bottom:
                    (_destinationLocation != null && !_isRouteVisible)
                        ? 80
                        : 20,
                left: 20,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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

              // Show DIRECTIONS button
              if (_destinationLocation != null && !_isRouteVisible)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // This is where you add the step 2 code:
                      if (_destinationLocation == null) {
                        _showMessage(
                          "Please set a destination first",
                          isError: true,
                        );
                        return;
                      }

                      if (_useCurrentLocationAsSource &&
                          _currentLocation == null) {
                        await _getCurrentLocationCoordinates();
                      }

                      if ((_useCurrentLocationAsSource &&
                              _currentLocation != null) ||
                          (!_useCurrentLocationAsSource &&
                              _sourceLocation != null)) {
                        await _drawBestRoute();
                      } else {
                        _showMessage(
                          "Please set your location first",
                          isError: true,
                        );
                      }
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text("DIRECTIONS"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sororiaPink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

              // Show OPEN IN MAPS button
              if (_isRouteVisible)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      // Floating location button
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
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

                      const SizedBox(width: 16),

                      // Expanded "OPEN IN MAPS" or "DIRECTIONS" button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            LatLng sourceLocation =
                                _useCurrentLocationAsSource
                                    ? _currentLocation!
                                    : _sourceLocation!;
                            if (sourceLocation != null &&
                                _destinationLocation != null) {
                              _openMapsDirections(
                                sourceLocation.latitude,
                                sourceLocation.longitude,
                                _destinationLocation!.latitude,
                                _destinationLocation!.longitude,
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new, size: 24),
                          label: const Text(
                            "OPEN IN MAPS",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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
      builder:
          (context) => Container(
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

Widget _buildMarkerButton({
  required IconData icon,
  required String label,
  required bool isActive,
  required Color activeColor,
  required VoidCallback onPressed,
}) {
  return Material(
    color:
        isActive ? activeColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? activeColor : Colors.grey, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? activeColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
