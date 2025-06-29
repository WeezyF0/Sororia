import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'navbar.dart';

class PetitionListScreen extends StatefulWidget {
  const PetitionListScreen({super.key});

  @override
  State<PetitionListScreen> createState() => _PetitionListScreenState();
}

class _PetitionListScreenState extends State<PetitionListScreen>
    with SingleTickerProviderStateMixin {
  double _fabScale = 1.0;

  void _onFabTapDown(TapDownDetails details) {
    setState(() {
      _fabScale = 0.92;
    });
  }

  void _onFabTapUp(TapUpDetails details) {
    setState(() {
      _fabScale = 1.0;
    });
  }

  void _onFabTapCancel() {
    setState(() {
      _fabScale = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    const sororiaPink = Color(0xFFE91E63);
    const accentBlue = Color(0xFF1976D2); // Material blue 700

    return Scaffold(
      // Use a blue gradient background for a fresh, modern look
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7F7F9), Color(0xFFE3F0FF), Color(0xFFD0E6FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                title: Text(
                  "ACTIVE PETITIONS",
                  style: TextStyle(
                    color: sororiaPink,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                iconTheme: const IconThemeData(color: sororiaPink),
              ),
              // Expanded ListView
              Expanded(
                child: StreamBuilder(
                  stream:
                      FirebaseFirestore.instance
                          .collection('petitions')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: sororiaPink),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          "No active petitions.",
                          style: textTheme.bodyLarge?.copyWith(
                            color: Colors.black54,
                          ),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.all(16.0),
                      physics: const BouncingScrollPhysics(),
                      children:
                          snapshot.data!.docs.map((doc) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                              child: Card(
                                elevation: 0, // shadow handled by container
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14.0),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doc['title'],
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                color: sororiaPink,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          doc['description'],
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: const NavBar(),
      floatingActionButton: GestureDetector(
        onTapDown: _onFabTapDown,
        onTapUp: _onFabTapUp,
        onTapCancel: _onFabTapCancel,
        onTap: () async {
          setState(() => _fabScale = 1.0);
          await Navigator.pushNamed(context, '/add_petition');
        },
        child: AnimatedScale(
          scale: _fabScale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: FloatingActionButton.extended(
            backgroundColor: accentBlue,
            elevation: 4,
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 24,
            ),
            label: const Text(
              'Start a Petition',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            onPressed: null, // handled by GestureDetector
          ),
        ),
      ),
    );
  }
}
