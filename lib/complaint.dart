import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> submitComplaint(String description, double lat, double lng) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await FirebaseFirestore.instance.collection("complaints").add({
      "userId": user.uid,
      "description": description,
      "location": {"lat": lat, "lng": lng},
      "timestamp": FieldValue.serverTimestamp(),
    });
  }
}

Stream<QuerySnapshot> getComplaints() {
  return FirebaseFirestore.instance.collection("complaints").snapshots();
}
