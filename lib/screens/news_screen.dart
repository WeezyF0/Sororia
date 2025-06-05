import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:complaints_app/screens/navbar.dart';
import 'package:complaints_app/services/serper_news.dart';
import 'package:complaints_app/services/location_service.dart';
import 'package:complaints_app/services/web_geocoding.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  _NewsScreenState createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<Map<String, String>> centralNews = [];
  List<Map<String, String>> stateNews = [];
  bool isLoading = false;
  String currentState = "";

  late SerperService serperService;
  
  @override
  void initState() {
    super.initState();
    final serperApiKey = dotenv.env['serper-api'] ?? "";
    serperService = SerperService(serperApiKey);
    _determinePosition();
  }
  Future<void> _determinePosition() async {
    try {
      Position? position = await LocationService.getCurrentPosition();
      if (position != null) {
        String locationName = await _getLocationName(position.latitude, position.longitude) ?? "Unknown";
        setState(() {
          currentState = locationName;
        });
        fetchNews(currentState);
      } else {
        // Fallback to default location or show error
        setState(() {
          currentState = "India"; // Default fallback
        });
        fetchNews(currentState);
      }
    } catch (e) {
      print("Location error: $e");
      // Fallback to default location
      setState(() {
        currentState = "India";
      });
      fetchNews(currentState);
    }
  }
  Future<String?> _getLocationName(double latitude, double longitude) async {
    try {
      String? locationName = await WebGeocoding.placemarkFromCoordinates(latitude, longitude);
      return locationName ?? "Unknown Location";
    } catch (_) {
      return "Unknown Location";
    }
  }

  Future<void> fetchNews(String state) async {
    if (isLoading) return;

    setState(() => isLoading = true);

    final centralNewsFuture = serperService.fetchSerperNews("Latest central government woman scheme site:.gov.in");
    final stateNewsFuture = serperService.fetchSerperNews("Latest $state state woman schemes site:.gov.in");

    final results = await Future.wait([centralNewsFuture, stateNewsFuture]);

    setState(() {
      centralNews = results[0];
      stateNews = results[1];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: PreferredSize(
      preferredSize: Size.fromHeight(80.0),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "State & Central News - $currentState",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
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
        ),
      ),
    ),
    drawer: NavBar(),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              isDark
                  ? 'assets/images/home_bg_night.jpg'
                  : 'assets/images/home_bg_day.jpg',
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isLoading
                  ? Center(child: CircularProgressIndicator())
                  : Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 24),
                            _buildNewsSection(
                              "Central Government Schemes",
                              centralNews,
                            ),
                            SizedBox(height: 24),
                            _buildNewsSection(
                              "State Government Schemes",
                              stateNews,
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsSection(String title, List<Map<String, String>> newsList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        ),
        SizedBox(height: 12),
        if (newsList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "No news available",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ...newsList.map((news) => _buildNewsCard(news)),
      ],
    );
  }

  Widget _buildNewsCard(Map<String, String> news) {
    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(news['url']!)),
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                news['title']!,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                news['summary']!,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}