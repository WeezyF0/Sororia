import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ComplaintsMapScreen extends StatefulWidget {
  const ComplaintsMapScreen({super.key});

  @override
  _ComplaintsMapScreenState createState() => _ComplaintsMapScreenState();
}

class _ComplaintsMapScreenState extends State<ComplaintsMapScreen> {
  GoogleMapController? mapController;
  Set<Marker> markers = {};

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection("complaints").snapshots().listen((snapshot) {
      setState(() {
        markers = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          return Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(data["location"]["lat"], data["location"]["lng"]),
            infoWindow: InfoWindow(title: data["description"]),
          );
        }).toSet();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Complaint Map")),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: LatLng(20.0, 78.0), zoom: 5),
        onMapCreated: (controller) => mapController = controller,
        markers: markers,
      ),
    );
  }
}
