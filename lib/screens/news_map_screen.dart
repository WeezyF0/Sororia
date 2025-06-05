import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:complaints_app/services/location_service.dart';
import 'package:complaints_app/services/web_geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsMapScreen extends StatefulWidget {
  const NewsMapScreen({super.key});

  @override
  State<NewsMapScreen> createState() => _NewsMapScreenState();
}

class _NewsMapScreenState extends State<NewsMapScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
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

      List<LatLng> locations = await WebGeocoding.locationFromAddress(placeName);
      if (locations.isNotEmpty) {
        LatLng location = locations.first;
        _mapController.move(location, 14.0);
      } else {
        _showError("Location not found");
      }
    } catch (e) {
      _showError("Invalid place name or network error");
    }
  }Future<void> _getCurrentLocation() async {
    try {
      Position? position = await LocationService.getCurrentPosition();
      if (position != null) {
        _mapController.move(LatLng(position.latitude, position.longitude), 14.0);
      } else {
        _showError("Unable to get your current location");
      }
    } catch (e) {
      String errorMessage = LocationService.getLocationErrorMessage(e);
      _showError(errorMessage);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
        _showError("Cannot open this URL on your device");
      }
    } catch (e) {
      print("URL Launch Error: $e"); // Debug log
      _showError("Error opening article: ${e.toString()}");
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
            "News Map",
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

              List<Marker> markers = [];

              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                double? lat = data['latitude'] as double?;
                double? lon = data['longitude'] as double?;
                String originalText = data['original_text'] ?? 'No description available';
                String? sourceUrl = data['source_url'] as String?;

                if (lat == null || lon == null) continue;

                markers.add(
                  Marker(
                    point: LatLng(lat, lon),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => showNewsDetails(
                        context,
                        originalText,
                        sourceUrl,
                      ),
                      child: const Icon(
                        CupertinoIcons.news_solid,
                        color: Colors.blue,
                        size: 36,
                      ),
                    ),
                  ),
                );
              }

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: markers.isNotEmpty
                      ? markers.first.point
                      : const LatLng(20.5937, 78.9629), // Default to India center
                  initialZoom: 10,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://www.google.com/maps/vt?lyrs=m@221097413,traffic&x={x}&y={y}&z={z}',
                    userAgentPackageName: 'com.complaints.app',
                  ),
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
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: Colors.blue),
                    onPressed: _searchLocation,
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
        ],
      ),
    );
  }

  void showNewsDetails(
    BuildContext context,
    String description,
    String? sourceUrl,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                SizedBox(width: 8),
                Text(
                  "News Report",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  description,
                  style: TextStyle(fontSize: 16, height: 1.4),
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
                  icon: Icon(Icons.open_in_new),
                  label: Text("Read Full Article"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
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
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text("Close"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}