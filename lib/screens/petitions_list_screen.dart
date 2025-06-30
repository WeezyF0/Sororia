import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'navbar.dart';

class PetitionListScreen extends StatelessWidget {
  const PetitionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80.0),
        child: AppBar(
          centerTitle: true,
          title: Text(
            "ACTIVE PETITIONS",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              fontSize: 24,
              color: Theme.of(context).appBarTheme.foregroundColor,
              shadows: [
                Shadow(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.purple.withOpacity(0.2)
                          : Colors.pink.withOpacity(0.2),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: NavBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.pushNamed(context, '/add_petition');
        },
        backgroundColor: colorScheme.secondary,
        elevation: 4,
        icon: Icon(
          Icons.add_circle_outline,
          color: colorScheme.onSecondary,
          size: 24,
        ),
        label: Text(
          'Start a Petition',
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondary,
          ),
        ),
      ),
      body: StreamBuilder(
        stream:
            FirebaseFirestore.instance
                .collection('petitions')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text("No active petitions.", style: textTheme.bodyLarge),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16.0),
            physics: const BouncingScrollPhysics(),
            children:
                snapshot.data!.docs.map((doc) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    elevation: theme.cardTheme.elevation,
                    shape: theme.cardTheme.shape,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8.0),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/open_petition',
                          arguments: doc['petition_id'],
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc['title'], style: textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                              doc['description'],
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}
