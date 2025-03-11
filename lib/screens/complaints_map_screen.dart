import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';

class ComplaintMapScreen extends StatelessWidget {
  const ComplaintMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          // Remove default leading/back button to avoid misalignment
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/appBar_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            // SafeArea prevents overlap with status bar
            child: SafeArea(
              // Center horizontally & vertically
              child: Center(
                // Row sized to its children, so they remain together in the center
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start, // Distribute space between children
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Custom back arrow (white)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    // Title
                    const Text(
                      "COMPLAINTS MAP",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('complaints').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No complaints available"));
          }

          final random = Random();
          Set<String> uniqueCoordinates = {}; // Track unique lat/lon
          List<Marker> markers = [];

          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            double? lat = data['latitude'] as double?;
            double? lon = data['longitude'] as double?;

            if (lat == null || lon == null) {
              print("Skipping document ${doc.id} - invalid coordinates");
              continue;
            }

            // Ensure unique locations to prevent overlap
            double newLat = lat;
            double newLon = lon;
            String coordKey = "$newLat,$newLon";

            while (uniqueCoordinates.contains(coordKey)) {
              newLat += (random.nextDouble() - 0.5) * 0.0005;
              newLon += (random.nextDouble() - 0.5) * 0.0005;
              coordKey = "$newLat,$newLon";
            }
            uniqueCoordinates.add(coordKey);

            markers.add(
              Marker(
                point: LatLng(newLat, newLon),
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            );
          }

          return FlutterMap(
            options: MapOptions(
              initialCenter: markers.isNotEmpty
                  ? markers.first.point
                  : const LatLng(20.5937, 78.9629), // Default to India if no markers
              initialZoom: 10,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.complaints.app',
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }
}
