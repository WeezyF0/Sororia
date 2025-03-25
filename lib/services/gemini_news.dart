import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiNewsService {
  final String apiKey;

  GeminiNewsService(this.apiKey);

  Future<List<Map<String, String>>> fetchGeminiNews(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey",
        ),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['candidates'] == null || data['candidates'].isEmpty) {
          return [];
        }

        // Extracting the summarized content from Gemini
        final summaries = data['candidates'][0]['content']['parts'][0]['text']
            .split("\n")
            .where((summary) => summary.trim().isNotEmpty)
            .toList();

        return summaries.map((summary) {
          final parts = summary.split(" - ");
          return {
            'title': parts.isNotEmpty ? parts[0].trim() : "No Title",
            'summary': parts.length > 1 ? parts[1].trim() : "No Summary",
            'url': "https://agriwelfare.gov.in/",
          };
        }).toList();
      } else {
        print("Gemini API Error: ${response.body}");
      }
    } catch (e) {
      print("Error fetching Gemini news: $e");
    }
    return [];
  }
}
