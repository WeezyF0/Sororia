import 'package:flutter/material.dart';

class NavBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey[100]!, Colors.grey[200]!],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Custom drawer header with gradient and logo/image
            Container(
              height: 170,
              child: DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blueGrey[800]!, Colors.black],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Prevent overflow
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 30,
                      child: Icon(
                        Icons.account_balance,
                        size: 35,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "GramSewa",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                  ],
                ),
              ),
            ),
            
            // Complaints section
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0),
              child: Text(
                "COMPLAINTS",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.report_problem, color: Colors.orange[700]),
              title: Text("View Complaints"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, "/complaints");
              },
            ),
            ListTile(
              leading: Icon(Icons.map, color: Colors.green[700]),
              title: Text("Map View"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, "/complaints_map");
              },
            ),
            
            Divider(),
            
            // Petitions section
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0),
              child: Text(
                "PETITIONS",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.gavel, color: Colors.blue[700]),
              title: Text("All Petitions"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, "/petitions");
              },
            ),
            ListTile(
              leading: Icon(Icons.folder_special, color: Colors.purple[700]),
              title: Text("My Petitions"),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, "/my_petitions");
              },
            ),
            
            Divider(),
            
            // Account section
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red[700]),
              title: Text("Logout"),
              onTap: () {
                Navigator.pushNamed(context, "/login");
              },
            ),

            SizedBox(height: 20), // Reduce extra space
            
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0), // Ensure spacing is controlled
                child: Text(
                  "Version 1.0.0",
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
