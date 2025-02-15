import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> createPetition(String title, String description) async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    await FirebaseFirestore.instance.collection("petitions").add({
      "title": title,
      "description": description,
      "createdBy": user.uid,
      "signatures": 0,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }
}

Future<void> signPetition(String petitionId) async {
  DocumentReference petitionRef =
      FirebaseFirestore.instance.collection("petitions").doc(petitionId);

  FirebaseFirestore.instance.runTransaction((transaction) async {
    DocumentSnapshot snapshot = await transaction.get(petitionRef);
    if (snapshot.exists) {
      int currentSignatures = snapshot["signatures"] ?? 0;
      transaction.update(petitionRef, {"signatures": currentSignatures + 1});
    }
  });
}

