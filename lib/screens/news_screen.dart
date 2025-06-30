import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:complaints_app/screens/navbar.dart';
import 'package:complaints_app/services/serper_news.dart';
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
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    String locationName =
        await _getLocationName(position.latitude, position.longitude) ??
        "Unknown";
    setState(() {
      currentState = locationName;
    });
    fetchNews(currentState);
  }

  Future<String?> _getLocationName(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      return placemarks.isNotEmpty
          ? placemarks.first.administrativeArea ?? "Unknown Location"
          : "Unknown Location";
    } catch (_) {
      return "Unknown Location";
    }
  }

  Future<void> fetchNews(String state) async {
    if (isLoading) return;

    setState(() => isLoading = true);

    final centralNewsFuture = serperService.fetchSerperNews(
      "Latest central government woman scheme site:.gov.in",
    );
    final stateNewsFuture = serperService.fetchSerperNews(
      "Latest $state state woman schemes site:.gov.in",
    );

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
          centerTitle: true,
          title: Text(
            "State & Central News${currentState.isNotEmpty ? ' - $currentState' : ''}",
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
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        _buildNewsSection(
                          "Central Government Schemes",
                          centralNews,
                        ),
                        const SizedBox(height: 24),
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
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
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
