import 'package:complaints_app/screens/navbar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:complaints_app/theme/theme_provider.dart';
import 'package:provider/provider.dart';

class NewsMapScreen extends StatefulWidget {
  const NewsMapScreen({super.key});

  @override
  State<NewsMapScreen> createState() => _NewsMapScreenState();
}

class _NewsMapScreenState extends State<NewsMapScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  // Google Maps controller
  gmaps.GoogleMapController? _mapController;
  Set<gmaps.Marker> _markers = {};
  
  // Dark mode map style
  static const String _darkMapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#212121"
        }
      ]
    },
    {
      "elementType": "labels.icon",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#212121"
        }
      ]
    },
    {
      "featureType": "administrative",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "featureType": "administrative.country",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#9e9e9e"
        }
      ]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#bdbdbd"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#181818"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#616161"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.fill",
      "stylers": [
        {
          "color": "#2c2c2c"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#8a8a8a"
        }
      ]
    },
    {
      "featureType": "road.arterial",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#373737"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#3c3c3c"
        }
      ]
    },
    {
      "featureType": "road.highway.controlled_access",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#4e4e4e"
        }
      ]
    },
    {
      "featureType": "road.local",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#616161"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#757575"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#000000"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#3d3d3d"
        }
      ]
    }
  ]
  ''';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // Update map style based on current theme
  void _updateMapStyle() {
    if (_mapController == null) return;

    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDark;

    if (isDark) {
      _mapController!.setMapStyle(_darkMapStyle);
    } else {
      _mapController!.setMapStyle(null); // Reset to default style
    }
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
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            gmaps.LatLng(location.latitude, location.longitude),
            14.0,
          ),
        );
      } else {
        _showError("Location not found");
      }
    } catch (e) {
      _showError("Invalid place name");
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
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
    _mapController?.animateCamera(
      gmaps.CameraUpdate.newLatLngZoom(
        gmaps.LatLng(position.latitude, position.longitude),
        14.0,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message))
    );
  }

  Future<void> _launchNewsUrl(String? url) async {
    if (url == null || url.isEmpty) {
      _showError("No news article URL available");
      return;
    }

    try {
      // Clean the URL - remove any extra whitespace
      String cleanUrl = url.trim();

      // Ensure URL has proper protocol
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }

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
        _showError("Cannot open this URL on your device");
      }
    } catch (e) {
      _showError("Error opening article: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          toolbarHeight: 80,
          centerTitle: true,
          title: const Text(
            "NEWS MAP",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
              fontSize: 24,
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
                return const Center(child: Text("No news available"));
              }

              // Process news markers
              _markers = {};
              
              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                double? lat = data['latitude'] as double?;
                double? lon = data['longitude'] as double?;
                String originalText = data['original_text'] ?? 'No description available';
                String? sourceUrl = data['source_url'] as String?;

                if (lat == null || lon == null) continue;

                // Add Google Maps Marker
                _markers.add(
                  gmaps.Marker(
                    markerId: gmaps.MarkerId('news_${doc.id}'),
                    position: gmaps.LatLng(lat, lon),
                    icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueBlue),
                    infoWindow: gmaps.InfoWindow(
                      title: "News Report",
                      snippet: originalText.length > 30
                          ? '${originalText.substring(0, 30)}...'
                          : originalText,
                      onTap: () => showNewsDetails(context, originalText, sourceUrl),
                    ),
                  ),
                );
              }

              return Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  // Update map style when theme changes
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _updateMapStyle();
                  });

                  return gmaps.GoogleMap(
                    initialCameraPosition: gmaps.CameraPosition(
                      target: _markers.isNotEmpty
                          ? _markers.first.position
                          : gmaps.LatLng(20.5937, 78.9629), // Default to India center
                      zoom: 10,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      
                      // Apply initial style based on theme
                      if (themeProvider.isDark) {
                        controller.setMapStyle(_darkMapStyle);
                      }
                    },
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    mapType: gmaps.MapType.normal,
                    zoomControlsEnabled: false,
                  );
                },
              );
            },
          ),

          // Search Bar
          Positioned(
            top: 30,
            left: 20,
            right: 20,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[800]
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26, 
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: "Search for a location...",
                  hintStyle: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : Colors.black54,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.blue),
                    onPressed: _searchLocation,
                  ),
                ),
                onSubmitted: (_) => _searchLocation(),
              ),
            ),
          ),

          // Current Location Button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.white,
              elevation: 4,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void showNewsDetails(BuildContext context, String description, String? sourceUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[900]
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.news, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  "News Report",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (sourceUrl != null && sourceUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _launchNewsUrl(sourceUrl);
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Read Full Article"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Close"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}