import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'navbar.dart';
import 'package:complaints_app/screens/open_complaint.dart';


class ComplaintMapScreen extends StatefulWidget {
  const ComplaintMapScreen({super.key});

  @override
  State<ComplaintMapScreen> createState() => _ComplaintMapScreenState();
}

class _ComplaintMapScreenState extends State<ComplaintMapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
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
            child: const SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "COMPLAINTS MAP",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      drawer: NavBar(),
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
          Set<String> uniqueCoordinates = {};
          List<Marker> markers = [];

          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            double? lat = data['latitude'] as double?;
            double? lon = data['longitude'] as double?;
            String title = data['issue_type'] ?? 'No issue type';
            String description = data['text'] ?? 'No description';

            if (lat == null || lon == null) {
              print("Skipping document ${doc.id} - invalid coordinates");
              continue;
            }

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

          return FlutterMap(
            options: MapOptions(
              initialCenter: markers.isNotEmpty
                  ? markers.first.point
                  : const LatLng(20.5937, 78.9629),
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
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }
}