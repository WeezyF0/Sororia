import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SerperService {
  final String _apiKey = dotenv.env['serper-api'] ?? "";

  Future<String> search(String query) async {
    if (_apiKey.isEmpty) {
      return "ERROR: Serper API key is missing.";
    }

    final Uri url = Uri.parse("https://google.serper.dev/search");
    
    try {
      final response = await http.post(
        url,
        headers: {
          "X-API-KEY": _apiKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "q": query,
          "num": 5,  // Get top 5 search results
        }),
      ).timeout(Duration(seconds: 8)); // Added timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data.containsKey("organic")) {
          List<dynamic> results = data["organic"];
          if (results.isEmpty) return "🔍 No results found for: $query.";

          String formattedResults = results
              .map((r) => "**${r["title"]}**\n${r["link"]}")
              .join("\n\n");

          return "🌍 **Top Search Results:**\n$formattedResults";
        }
      }

      return "⚠️ No search results found. Try again later.";
    } catch (e) {
      return "Network Error: $e";
    }
  }
}
