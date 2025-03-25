import 'dart:convert';
import 'package:http/http.dart' as http;

class SerperService {
  final String apiKey;

  SerperService(this.apiKey);

  Future<List<Map<String, String>>> fetchSerperNews(String query) async {
    try {
      final response = await http.post(
        Uri.parse("https://google.serper.dev/search"),
        headers: {
          "Content-Type": "application/json",
          "X-API-KEY": apiKey,
        },
        body: json.encode({
          "q": "$query site:agricoop.gov.in",
          "location": "India", // Ensure search is location-based
          "num": 10, // Limit the number of results
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['organic'] == null) return [];

        return (data['organic'] as List).map((item) {
          return {
            'title': item['title']?.toString() ?? "No Title",
            'summary': item['snippet']?.toString() ?? "No Summary",
            'url': item['link']?.toString() ?? "#",
          };
        }).toList();
      } else {
        print("Serper API Error: ${response.body}");
      }
    } catch (e) {
      print("Error fetching Serper news: $e");
    }
    return [];
  }
}
