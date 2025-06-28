import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class OpenPetitionScreen extends StatelessWidget {
  const OpenPetitionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sororiaPink = Color(0xFFE91E63);
    final accentBlue = const Color(0xFF1976D2);
    final theme = Theme.of(context);

    // Retrieve the petition ID from route arguments
    final String petitionId =
        ModalRoute.of(context)!.settings.arguments as String;

    // Get current user ID
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      // Handle case where user is not logged in
      return const Scaffold(
        body: Center(child: Text("Please log in to view petitions")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        iconTheme: const IconThemeData(color: sororiaPink),
        title: Text(
          "REVIEW PETITION",
          style: const TextStyle(
            color: sororiaPink,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('petitions')
                .doc(petitionId)
                .snapshots(),
        builder: (context, petitionSnapshot) {
          if (petitionSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!petitionSnapshot.hasData || !petitionSnapshot.data!.exists) {
            return const Center(child: Text("No petition data available."));
          }

          // Extract petition data
          final petitionData =
              petitionSnapshot.data!.data() as Map<String, dynamic>;
          final String id = petitionData['petition_id'] ?? petitionId;
          final String title = petitionData['title'] ?? 'No Title';
          final String description =
              petitionData['description'] ?? 'No Description';
          final List<dynamic> signatures = petitionData['signatures'] ?? [];
          final int signatureCount = signatures.length;
          final bool hasUserSigned = signatures.contains(currentUserId);
          final List<dynamic> protestsData = petitionData['protests'] ?? [];

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display Petition ID outside the card
                  Text(
                    "Petition ID: $id",
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Card for petition details
                  Card(
                    color: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Petition Title (bold)
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: sororiaPink,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Petition Description
                          Text(
                            description,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.8,
                              ),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Use LayoutBuilder for adaptive layout based on available width
                          LayoutBuilder(
                            builder: (context, constraints) {
                              // Check if screen is wide enough for row layout
                              bool useRowLayout = constraints.maxWidth > 400;

                              return useRowLayout
                                  ? _buildRowLayout(
                                    context,
                                    signatureCount,
                                    hasUserSigned,
                                    currentUserId,
                                    petitionId,
                                    accentBlue,
                                    sororiaPink,
                                  )
                                  : _buildColumnLayout(
                                    context,
                                    signatureCount,
                                    hasUserSigned,
                                    currentUserId,
                                    petitionId,
                                    accentBlue,
                                    sororiaPink,
                                  );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Display Protests Section
                  const SizedBox(height: 24),
                  Text(
                    "RELATED PROTESTS",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (protestsData.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "No protests planned for this petition yet.",
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: protestsData.length,
                      itemBuilder: (context, index) {
                        final protestData =
                            protestsData[index] as Map<String, dynamic>;
                        final String protestId =
                            protestData['protest_id'] ?? '';
                        final String protestTitle =
                            protestData['title'] ?? 'Unnamed Protest';
                        final DateTime date =
                            (protestData['date'] as Timestamp).toDate();
                        final String location =
                            protestData['location'] ?? 'Location not specified';
                        final List<dynamic> supporters =
                            protestData['supporters'] ?? [];
                        return Card(
                          color: Colors.white,
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14.0),
                            onTap: () {
                              _showProtestDetails(
                                context,
                                protestData,
                                petitionId,
                                title,
                                currentUserId,
                                accentBlue,
                                sororiaPink,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    protestTitle,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: accentBlue,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: accentBlue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: accentBlue,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          location,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: Colors.black87),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 16,
                                        color: accentBlue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${supporters.length} supporters",
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: Colors.black87),
                                      ),
                                    ],
                                  ),
                                  if (protestData['host_name'] != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person,
                                          size: 16,
                                          color: accentBlue,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Host: ${protestData['host_name']}",
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // Add button to create a new protest
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                      ),
                      label: const Text("ORGANIZE A PROTEST"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        _showCreateProtestDialog(
                          context,
                          petitionId,
                          currentUserId,
                          title,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRowLayout(
    BuildContext context,
    int signatureCount,
    bool hasUserSigned,
    String currentUserId,
    String petitionId,
    Color accentBlue,
    Color sororiaPink,
  ) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            "$signatureCount ${signatureCount == 1 ? 'person has' : 'people have'} already signed",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: accentBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _buildSignButton(
            context,
            hasUserSigned,
            currentUserId,
            petitionId,
            accentBlue,
            sororiaPink,
          ),
        ),
      ],
    );
  }

  Widget _buildColumnLayout(
    BuildContext context,
    int signatureCount,
    bool hasUserSigned,
    String currentUserId,
    String petitionId,
    Color accentBlue,
    Color sororiaPink,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "$signatureCount ${signatureCount == 1 ? 'person has' : 'people have'} already signed",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: accentBlue,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        _buildSignButton(
          context,
          hasUserSigned,
          currentUserId,
          petitionId,
          accentBlue,
          sororiaPink,
        ),
      ],
    );
  }

  Widget _buildSignButton(
    BuildContext context,
    bool hasUserSigned,
    String currentUserId,
    String petitionId,
    Color accentBlue,
    Color sororiaPink,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: hasUserSigned ? Colors.grey[400] : accentBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 2,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      onPressed:
          hasUserSigned
              ? null // Disable button if already signed
              : () async {
                try {
                  // 1. Update the petition's signatures array
                  final petitionRef = FirebaseFirestore.instance
                      .collection('petitions')
                      .doc(petitionId);

                  await petitionRef.update({
                    'signatures': FieldValue.arrayUnion([currentUserId]),
                  });

                  // 2. Update the user's "signed_p" array
                  final userRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(currentUserId);

                  // If "signed_p" doesn't exist, create or merge it
                  await userRef.set({
                    'signed_p': FieldValue.arrayUnion([petitionId]),
                  }, SetOptions(merge: true));

                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Petition signed successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error signing petition: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
      child: Text(
        hasUserSigned ? "You've Signed" : "Sign Petition",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showCreateProtestDialog(
    BuildContext context,
    String petitionId,
    String userId,
    String petitionTitle,
  ) {
    // Form controllers
    final titleController = TextEditingController();
    final aimController = TextEditingController();
    final locationController = TextEditingController();
    final detailsController = TextEditingController();
    final hostNameController = TextEditingController();
    final phoneController = TextEditingController();
    final socialMediaController = TextEditingController();

    // Date and time selection
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Function to pick date without recreating the dialog
            Future<void> _selectDate() async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime(2101),
              );
              if (picked != null && picked != selectedDate) {
                setState(() {
                  selectedDate = picked;
                });
              }
            }

            // Function to pick time without recreating the dialog
            Future<void> _selectTime() async {
              final TimeOfDay? picked = await showTimePicker(
                context: context,
                initialTime: selectedTime,
              );
              if (picked != null && picked != selectedTime) {
                setState(() {
                  selectedTime = picked;
                });
              }
            }

            return AlertDialog(
              title: const Text('Organize a Protest'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'For petition: $petitionTitle',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Protest Title*',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: aimController,
                      decoration: const InputDecoration(
                        labelText: 'Aim of Protest*',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Date*'),
                            subtitle: Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: const Icon(Icons.calendar_today),
                            onTap: _selectDate,
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Time*'),
                            subtitle: Text(
                              '${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: const Icon(Icons.access_time),
                            onTap: _selectTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location*',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    // Add host details section
                    const SizedBox(height: 20),
                    const Text(
                      'Host Contact Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hostNameController,
                      decoration: const InputDecoration(
                        labelText: 'Host Name*',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number*',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        hintText: '+1 (555) 123-4567',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: socialMediaController,
                      decoration: const InputDecoration(
                        labelText: 'Social Media Link (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                        hintText: 'https://twitter.com/username',
                      ),
                      keyboardType: TextInputType.url,
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
                      decoration: const InputDecoration(
                        labelText: 'Additional Details',
                        border: OutlineInputBorder(),
                        hintText: 'What to bring, safety information, etc.',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validate required fields
                    if (titleController.text.trim().isEmpty ||
                        aimController.text.trim().isEmpty ||
                        locationController.text.trim().isEmpty ||
                        hostNameController.text.trim().isEmpty ||
                        phoneController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fill all required fields'),
                        ),
                      );
                      return;
                    }

                    try {
                      // Combine date and time
                      final protestDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      // Create unique protest ID
                      final protestId =
                          DateTime.now().millisecondsSinceEpoch.toString();

                      // New protest data
                      final protestData = {
                        'protest_id': protestId,
                        'title': titleController.text.trim(),
                        'aim': aimController.text.trim(),
                        'date': Timestamp.fromDate(protestDateTime),
                        'location': locationController.text.trim(),
                        'details': detailsController.text.trim(),
                        'created_by': userId,
                        'created_at': Timestamp.now(),
                        'supporters': [
                          userId,
                        ], // Creator is the first supporter
                        'host_name': hostNameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'social_media': socialMediaController.text.trim(),
                      };

                      // Update petition document to add new protest
                      await FirebaseFirestore.instance
                          .collection('petitions')
                          .doc(petitionId)
                          .update({
                            'protests': FieldValue.arrayUnion([protestData]),
                          });

                      Navigator.of(context).pop();

                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Protest organized successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating protest: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('CREATE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _generateShareText(
    String title,
    String date,
    String time,
    String location,
    String hostName,
    String phone,
    String aim,
    String details,
  ) {
    return """
  Join the protest: $title
  Date: $date at $time
  Location: $location
  Host: $hostName (Phone: $phone)

  ${aim.isNotEmpty ? "$aim\n\n" : ""}
  ${details.isNotEmpty ? "Details: $details\n\n" : ""}

  Download our app to support more protests:
  https://drive.google.com/file/d/1GqR7grncvl9tcI-oOLbeQg9s_7ZwbPJt/view?usp=sharing
  """;
  }

  void _showProtestDetails(
    BuildContext context,
    Map<String, dynamic> protestData,
    String petitionId,
    String petitionTitle,
    String currentUserId,
    Color accentBlue,
    Color sororiaPink,
  ) {
    final String protestId = protestData['protest_id'] ?? '';
    final String title = protestData['title'] ?? 'Unnamed Protest';
    final String aim = protestData['aim'] ?? 'No aim specified';
    final DateTime date = (protestData['date'] as Timestamp).toDate();
    final String location = protestData['location'] ?? 'Location not specified';
    final String details = protestData['details'] ?? '';
    final List<dynamic> supporters = protestData['supporters'] ?? [];
    final int supporterCount = supporters.length;
    final bool isUserSupporting = supporters.contains(currentUserId);
    final String hostName = protestData['host_name'] ?? 'Not specified';
    final String phone = protestData['phone'] ?? 'Not specified';
    final String socialMedia = protestData['social_media'] ?? '';
    final dateFormatter = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormatter = DateFormat('h:mm a');
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20.0),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: sororiaPink,
                            fontSize: 22,
                          ),
                        ),
                        const Divider(),
                        const Text(
                          "Aim:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(aim, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, color: accentBlue),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateFormatter.format(date),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  timeFormatter.format(date),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, color: accentBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    location,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  GestureDetector(
                                    onTap: () async {
                                      final url =
                                          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}';
                                      final uri = Uri.parse(url);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      }
                                    },
                                    child: const Text(
                                      "Open in Maps",
                                      style: TextStyle(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Host Contact Information:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.person, color: accentBlue),
                            const SizedBox(width: 8),
                            Text(
                              hostName,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.phone, color: accentBlue),
                            const SizedBox(width: 8),
                            Text(phone, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        if (socialMedia.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.link, color: accentBlue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.parse(socialMedia);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  },
                                  child: Text(
                                    socialMedia,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            "Additional Details:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(details, style: const TextStyle(fontSize: 16)),
                        ],
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accentBlue.withOpacity(0.15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                "$supporterCount ${supporterCount == 1 ? 'person is' : 'people are'} supporting this protest",
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: accentBlue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        isUserSupporting
                                            ? Colors.grey[400]
                                            : accentBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed:
                                      isUserSupporting
                                          ? null
                                          : () async {
                                            try {
                                              final petitionRef =
                                                  FirebaseFirestore.instance
                                                      .collection('petitions')
                                                      .doc(petitionId);
                                              final petitionDoc =
                                                  await petitionRef.get();
                                              final petitionData =
                                                  petitionDoc.data()
                                                      as Map<String, dynamic>;
                                              final protests = List<
                                                Map<String, dynamic>
                                              >.from(
                                                petitionData['protests'] ?? [],
                                              );
                                              for (
                                                int i = 0;
                                                i < protests.length;
                                                i++
                                              ) {
                                                if (protests[i]['protest_id'] ==
                                                    protestId) {
                                                  if (!protests[i]['supporters']
                                                      .contains(
                                                        currentUserId,
                                                      )) {
                                                    protests[i]['supporters']
                                                        .add(currentUserId);
                                                  }
                                                  break;
                                                }
                                              }
                                              await petitionRef.update({
                                                'protests': protests,
                                              });
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'You are now supporting this protest!',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          },
                                  child: Text(
                                    isUserSupporting
                                        ? "You're Supporting"
                                        : "Support this Protest",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: Icon(Icons.share, color: accentBlue),
                                  label: Text(
                                    "Share Protest",
                                    style: TextStyle(color: accentBlue),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: accentBlue,
                                    side: BorderSide(color: accentBlue),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    final dateFormatter = DateFormat(
                                      'EEEE, MMMM d, yyyy',
                                    );
                                    final timeFormatter = DateFormat('h:mm a');
                                    final dateStr = dateFormatter.format(date);
                                    final timeStr = timeFormatter.format(date);
                                    final String shareText = _generateShareText(
                                      title,
                                      dateStr,
                                      timeStr,
                                      location,
                                      hostName,
                                      phone,
                                      aim,
                                      details,
                                    );
                                    Share.share(
                                      shareText,
                                      subject: 'Join the protest: $title',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CLOSE"),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
