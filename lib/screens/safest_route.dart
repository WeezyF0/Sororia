import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'package:complaints_app/screens/navbar.dart';
import 'package:flutter/cupertino.dart';
import 'package:complaints_app/services/google_directions_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart'
    hide TravelMode;
import 'package:complaints_app/models/travel_mode.dart';
import 'dart:async';

class SafestRoutePage extends StatefulWidget {
  const SafestRoutePage({super.key});

  @override
  State<SafestRoutePage> createState() => _SafestRoutePageState();
}

class _SafestRoutePageState extends State<SafestRoutePage> {
  final TextEditingController _destSearchController = TextEditingController();
  final TextEditingController _sourceSearchController = TextEditingController();
  final FocusNode _destFocusNode = FocusNode();
  final FocusNode _sourceFocusNode = FocusNode();

  // Google Maps controller
  gmaps.GoogleMapController? _mapController;
  final GoogleDirectionsService _directionsService = GoogleDirectionsService();

  // Travel mode selection
  TravelMode _selectedTravelMode = TravelMode.driving;

  // Routing variables
  LatLng? _currentLocation;
  LatLng? _sourceLocation;
  bool _useCurrentLocationAsSource = true;
  LatLng? _destinationLocation;
  List<LatLng> _bestRoutePoints = [];
  List<List<LatLng>> _alternativeRoutes = [];
  bool _isRouteVisible = false;
  bool _isLoading = false;
  List<LatLng> _newsMarkers = [];

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

  // Google Maps variables
  Set<gmaps.Marker> _gMapMarkers = {};
  Set<gmaps.Polyline> _gMapPolylines = {};

  // Constants
  static const double _earthRadius = 6371000; // Earth radius in meters
  static const double _safetyWeight = 0.7;
  static const double _distanceWeight = 0.3;
  static const int _maxRoutes = 5;

  @override
  void dispose() {
    _destSearchController.dispose();
    _sourceSearchController.dispose();
    _destFocusNode.dispose();
    _sourceFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Load map without waiting for location first
    _fetchMarkerData();

    // Try to get location in the background
    Future.delayed(Duration.zero, () {
      _getCurrentLocationCoordinates().then((_) {
        // If we got location, update map
        if (_currentLocation != null && _mapController != null && mounted) {
          setState(() {
            // Just update state to refresh
          });

          _mapController!.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(
              gmaps.LatLng(
                _currentLocation!.latitude,
                _currentLocation!.longitude,
              ),
              14.0,
            ),
          );
        }
      });
    });
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

        // Move camera to source location
        if (_mapController != null) {
          _mapController!.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(
              gmaps.LatLng(source.latitude, source.longitude),
              14.0,
            ),
          );
        }

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
        final destination = LatLng(location.latitude, location.longitude);

        setState(() {
          _destinationLocation = destination;
        });

        // Move camera to destination
        if (_mapController != null) {
          _mapController!.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(
              gmaps.LatLng(destination.latitude, destination.longitude),
              14.0,
            ),
          );
        }

        // If we don't have a source yet, get current location
        if (_useCurrentLocationAsSource && _currentLocation == null) {
          await _getCurrentLocationCoordinates();
        }

        // Draw route if we have both source and destination
        if ((_useCurrentLocationAsSource && _currentLocation != null) ||
            (!_useCurrentLocationAsSource && _sourceLocation != null)) {
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

  String _formatSafetyScore(double rawScore) {
    // Safety is measured in meters distance from danger
    // Lower distance = less safe
    if (rawScore <= 100) {
      // Under 100m is considered high risk (0-20%)
      return "${(rawScore / 5).toStringAsFixed(1)}%";
    } else if (rawScore <= 500) {
      // 100-500m is medium risk (20-70%)
      return "${(20 + (rawScore - 100) / 500 * 50).toStringAsFixed(1)}%";
    } else {
      // Over 500m is relatively safe (70-95%)
      double score = min(95.0, 70 + (rawScore - 500) / 500 * 25);
      return "${score.toStringAsFixed(1)}%";
    }
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

  // Get routes using Google Directions API
  Future<List<List<LatLng>>> _getAlternativeRoutes(
    LatLng sourceLocation,
  ) async {
    if (sourceLocation == null || _destinationLocation == null) return [];

    _clearRouteMetrics();
    final routes = <List<LatLng>>[];

    try {
      // Get Google directions routes
      final directionsRoutes = await _directionsService.getRoutes(
        origin: sourceLocation,
        destination: _destinationLocation!,
        travelMode: _selectedTravelMode,
        alternatives: true,
      );

      // Process each route
      for (final route in directionsRoutes) {
        final points = _decodeRoutePath(route);
        if (points.isNotEmpty) {
          routes.add(points);

          // Calculate metrics
          final distance = route.legs.fold(
            0.0,
            (sum, leg) => sum + (leg.distance?.value?.toDouble() ?? 0.0),
          );
          final duration = route.legs.fold(
            0.0,
            (sum, leg) => sum + (leg.duration?.value?.toDouble() ?? 0.0),
          );

          _routeDistances.add(distance);
          _routeDurations.add(duration);

          final safetyScore = _calculateRouteSafety(points);
          _routeSafetyScores.add(safetyScore);
        }
      }

      // Generate additional routes with waypoints if needed
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

  // Add to your _SafestRoutePageState class
  void _refreshMarkers() {
    // Check if marker data has been loaded
    _fetchMarkerData().then((snapshots) {
      if (snapshots.isNotEmpty && mounted) {
        _updateMapMarkers(snapshots[0], snapshots[1], snapshots[2]);
      }
    });
  }

  // Helper to decode the polyline from a Google DirectionsRoute
  List<LatLng> _decodeRoutePath(DirectionsRoute route) {
    if (route.overviewPolyline?.points == null) return [];

    return _directionsService.decodePolyline(route.overviewPolyline!.points!);
  }

  // Generate additional routes using waypoints
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

      // Get route through waypoint
      try {
        final waypointRoutes = await _directionsService.getRoutes(
          origin: sourceLocation,
          destination: _destinationLocation!,
          waypoints: [waypoint],
          travelMode: _selectedTravelMode,
          alternatives: false,
        );

        for (final route in waypointRoutes) {
          final points = _decodeRoutePath(route);
          if (points.isNotEmpty) {
            existingRoutes.add(points);

            // Calculate metrics
            final distance = route.legs.fold(
              0.0,
              (sum, leg) => sum + (leg.distance?.value?.toDouble() ?? 0.0),
            );
            final duration = route.legs.fold(
              0.0,
              (sum, leg) => sum + (leg.duration?.value?.toDouble() ?? 0.0),
            );

            _routeDistances.add(distance);
            _routeDurations.add(duration);

            final safetyScore = _calculateRouteSafety(points);
            _routeSafetyScores.add(safetyScore);
          }
        }
      } catch (e) {
        print("Error generating waypoint route: $e");
      }
    }
  }

  void _calculateAllOverallScores(List<List<LatLng>> routes) {
    _routeOverallScores = [];
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
      setState(() {
        _isLoading = true;
      });

      final routes = await _getAlternativeRoutes(sourceLocation);

      if (routes.isEmpty) {
        _showMessage("No routes found", isError: true);
        setState(() {
          _isLoading = false;
        });
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
        _isLoading = false;

        // Update the polylines on Google Map
        _updateMapPolylines();
      });

      if (_bestRoutePoints.isNotEmpty) {
        _fitMapToRoute();
      }

      _showMessage(
        "Best route found (${routes.length} alternatives analyzed)",
        isError: false,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage("Failed to get best route: ${e.toString()}", isError: true);
    }
  }

  int _findBestRouteIndex() {
    if (_routeOverallScores.isEmpty) return 0;

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

  // UI Formatting helpers
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

  // Fit map to the route bounds
  void _fitMapToRoute() {
    if (_bestRoutePoints.isEmpty || _mapController == null) return;

    // Calculate bounds
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    // Add source and destination points to bounds calculation
    List<LatLng> allPoints = [..._bestRoutePoints];
    if (_sourceLocation != null) allPoints.add(_sourceLocation!);
    if (_destinationLocation != null) allPoints.add(_destinationLocation!);

    for (final point in allPoints) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    // Convert to Google's LatLngBounds
    final bounds = gmaps.LatLngBounds(
      southwest: gmaps.LatLng(minLat, minLng),
      northeast: gmaps.LatLng(maxLat, maxLng),
    );

    // Add some padding
    _mapController!.animateCamera(
      gmaps.CameraUpdate.newLatLngBounds(bounds, 50.0),
    );
  }

  void _clearRoute() {
    setState(() {
      _bestRoutePoints = [];
      _alternativeRoutes = [];
      _isRouteVisible = false;
      _gMapPolylines = {};
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
      if (_mapController != null) {
        _mapController!.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            gmaps.LatLng(
              _currentLocation!.latitude,
              _currentLocation!.longitude,
            ),
            14.0,
          ),
        );
      }

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

  // Add this method to your _SafestRoutePageState class
  Future<List<QuerySnapshot>> _fetchMarkerData() async {
    final news =
        await FirebaseFirestore.instance.collection('news_markers').get();
    final ngos = await FirebaseFirestore.instance.collection('ngos').get();
    final police =
        await FirebaseFirestore.instance.collection('police_stations').get();
    return [news, ngos, police];
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

  // URL launching logic
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

  // Combine Firestore streams for map data
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

  // Update markers for Google Maps
  void _updateMapMarkers(
    QuerySnapshot newsSnapshot,
    QuerySnapshot ngosSnapshot,
    QuerySnapshot policeSnapshot,
  ) {
    final markers = <gmaps.Marker>{};
    final newsMarkers = <LatLng>[];

    // Add current location marker
    if (_useCurrentLocationAsSource && _currentLocation != null) {
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('current_location'),
          position: gmaps.LatLng(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
          ),
          infoWindow: gmaps.InfoWindow(title: 'Current Location'),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueBlue,
          ),
        ),
      );
    }

    // Add custom source location marker
    if (!_useCurrentLocationAsSource && _sourceLocation != null) {
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('source'),
          position: gmaps.LatLng(
            _sourceLocation!.latitude,
            _sourceLocation!.longitude,
          ),
          infoWindow: gmaps.InfoWindow(title: 'Starting Point'),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueBlue,
          ),
        ),
      );
    }

    // Add destination marker
    if (_destinationLocation != null) {
      markers.add(
        gmaps.Marker(
          markerId: gmaps.MarkerId('destination'),
          position: gmaps.LatLng(
            _destinationLocation!.latitude,
            _destinationLocation!.longitude,
          ),
          infoWindow: gmaps.InfoWindow(title: 'Destination'),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    // Add news markers
    if (_showNews) {
      int index = 0;
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
            gmaps.Marker(
              markerId: gmaps.MarkerId('news_$index'),
              position: gmaps.LatLng(lat, lon),
              infoWindow: gmaps.InfoWindow(
                title: title,
                snippet: 'Click for more information',
                onTap:
                    () => _showNewsDetails(
                      context,
                      title,
                      description,
                      sourceUrl,
                    ),
              ),
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueAzure,
              ),
            ),
          );
          index++;
        } catch (e) {
          print("Error processing news marker: $e");
          continue;
        }
      }
    }

    // Add NGO markers
    if (_showNGOs) {
      int index = 0;
      for (final doc in ngosSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;

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

          markers.add(
            gmaps.Marker(
              markerId: gmaps.MarkerId('ngo_$index'),
              position: gmaps.LatLng(lat, lon),
              infoWindow: gmaps.InfoWindow(
                title: name,
                snippet: 'NGO Services',
                onTap: () => _showNGODetails(context, name, sectors),
              ),
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueOrange,
              ),
            ),
          );
          index++;
        } catch (e) {
          print("Error processing NGO marker: $e");
          continue;
        }
      }
    }

    // Add Police Station markers
    if (_showPoliceStations) {
      int index = 0;
      for (final doc in policeSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final lat = data['latitude'] as double?;
          final lon = data['longitude'] as double?;
          final name = data['name']?.toString() ?? 'Police Station';

          if (lat == null || lon == null) continue;

          markers.add(
            gmaps.Marker(
              markerId: gmaps.MarkerId('police_$index'),
              position: gmaps.LatLng(lat, lon),
              infoWindow: gmaps.InfoWindow(
                title: name,
                snippet: 'Police Station',
                onTap: () => _showPoliceStationDetails(context, name),
              ),
              icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                gmaps.BitmapDescriptor.hueRed,
              ),
            ),
          );
          index++;
        } catch (e) {
          print("Error processing police marker: $e");
          continue;
        }
      }
    }

    // Update news markers for safety calculation
    _newsMarkers = newsMarkers;

    // Update the state
    setState(() {
      _gMapMarkers = markers;
    });
  }

  // Update polylines for Google Maps
  void _updateMapPolylines() {
    final polylines = <gmaps.Polyline>{};

    // Add alternative routes first
    for (int i = 0; i < _alternativeRoutes.length; i++) {
      final route = _alternativeRoutes[i];
      if (route.isNotEmpty) {
        polylines.add(
          gmaps.Polyline(
            polylineId: gmaps.PolylineId('alternative_$i'),
            points:
                route
                    .map(
                      (point) => gmaps.LatLng(point.latitude, point.longitude),
                    )
                    .toList(),
            width: 3,
            color: Colors.red.withOpacity(0.6),
          ),
        );
      }
    }

    // Add best route on top
    if (_bestRoutePoints.isNotEmpty) {
      polylines.add(
        gmaps.Polyline(
          polylineId: gmaps.PolylineId('best_route'),
          points:
              _bestRoutePoints
                  .map((point) => gmaps.LatLng(point.latitude, point.longitude))
                  .toList(),
          width: 5,
          color: Colors.green,
        ),
      );
    }

    setState(() {
      _gMapPolylines = polylines;
    });
  }

  // Build travel mode selector
  Widget _buildTravelModeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children:
            TravelModeInfo.allModes
                .map(
                  (modeInfo) => _buildTravelModeButton(
                    icon: modeInfo.icon,
                    mode: modeInfo.mode,
                    tooltip: modeInfo.name,
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildTravelModeButton({
    required IconData icon,
    required TravelMode mode,
    required String tooltip,
  }) {
    final isSelected = _selectedTravelMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            _selectedTravelMode = mode;
          });
          // Recalculate route if visible
          if (_isRouteVisible) {
            _drawBestRoute();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.blue : Colors.grey,
            size: 24,
          ),
        ),
      ),
    );
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
    final modeParam = _selectedTravelMode.value;
    final url =
        "https://www.google.com/maps/dir/?api=1&origin=$sourceLat,$sourceLng&destination=$destLat,$destLng&travelmode=$modeParam";
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showMessage("Could not open maps application", isError: true);
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 4,
        shadowColor:
            isDark
                ? Colors.purple.withOpacity(0.2)
                : Colors.pink.withOpacity(0.2),
        centerTitle: true,
        title: Text(
          "SAFEST ROUTE",
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
            letterSpacing: 1.2,
          ),
        ),
      ),
      drawer: const NavBar(),
      body: Stack(
        children: [
          // Replace the entire StreamBuilder in your build method with this:
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target:
                  _currentLocation != null
                      ? gmaps.LatLng(
                        _currentLocation!.latitude,
                        _currentLocation!.longitude,
                      )
                      : gmaps.LatLng(
                        20.5937,
                        78.9629,
                      ), // Default to India center
              zoom: 14.0,
            ),
            onMapCreated: (controller) {
              _mapController = controller;

              // Load markers after map is created
              _fetchMarkerData().then((snapshots) {
                if (snapshots.isNotEmpty && mounted) {
                  _updateMapMarkers(snapshots[0], snapshots[1], snapshots[2]);
                }
              });
            },
            markers: _gMapMarkers,
            polylines: _gMapPolylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: gmaps.MapType.normal,
            zoomControlsEnabled: false,
          ),
          // Travel Mode Selector
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                width: double.infinity,
                child: _buildTravelModeSelector(),
              ),
            ),
          ),
          // Search Bars
          Positioned(
            top: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Source Location Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDark
                                ? Colors.black12
                                : Colors.grey.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _sourceSearchController,
                    focusNode: _sourceFocusNode,
                    enabled: !_isLoading,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: 'Poppins',
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          _useCurrentLocationAsSource
                              ? "Current Location (tap to change)"
                              : "Source Location",
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontFamily: 'Poppins',
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.trip_origin,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_useCurrentLocationAsSource)
                            IconButton(
                              icon: const Icon(
                                Icons.my_location,
                                color: Colors.blue,
                              ),
                              onPressed: _getCurrentLocation,
                              tooltip: "Use current location",
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.search,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed:
                                _isLoading ? null : _searchSourceLocation,
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
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
                const SizedBox(height: 8),
                // Destination Location Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            isDark
                                ? Colors.black12
                                : Colors.grey.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _destSearchController,
                    focusNode: _destFocusNode,
                    enabled: !_isLoading,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: 'Poppins',
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search for a destination...",
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontFamily: 'Poppins',
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 22,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isRouteVisible)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: _clearRoute,
                              tooltip: "Clear route",
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.search,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed:
                                _isLoading ? null : _searchDestinationLocation,
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Marker Filter Panel
          Positioned(
            top: 180,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDark ? Colors.black12 : Colors.grey.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Show Markers",
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMarkerToggle(
                    "News",
                    CupertinoIcons.exclamationmark_shield_fill,
                    Colors.blue,
                    _showNews,
                    (value) {
                      setState(() => _showNews = value);
                      _refreshMarkers();
                    },
                  ),
                  _buildMarkerToggle(
                    "NGOs",
                    Icons.volunteer_activism,
                    Colors.orange,
                    _showNGOs,
                    (value) {
                      setState(() => _showNGOs = value);
                      _refreshMarkers();
                    },
                  ),
                  _buildMarkerToggle(
                    "Police",
                    Icons.local_police,
                    Colors.red,
                    _showPoliceStations,
                    (value) {
                      setState(() => _showPoliceStations = value);
                      _refreshMarkers();
                    },
                  ),
                ],
              ),
            ),
          ),
          // Route Information Panel
          if (_isRouteVisible && _routeDistances.isNotEmpty)
            Positioned(
              top: 180,
              right: 20,
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          isDark
                              ? Colors.black12
                              : Colors.grey.withOpacity(0.08),
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
                      children: [
                        Icon(Icons.route, color: Colors.green, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          "Best Route",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Distance: ${_formatDistance(_routeDistances[_bestRouteIndex])}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'Poppins',
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Duration: ${_formatDuration(_routeDurations[_bestRouteIndex])}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'Poppins',
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      "Safety: ${_formatSafetyScore(_routeSafetyScores[_bestRouteIndex])}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'Poppins',
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final src =
                            _useCurrentLocationAsSource
                                ? _currentLocation
                                : _sourceLocation;
                        final dest = _destinationLocation;
                        if (src != null && dest != null) {
                          await _openMapsDirections(
                            src.latitude,
                            src.longitude,
                            dest.latitude,
                            dest.longitude,
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text("Open in Google Maps"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
}
