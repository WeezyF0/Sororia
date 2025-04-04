import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class NewsApiService {
  final String _apiKey = dotenv.env['news-api'] ?? "";

  Future<List<Map<String, String>>> search(String query) async {
    if (_apiKey.isEmpty) {
      print("ERROR: News API key is missing.");
      return [];
    }

    final Uri url = Uri.parse(
        "https://newsapi.org/v2/everything?q=$query&sortBy=relevancy&apiKey=$_apiKey&pageSize=10");

    try {
      final response = await http.get(url).timeout(Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['articles'] == null) return [];

        return (data['articles'] as List).map((item) {
          return {
            'title': item['title']?.toString() ?? "No Title",
            'summary': item['description']?.toString() ?? "No Summary",
            'url': item['url']?.toString() ?? "#",
          };
        }).toList();
      } else {
        print("News API Error: ${response.body}");
      }
    } catch (e) {
      print("Error fetching News API results: $e");
    }

    return [];
  }
}
