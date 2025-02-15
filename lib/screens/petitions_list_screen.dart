import 'package:flutter/material.dart';

class Petition {
  final String title;
  final String description;

  Petition({required this.title, required this.description});
}

class PetitionListScreen extends StatefulWidget {
  const PetitionListScreen({super.key});

  @override
  _PetitionListScreenState createState() => _PetitionListScreenState();
}

class _PetitionListScreenState extends State<PetitionListScreen> {
  List<Petition> petitions = []; // Stores petitions with title & description

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Active Petitions")),
      body: petitions.isEmpty
          ? Center(child: Text("No active petitions."))
          : ListView.builder(
              itemCount: petitions.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(petitions[index].title, style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(petitions[index].description),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newPetition = await Navigator.pushNamed(context, '/add_petition');
          if (newPetition != null && newPetition is Petition) {
            setState(() {
              petitions.add(newPetition);
            });
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
